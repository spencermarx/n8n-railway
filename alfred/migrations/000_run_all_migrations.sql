-- Alfred Database Setup: Run All Migrations
-- Execute this file to set up the complete Alfred database schema
-- All statements are idempotent (safe to run multiple times)
--
-- WARNING: This operates on the 'alfred' schema ONLY.
-- It will NEVER touch n8n's tables in the 'public' schema.

-- ============================================================
-- STEP 1: Create Schema
-- ============================================================
CREATE SCHEMA IF NOT EXISTS alfred;

-- ============================================================
-- STEP 2: Create Users Table
-- ============================================================
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

    -- Google auth method: service_account (for @aclarify.com), oauth_credential (external), none
    google_auth_method VARCHAR(20) DEFAULT 'none'
        CHECK (google_auth_method IN ('service_account', 'oauth_credential', 'none')),

    -- JSON fields
    calendar_ids JSONB DEFAULT '[]'::jsonb,
    -- preferences schema:
    --   timezone: string (e.g., "America/Chicago")
    --   daily_briefing: boolean
    --   briefing_time: string (e.g., "08:15")
    --   personality: string (alfred|jarvis|dwight|jim|donna|custom)
    --   custom_personality: string (only if personality="custom")
    preferences JSONB DEFAULT '{"personality":"alfred"}'::jsonb,

    -- Status
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_alfred_users_slack_id ON alfred.users(slack_user_id);
CREATE INDEX IF NOT EXISTS idx_alfred_users_active ON alfred.users(is_active);
CREATE INDEX IF NOT EXISTS idx_alfred_users_role ON alfred.users(role);

-- ============================================================
-- STEP 3: Create Role Permissions Table
-- ============================================================
CREATE TABLE IF NOT EXISTS alfred.role_permissions (
    role VARCHAR(20) PRIMARY KEY,
    permissions JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================
-- STEP 4: Create Audit Log Table
-- ============================================================
CREATE TABLE IF NOT EXISTS alfred.audit_log (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    slack_user_id VARCHAR(20) NOT NULL,
    action VARCHAR(100) NOT NULL,
    resource VARCHAR(255),
    permitted BOOLEAN NOT NULL,
    denial_reason TEXT,
    request_summary TEXT,
    metadata JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_audit_log_user ON alfred.audit_log(slack_user_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_timestamp ON alfred.audit_log(timestamp);
CREATE INDEX IF NOT EXISTS idx_audit_log_action ON alfred.audit_log(action);
CREATE INDEX IF NOT EXISTS idx_audit_log_permitted ON alfred.audit_log(permitted);

-- ============================================================
-- STEP 5: Seed Role Permissions
-- ============================================================
INSERT INTO alfred.role_permissions (role, permissions) VALUES
('admin', '{
    "calendar_read": true, "calendar_write": true,
    "email_read": true, "email_send": true, "email_delete": true,
    "docs_read": true, "docs_write": true, "docs_create": true,
    "sheets_read": true, "sheets_write": true,
    "drive_read": true, "drive_write": true, "drive_share": true,
    "tasks_read": true, "tasks_write": true,
    "research_web": true,
    "workflows_view": true, "workflows_create": true,
    "workflows_activate": true, "workflows_delete": true,
    "admin_manage_users": true, "admin_view_all_data": true
}'::jsonb),
('member', '{
    "calendar_read": true, "calendar_write": true,
    "email_read": true, "email_send": true, "email_delete": false,
    "docs_read": true, "docs_write": true, "docs_create": true,
    "sheets_read": true, "sheets_write": true,
    "drive_read": true, "drive_write": true, "drive_share": false,
    "tasks_read": true, "tasks_write": true,
    "research_web": true,
    "workflows_view": true, "workflows_create": false,
    "workflows_activate": false, "workflows_delete": false,
    "admin_manage_users": false, "admin_view_all_data": false
}'::jsonb),
('guest', '{
    "calendar_read": true, "calendar_write": false,
    "email_read": false, "email_send": false, "email_delete": false,
    "docs_read": true, "docs_write": false, "docs_create": false,
    "sheets_read": true, "sheets_write": false,
    "drive_read": true, "drive_write": false, "drive_share": false,
    "tasks_read": true, "tasks_write": false,
    "research_web": true,
    "workflows_view": false, "workflows_create": false,
    "workflows_activate": false, "workflows_delete": false,
    "admin_manage_users": false, "admin_view_all_data": false
}'::jsonb)
ON CONFLICT (role) DO NOTHING;

-- ============================================================
-- STEP 6: Seed Initial Admin User (Spencer)
-- ============================================================
INSERT INTO alfred.users (
    slack_user_id, slack_username, email, role,
    google_calendar_credential_id, gmail_credential_id, google_docs_credential_id,
    google_auth_method, calendar_ids, preferences, is_active
) VALUES (
    'U02TE7SKU3X', 'spencermarx', 'spencer@aclarify.com', 'admin',
    'yBNZEWLXitD9cSiU', 'v2wjW0tm9a1TxnZP', 'yBNZEWLXitD9cSiU',
    'service_account',
    '["spencer@aclarify.com", "spencer.s.marx@gmail.com"]'::jsonb,
    '{"timezone":"Europe/Berlin","daily_briefing":true,"briefing_time":"08:15","personality":"alfred"}'::jsonb,
    true
)
ON CONFLICT (slack_user_id) DO NOTHING;

-- ============================================================
-- STEP 7: Fix timezone for existing users (Migration 009)
-- ============================================================
UPDATE alfred.users
SET preferences = jsonb_set(preferences, '{timezone}', '"Europe/Berlin"')
WHERE slack_user_id = 'U02TE7SKU3X'
  AND preferences->>'timezone' = 'America/Chicago';

-- ============================================================
-- VERIFICATION: Check Setup
-- ============================================================
SELECT 'Schema' as check_type, schema_name as result
FROM information_schema.schemata WHERE schema_name = 'alfred'
UNION ALL
SELECT 'Users Count', COUNT(*)::text FROM alfred.users
UNION ALL
SELECT 'Roles Count', COUNT(*)::text FROM alfred.role_permissions
UNION ALL
SELECT 'Admin User', slack_username FROM alfred.users WHERE role = 'admin';
