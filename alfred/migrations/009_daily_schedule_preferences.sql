-- Alfred Migration 009: Daily Schedule Preferences Schema
-- Documents the expected structure for daily_schedule in user preferences
-- Safe to run multiple times (idempotent)

-- This migration documents the preferences.daily_schedule JSON structure:
--
-- {
--   "daily_schedule": {
--     "enabled": true,                    -- Whether to send daily schedule
--     "time": "08:00",                    -- 24-hour format, user's preferred time
--     "timezone": "America/New_York",    -- IANA timezone string
--     "channels": ["slack", "email"],    -- Delivery channels (one or both)
--     "include_greeting": true,          -- Include personality-based greeting
--     "aggregate_key_work_time": true    -- AI aggregates focus/deep work time as key stat
--   }
-- }
--
-- Example user preferences update:
-- UPDATE alfred.users
-- SET preferences = preferences || '{
--   "daily_schedule": {
--     "enabled": true,
--     "time": "08:00",
--     "timezone": "America/New_York",
--     "channels": ["slack"],
--     "include_greeting": true,
--     "aggregate_key_work_time": true
--   }
-- }'::jsonb
-- WHERE slack_user_id = 'U12345';

-- Create a helper function to get users due for daily schedule
-- This checks if current time matches their configured time in their timezone
-- NOTE: timezone is at root level (preferences->>'timezone'), NOT in daily_schedule
CREATE OR REPLACE FUNCTION alfred.get_users_due_for_daily_schedule()
RETURNS TABLE (
    id INTEGER,
    slack_user_id VARCHAR(20),
    slack_username VARCHAR(100),
    email VARCHAR(255),
    preferences JSONB,
    daily_schedule JSONB,
    user_timezone TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        u.id,
        u.slack_user_id,
        u.slack_username,
        u.email,
        u.preferences,
        u.preferences->'daily_schedule' as daily_schedule,
        COALESCE(u.preferences->>'timezone', 'America/New_York') as user_timezone
    FROM alfred.users u
    WHERE
        u.is_active = true
        AND (u.preferences->'daily_schedule'->>'enabled')::boolean = true
        AND (
            -- Check if current time in user's timezone matches their preferred time
            -- Allow 15-minute window for CRON flexibility
            TO_CHAR(
                NOW() AT TIME ZONE COALESCE(u.preferences->>'timezone', 'America/New_York'),
                'HH24:MI'
            ) >= u.preferences->'daily_schedule'->>'time'
            AND
            TO_CHAR(
                NOW() AT TIME ZONE COALESCE(u.preferences->>'timezone', 'America/New_York'),
                'HH24:MI'
            ) < (
                TO_CHAR(
                    (u.preferences->'daily_schedule'->>'time')::TIME + INTERVAL '15 minutes',
                    'HH24:MI'
                )
            )
        );
END;
$$ LANGUAGE plpgsql;

-- Create a table to track sent daily schedules (prevent duplicates)
CREATE TABLE IF NOT EXISTS alfred.daily_schedule_log (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES alfred.users(id),
    sent_date DATE NOT NULL,
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    channels_sent JSONB DEFAULT '[]'::jsonb,
    UNIQUE(user_id, sent_date)
);

CREATE INDEX IF NOT EXISTS idx_daily_schedule_log_date
ON alfred.daily_schedule_log(sent_date);

-- Verify setup
SELECT 'Migration 009 complete: Daily schedule preferences schema documented' as status;
