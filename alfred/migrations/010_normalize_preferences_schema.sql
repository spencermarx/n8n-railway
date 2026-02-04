-- Alfred Migration 010: Normalize User Preferences Schema
-- Consolidates timezone to root level and standardizes daily_schedule structure
-- Safe to run multiple times (idempotent)

-- ============================================================================
-- EXPECTED PREFERENCES SCHEMA AFTER MIGRATION:
-- ============================================================================
-- {
--   "timezone": "America/New_York",      -- IANA timezone (single source of truth)
--   "personality": "alfred",              -- AI personality: alfred, donna, jarvis, jim
--   "verbosity": "concise",               -- Response style: concise, detailed
--   "proactive_notifications": true,      -- Allow proactive outreach
--
--   "daily_schedule": {
--     "enabled": true,                    -- Feature on/off
--     "time": "08:00",                    -- Delivery time in HH:MM (24h format)
--     "channels": ["slack"]               -- Delivery channels: slack, email, or both
--   }
-- }
-- ============================================================================

BEGIN;

-- Step 1: For users who have old format (daily_briefing/briefing_time) but NO daily_schedule yet
-- Convert to new nested format
UPDATE alfred.users
SET preferences = preferences
  || jsonb_build_object(
    'daily_schedule', jsonb_build_object(
      'enabled', COALESCE((preferences->>'daily_briefing')::boolean, false),
      'time', COALESCE(preferences->>'briefing_time', '08:00'),
      'channels', '["slack"]'::jsonb
    )
  )
WHERE preferences->>'daily_briefing' IS NOT NULL
  AND preferences->'daily_schedule' IS NULL;

-- Step 2: Remove deprecated fields from ALL users
UPDATE alfred.users
SET preferences = preferences - 'daily_briefing' - 'briefing_time'
WHERE preferences ? 'daily_briefing'
   OR preferences ? 'briefing_time';

-- Step 3: Remove timezone from daily_schedule if it was duplicated there
-- (timezone should only exist at root level)
UPDATE alfred.users
SET preferences = jsonb_set(
  preferences,
  '{daily_schedule}',
  (preferences->'daily_schedule') - 'timezone'
)
WHERE preferences->'daily_schedule'->>'timezone' IS NOT NULL;

-- Step 4: Ensure all users have required root-level defaults
UPDATE alfred.users
SET preferences =
  jsonb_build_object(
    'timezone', COALESCE(preferences->>'timezone', 'America/New_York'),
    'personality', COALESCE(preferences->>'personality', 'alfred'),
    'verbosity', COALESCE(preferences->>'verbosity', 'concise'),
    'proactive_notifications', COALESCE((preferences->>'proactive_notifications')::boolean, true)
  ) ||
  CASE
    WHEN preferences->'daily_schedule' IS NOT NULL
    THEN jsonb_build_object('daily_schedule', preferences->'daily_schedule')
    ELSE '{}'::jsonb
  END
WHERE true;

COMMIT;

-- Verify migration results
SELECT
  id,
  slack_username,
  preferences->>'timezone' as timezone,
  preferences->>'personality' as personality,
  preferences->'daily_schedule' as daily_schedule,
  jsonb_pretty(preferences) as full_preferences
FROM alfred.users
ORDER BY id;
