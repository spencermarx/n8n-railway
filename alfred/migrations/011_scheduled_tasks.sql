-- Alfred Migration 011: Scheduled Tasks System
-- Unified scheduling system for all recurring/scheduled Alfred tasks
-- Safe to run multiple times (idempotent)

BEGIN;

-- ============================================================================
-- SCHEDULED TASKS TABLE
-- ============================================================================
-- Stores all scheduled tasks that Alfred can execute on a schedule.
-- Supports: once, daily, weekly, interval schedule types
-- ============================================================================

CREATE TABLE IF NOT EXISTS alfred.scheduled_tasks (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES alfred.users(id) ON DELETE CASCADE,

    -- Task identification
    name VARCHAR(100) NOT NULL,                -- Human-readable name: "Daily Schedule", "Email Reminder"
    description TEXT,                          -- Optional description of what this task does

    -- What to execute (sent to Alfred AI agent)
    request TEXT NOT NULL,                     -- The full request/prompt to send to Alfred

    -- Schedule configuration
    schedule_type VARCHAR(20) NOT NULL         -- 'once', 'daily', 'weekly', 'interval'
        CHECK (schedule_type IN ('once', 'daily', 'weekly', 'interval')),

    -- For 'once': specific datetime to run
    one_time_at TIMESTAMPTZ,

    -- For 'daily' and 'weekly': time of day to run (in user's timezone)
    scheduled_time TIME,

    -- For 'weekly': which days to run (1=Monday, 7=Sunday)
    days_of_week INTEGER[]
        CHECK (days_of_week IS NULL OR (
            array_length(days_of_week, 1) > 0 AND
            days_of_week <@ ARRAY[1,2,3,4,5,6,7]
        )),

    -- For 'interval': frequency in minutes
    interval_minutes INTEGER
        CHECK (interval_minutes IS NULL OR interval_minutes >= 1),

    -- Pre-calculated next execution time (in UTC)
    next_run_at TIMESTAMPTZ NOT NULL,

    -- Delivery preferences
    channels TEXT[] DEFAULT '{slack}'          -- ['slack'], ['email'], ['slack','email']
        CHECK (channels <@ ARRAY['slack', 'email']),

    -- Status and tracking
    is_active BOOLEAN DEFAULT true,
    last_run_at TIMESTAMPTZ,
    last_action_at TIMESTAMPTZ,                -- Last time task actually performed an action (vs just checked)
    run_count INTEGER DEFAULT 0,
    error_count INTEGER DEFAULT 0,
    last_error TEXT,

    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Constraints based on schedule_type
    CONSTRAINT valid_once_schedule CHECK (
        schedule_type != 'once' OR one_time_at IS NOT NULL
    ),
    CONSTRAINT valid_daily_schedule CHECK (
        schedule_type != 'daily' OR scheduled_time IS NOT NULL
    ),
    CONSTRAINT valid_weekly_schedule CHECK (
        schedule_type != 'weekly' OR (scheduled_time IS NOT NULL AND days_of_week IS NOT NULL)
    ),
    CONSTRAINT valid_interval_schedule CHECK (
        schedule_type != 'interval' OR interval_minutes IS NOT NULL
    )
);

-- Indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_scheduled_tasks_user_id
    ON alfred.scheduled_tasks(user_id);

CREATE INDEX IF NOT EXISTS idx_scheduled_tasks_next_run
    ON alfred.scheduled_tasks(next_run_at)
    WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_scheduled_tasks_active
    ON alfred.scheduled_tasks(is_active, next_run_at);


-- ============================================================================
-- HELPER FUNCTION: Calculate next_run_at
-- ============================================================================
-- Calculates the next execution time based on schedule_type and parameters
-- All times are converted to/from user's timezone for accurate scheduling

CREATE OR REPLACE FUNCTION alfred.calculate_next_run(
    p_schedule_type VARCHAR(20),
    p_user_timezone VARCHAR(50),
    p_one_time_at TIMESTAMPTZ DEFAULT NULL,
    p_scheduled_time TIME DEFAULT NULL,
    p_days_of_week INTEGER[] DEFAULT NULL,
    p_interval_minutes INTEGER DEFAULT NULL,
    p_last_run_at TIMESTAMPTZ DEFAULT NULL
) RETURNS TIMESTAMPTZ AS $$
DECLARE
    v_now TIMESTAMPTZ := NOW();
    v_user_now TIMESTAMP;
    v_today_date DATE;
    v_next_run TIMESTAMPTZ;
    v_candidate_date DATE;
    v_day_of_week INTEGER;
    v_i INTEGER;
BEGIN
    -- Get current time in user's timezone
    v_user_now := v_now AT TIME ZONE p_user_timezone;
    v_today_date := v_user_now::DATE;

    CASE p_schedule_type
        WHEN 'once' THEN
            -- Simple: return the one-time timestamp
            RETURN p_one_time_at;

        WHEN 'interval' THEN
            -- Return last_run + interval, or now + interval if never run
            IF p_last_run_at IS NOT NULL THEN
                RETURN p_last_run_at + (p_interval_minutes || ' minutes')::INTERVAL;
            ELSE
                RETURN v_now + (p_interval_minutes || ' minutes')::INTERVAL;
            END IF;

        WHEN 'daily' THEN
            -- Calculate next occurrence of scheduled_time
            v_next_run := (v_today_date + p_scheduled_time) AT TIME ZONE p_user_timezone;

            -- If that time has passed today, schedule for tomorrow
            IF v_next_run <= v_now THEN
                v_next_run := ((v_today_date + INTERVAL '1 day') + p_scheduled_time) AT TIME ZONE p_user_timezone;
            END IF;

            RETURN v_next_run;

        WHEN 'weekly' THEN
            -- Find the next matching day of week
            v_candidate_date := v_today_date;

            FOR v_i IN 0..7 LOOP
                v_day_of_week := EXTRACT(ISODOW FROM v_candidate_date)::INTEGER;

                IF v_day_of_week = ANY(p_days_of_week) THEN
                    v_next_run := (v_candidate_date + p_scheduled_time) AT TIME ZONE p_user_timezone;

                    -- If it's today but the time has passed, continue to next day
                    IF v_next_run > v_now THEN
                        RETURN v_next_run;
                    END IF;
                END IF;

                v_candidate_date := v_candidate_date + INTERVAL '1 day';
            END LOOP;

            -- Fallback (should never reach here if days_of_week is valid)
            RETURN v_now + INTERVAL '1 day';

        ELSE
            RAISE EXCEPTION 'Unknown schedule_type: %', p_schedule_type;
    END CASE;
END;
$$ LANGUAGE plpgsql;


-- ============================================================================
-- TRIGGER: Auto-update updated_at
-- ============================================================================

CREATE OR REPLACE FUNCTION alfred.update_scheduled_task_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_scheduled_tasks_updated ON alfred.scheduled_tasks;
CREATE TRIGGER trg_scheduled_tasks_updated
    BEFORE UPDATE ON alfred.scheduled_tasks
    FOR EACH ROW
    EXECUTE FUNCTION alfred.update_scheduled_task_timestamp();


-- ============================================================================
-- HELPER FUNCTION: Get due tasks
-- ============================================================================
-- Returns all tasks that are due to run (next_run_at <= now and is_active)

CREATE OR REPLACE FUNCTION alfred.get_due_scheduled_tasks()
RETURNS TABLE (
    task_id INTEGER,
    user_id INTEGER,
    slack_user_id VARCHAR(20),
    slack_username VARCHAR(100),
    email VARCHAR(255),
    user_timezone VARCHAR(50),
    task_name VARCHAR(100),
    request TEXT,
    schedule_type VARCHAR(20),
    channels TEXT[],
    run_count INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        st.id as task_id,
        st.user_id,
        u.slack_user_id,
        u.slack_username,
        u.email,
        COALESCE(u.preferences->>'timezone', 'America/New_York')::VARCHAR(50) as user_timezone,
        st.name as task_name,
        st.request,
        st.schedule_type,
        st.channels,
        st.run_count
    FROM alfred.scheduled_tasks st
    JOIN alfred.users u ON u.id = st.user_id
    WHERE st.is_active = true
      AND st.next_run_at <= NOW()
      AND u.is_active = true
    ORDER BY st.next_run_at ASC;
END;
$$ LANGUAGE plpgsql;


-- ============================================================================
-- HELPER FUNCTION: Mark task as run and calculate next execution
-- ============================================================================

CREATE OR REPLACE FUNCTION alfred.mark_task_run(
    p_task_id INTEGER,
    p_action_taken BOOLEAN DEFAULT true,
    p_error TEXT DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_task RECORD;
    v_user_timezone VARCHAR(50);
    v_next_run TIMESTAMPTZ;
BEGIN
    -- Get task details
    SELECT st.*, COALESCE(u.preferences->>'timezone', 'America/New_York') as user_tz
    INTO v_task
    FROM alfred.scheduled_tasks st
    JOIN alfred.users u ON u.id = st.user_id
    WHERE st.id = p_task_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Task not found: %', p_task_id;
    END IF;

    -- Calculate next run time
    IF v_task.schedule_type = 'once' THEN
        -- One-time tasks get deactivated after running
        UPDATE alfred.scheduled_tasks
        SET
            last_run_at = NOW(),
            last_action_at = CASE WHEN p_action_taken THEN NOW() ELSE last_action_at END,
            run_count = run_count + 1,
            error_count = CASE WHEN p_error IS NOT NULL THEN error_count + 1 ELSE error_count END,
            last_error = p_error,
            is_active = false
        WHERE id = p_task_id;
    ELSE
        -- Recurring tasks get rescheduled
        v_next_run := alfred.calculate_next_run(
            v_task.schedule_type,
            v_task.user_tz,
            v_task.one_time_at,
            v_task.scheduled_time,
            v_task.days_of_week,
            v_task.interval_minutes,
            NOW()  -- Use current time as last_run for calculation
        );

        UPDATE alfred.scheduled_tasks
        SET
            last_run_at = NOW(),
            last_action_at = CASE WHEN p_action_taken THEN NOW() ELSE last_action_at END,
            next_run_at = v_next_run,
            run_count = run_count + 1,
            error_count = CASE WHEN p_error IS NOT NULL THEN error_count + 1 ELSE error_count END,
            last_error = p_error
        WHERE id = p_task_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

COMMIT;

-- Verify migration
SELECT
    'scheduled_tasks table' as object,
    COUNT(*)::text as count
FROM information_schema.tables
WHERE table_schema = 'alfred' AND table_name = 'scheduled_tasks'
UNION ALL
SELECT
    'calculate_next_run function',
    COUNT(*)::text
FROM information_schema.routines
WHERE routine_schema = 'alfred' AND routine_name = 'calculate_next_run'
UNION ALL
SELECT
    'get_due_scheduled_tasks function',
    COUNT(*)::text
FROM information_schema.routines
WHERE routine_schema = 'alfred' AND routine_name = 'get_due_scheduled_tasks';
