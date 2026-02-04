-- Alfred Migration 009: Fix timezone for existing users
-- Updates Spencer's timezone from America/Chicago to Europe/Berlin

UPDATE alfred.users
SET preferences = jsonb_set(preferences, '{timezone}', '"Europe/Berlin"')
WHERE slack_user_id = 'U02TE7SKU3X';

-- Verify the update
SELECT
    slack_username,
    preferences->>'timezone' as timezone
FROM alfred.users
WHERE slack_user_id = 'U02TE7SKU3X';
