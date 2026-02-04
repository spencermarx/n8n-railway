-- Migration 008: Add Google auth method column
-- Tracks which authentication method to use for Google services per user
-- Safe to run multiple times (idempotent)

-- Add auth_method column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'alfred'
        AND table_name = 'users'
        AND column_name = 'google_auth_method'
    ) THEN
        ALTER TABLE alfred.users
        ADD COLUMN google_auth_method VARCHAR(20)
        DEFAULT 'none'
        CHECK (google_auth_method IN ('service_account', 'oauth_credential', 'none'));
    END IF;
END $$;

-- Update existing @aclarify.com users to use service_account
UPDATE alfred.users
SET google_auth_method = 'service_account'
WHERE email LIKE '%@aclarify.com'
AND google_auth_method = 'none';

-- Update users with existing credential IDs to use oauth_credential
UPDATE alfred.users
SET google_auth_method = 'oauth_credential'
WHERE (
    google_calendar_credential_id IS NOT NULL
    OR gmail_credential_id IS NOT NULL
    OR google_docs_credential_id IS NOT NULL
    OR google_sheets_credential_id IS NOT NULL
    OR google_drive_credential_id IS NOT NULL
)
AND google_auth_method = 'none'
AND email NOT LIKE '%@aclarify.com';

-- Verify
SELECT slack_username, email, google_auth_method
FROM alfred.users;
