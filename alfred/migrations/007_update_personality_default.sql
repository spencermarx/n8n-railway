-- Migration 007: Update Spencer's personality to "alfred" default
-- This sets the default personality for the initial admin user
-- Safe to run multiple times (idempotent)

UPDATE alfred.users
SET preferences = jsonb_set(
    COALESCE(preferences, '{}'::jsonb),
    '{personality}',
    '"alfred"'::jsonb
)
WHERE slack_user_id = 'U02TE7SKU3X';

-- Verify the update
SELECT slack_username, preferences->>'personality' as personality
FROM alfred.users
WHERE slack_user_id = 'U02TE7SKU3X';
