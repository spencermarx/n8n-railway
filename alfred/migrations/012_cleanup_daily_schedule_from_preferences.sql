-- Alfred Migration 012: Remove daily_schedule from user preferences
-- Now that scheduling is handled by the scheduled_tasks table, we no longer
-- need daily_schedule in user preferences. This migration cleans up the schema.
-- Safe to run multiple times (idempotent)

BEGIN;

-- ============================================================================
-- VERIFY DATA WAS MIGRATED
-- ============================================================================
-- First, let's verify that all users with daily_schedule preferences have
-- corresponding entries in scheduled_tasks

DO $$
DECLARE
    v_unmigrated_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_unmigrated_count
    FROM alfred.users u
    WHERE u.preferences->'daily_schedule'->>'enabled' = 'true'
      AND NOT EXISTS (
          SELECT 1 FROM alfred.scheduled_tasks st
          WHERE st.user_id = u.id
          AND st.name = 'Daily Schedule'
      );

    IF v_unmigrated_count > 0 THEN
        RAISE NOTICE 'WARNING: % users have daily_schedule enabled but no scheduled_task entry. Running auto-migration...', v_unmigrated_count;

        -- Auto-migrate any missing entries
        INSERT INTO alfred.scheduled_tasks (
            user_id, name, description, request, schedule_type,
            scheduled_time, channels, is_active, next_run_at
        )
        SELECT
            u.id,
            'Daily Schedule',
            'Daily calendar summary (auto-migrated from preferences)',
            'Get my calendar events for today and send me a comprehensive summary. Include key meetings, work time stats, and any preparation notes for important meetings.',
            'daily',
            (u.preferences->'daily_schedule'->>'time')::TIME,
            ARRAY(SELECT jsonb_array_elements_text(u.preferences->'daily_schedule'->'channels'))::TEXT[],
            (u.preferences->'daily_schedule'->>'enabled')::BOOLEAN,
            alfred.calculate_next_run(
                'daily',
                COALESCE(u.preferences->>'timezone', 'America/New_York'),
                NULL,
                (u.preferences->'daily_schedule'->>'time')::TIME,
                NULL,
                NULL,
                NULL
            )
        FROM alfred.users u
        WHERE u.preferences->'daily_schedule'->>'enabled' = 'true'
          AND NOT EXISTS (
              SELECT 1 FROM alfred.scheduled_tasks st
              WHERE st.user_id = u.id
              AND st.name = 'Daily Schedule'
          );

        RAISE NOTICE 'Auto-migration complete.';
    ELSE
        RAISE NOTICE 'All daily_schedule preferences have been migrated to scheduled_tasks.';
    END IF;
END $$;


-- ============================================================================
-- REMOVE daily_schedule FROM USER PREFERENCES
-- ============================================================================
-- The daily_schedule field is now redundant since scheduling is handled by
-- the scheduled_tasks table.

UPDATE alfred.users
SET preferences = preferences - 'daily_schedule',
    updated_at = NOW()
WHERE preferences ? 'daily_schedule';


-- ============================================================================
-- DOCUMENT THE CLEAN USER PREFERENCES SCHEMA
-- ============================================================================
-- After this migration, user preferences should only contain:
-- {
--   "timezone": "America/New_York",        -- IANA timezone (used across all features)
--   "personality": "alfred",               -- AI personality: alfred, jarvis, donna, jim, dwight
--   "verbosity": "concise",                -- Response style: concise, detailed
--   "proactive_notifications": true        -- Allow proactive notifications
-- }
--
-- Scheduling is now handled entirely by alfred.scheduled_tasks table

COMMIT;

-- Verify the cleanup
SELECT
    slack_username,
    preferences,
    CASE
        WHEN preferences ? 'daily_schedule' THEN 'STILL HAS daily_schedule'
        ELSE 'CLEAN'
    END as status
FROM alfred.users;
