-- Alfred Migration 016: Add metadata to scheduled_tasks
-- Adds metadata JSONB column for tracking event notifications and task state
-- Updates get_due_scheduled_tasks() to include metadata with auto-reset
-- Safe to run multiple times (idempotent)

BEGIN;

-- ============================================================================
-- ADD METADATA COLUMN
-- ============================================================================
-- Stores task-specific metadata like notified_event_ids for deduplication

ALTER TABLE alfred.scheduled_tasks
ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;

COMMENT ON COLUMN alfred.scheduled_tasks.metadata IS
'Task-specific metadata. For meeting reminders: {notified_event_ids: [], last_reset: "YYYY-MM-DD", task_type: "meeting_reminder"}';


-- ============================================================================
-- UPDATED FUNCTION: Get due tasks with metadata and auto-reset
-- ============================================================================
-- Returns all tasks that are due to run (next_run_at <= now and is_active)
-- Auto-resets notified_event_ids at the start of each new day

CREATE OR REPLACE FUNCTION alfred.get_due_scheduled_tasks()
RETURNS TABLE(
    task_id INTEGER,
    user_id INTEGER,
    slack_user_id VARCHAR,
    slack_username VARCHAR,
    email VARCHAR,
    user_timezone VARCHAR,
    task_name VARCHAR,
    request TEXT,
    schedule_type VARCHAR,
    channels TEXT[],
    run_count INTEGER,
    metadata JSONB
) AS $$
BEGIN
    -- Auto-reset metadata.notified_event_ids at start of new day
    UPDATE alfred.scheduled_tasks st
    SET metadata = jsonb_set(
        COALESCE(st.metadata, '{}'::jsonb),
        '{notified_event_ids}',
        '[]'::jsonb
    )
    WHERE st.is_active = true
      AND st.metadata IS NOT NULL
      AND (st.metadata->>'last_reset')::date < CURRENT_DATE;

    -- Update last_reset timestamp
    UPDATE alfred.scheduled_tasks st
    SET metadata = jsonb_set(
        COALESCE(st.metadata, '{}'::jsonb),
        '{last_reset}',
        to_jsonb(CURRENT_DATE::text)
    )
    WHERE st.is_active = true
      AND st.metadata IS NOT NULL
      AND (st.metadata->>'last_reset' IS NULL OR (st.metadata->>'last_reset')::date < CURRENT_DATE);

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
        st.run_count,
        COALESCE(st.metadata, '{}'::jsonb) as metadata
    FROM alfred.scheduled_tasks st
    JOIN alfred.users u ON u.id = st.user_id
    WHERE st.is_active = true
      AND st.next_run_at <= NOW()
      AND u.is_active = true
    ORDER BY st.next_run_at ASC;
END;
$$ LANGUAGE plpgsql;

COMMIT;

-- Verify migration
SELECT
    'metadata column exists' as check_name,
    CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'MISSING' END as status
FROM information_schema.columns
WHERE table_schema = 'alfred'
  AND table_name = 'scheduled_tasks'
  AND column_name = 'metadata';
