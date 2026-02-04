-- Alfred Migration 006: Seed Initial Admin User (Spencer)
-- Creates the first admin user for the Alfred system
-- Safe to run multiple times (ON CONFLICT DO NOTHING)

INSERT INTO alfred.users (
    slack_user_id,
    slack_username,
    email,
    role,
    google_calendar_credential_id,
    gmail_credential_id,
    google_docs_credential_id,
    calendar_ids,
    preferences,
    is_active
) VALUES (
    'U02TE7SKU3X',
    'spencermarx',
    'spencer@aclarify.com',
    'admin',
    'yBNZEWLXitD9cSiU',
    'v2wjW0tm9a1TxnZP',
    'yBNZEWLXitD9cSiU',
    '["spencer@aclarify.com", "spencer.s.marx@gmail.com"]'::jsonb,
    '{
        "timezone": "Europe/Berlin",
        "daily_briefing": true,
        "briefing_time": "08:15",
        "personality": "jarvis-inspired",
        "verbosity": "concise",
        "proactive_notifications": true
    }'::jsonb,
    true
)
ON CONFLICT (slack_user_id) DO NOTHING;

-- Verify user created with permissions
SELECT
    u.id,
    u.slack_user_id,
    u.slack_username,
    u.email,
    u.role,
    rp.permissions as effective_permissions
FROM alfred.users u
JOIN alfred.role_permissions rp ON u.role = rp.role
WHERE u.slack_user_id = 'U02TE7SKU3X';
