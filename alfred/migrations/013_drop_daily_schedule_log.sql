-- Alfred Migration 013: Drop daily_schedule_log table
-- This table is no longer needed since scheduling is now handled by the
-- scheduled_tasks table which has built-in tracking (last_run_at, next_run_at, run_count)
-- Safe to run multiple times (idempotent)

BEGIN;

-- ============================================================================
-- DROP THE OLD DAILY_SCHEDULE_LOG TABLE
-- ============================================================================
-- This table was used by the old Multi-User Daily Schedule CRON to track
-- which users had received their daily schedule on a given date.
--
-- The new unified scheduled_tasks system tracks this information directly:
-- - last_run_at: When the task last ran
-- - next_run_at: When the task will run next
-- - run_count: How many times the task has run
-- - last_action_at: When the task last performed an action (vs just checked)

DROP TABLE IF EXISTS alfred.daily_schedule_log CASCADE;

-- Also drop the sequence if it exists separately
DROP SEQUENCE IF EXISTS alfred.daily_schedule_log_id_seq CASCADE;

COMMIT;

-- Verify cleanup
SELECT
    'Tables in alfred schema' as check_type,
    string_agg(table_name, ', ' ORDER BY table_name) as tables
FROM information_schema.tables
WHERE table_schema = 'alfred';
