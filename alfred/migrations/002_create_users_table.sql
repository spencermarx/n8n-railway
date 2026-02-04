-- Alfred Migration 002: Create Users Table
-- User registry for Alfred system
-- Safe to run multiple times (idempotent)

CREATE TABLE IF NOT EXISTS alfred.users (
    id SERIAL PRIMARY KEY,
    slack_user_id VARCHAR(20) UNIQUE NOT NULL,
    slack_username VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL,
    role VARCHAR(20) DEFAULT 'member' CHECK (role IN ('admin', 'member', 'guest')),

    -- n8n Credential IDs (per-user OAuth)
    google_calendar_credential_id VARCHAR(50),
    gmail_credential_id VARCHAR(50),
    google_docs_credential_id VARCHAR(50),
    google_sheets_credential_id VARCHAR(50),
    google_drive_credential_id VARCHAR(50),
    notion_credential_id VARCHAR(50),

    -- JSON fields
    calendar_ids JSONB DEFAULT '[]'::jsonb,
    preferences JSONB DEFAULT '{}'::jsonb,

    -- Status
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_alfred_users_slack_id ON alfred.users(slack_user_id);
CREATE INDEX IF NOT EXISTS idx_alfred_users_active ON alfred.users(is_active);
CREATE INDEX IF NOT EXISTS idx_alfred_users_role ON alfred.users(role);

-- Verify table exists
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'alfred' AND table_name = 'users'
ORDER BY ordinal_position;
