-- Alfred Migration 015: Pending Actions Table
-- Creates pending_actions table for human-in-the-loop (HITL) approval queue
-- Safe to run multiple times (idempotent)

-- ============================================================================
-- PENDING_ACTIONS TABLE
-- ============================================================================
-- Stores actions awaiting user approval via Slack interactive messages.
-- Currently supports: email_send
-- Extensible to: calendar_delete, user_management, etc.
--
-- PAYLOAD STRUCTURE for action_type='email_send':
-- {
--   "to": "john@example.com",
--   "cc": "boss@example.com",
--   "bcc": "",
--   "subject": "Project Update",
--   "body_plain": "Hi John, ...",
--   "body_html": "<html>...",
--   "signature_html": "<div>Best, Spencer</div>",
--   "tone_prompt_used": true,
--   "user_email": "spencer@aclarify.com"
-- }
-- ============================================================================

BEGIN;

-- Create the pending_actions table if it doesn't exist
CREATE TABLE IF NOT EXISTS alfred.pending_actions (
    -- Primary key
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Action classification
    action_type VARCHAR(50) NOT NULL,

    -- User context
    user_id INTEGER NOT NULL REFERENCES alfred.users(id) ON DELETE CASCADE,
    slack_user_id VARCHAR(50) NOT NULL,
    slack_channel_id VARCHAR(50),
    slack_thread_ts VARCHAR(50),

    -- Slack approval message tracking
    approval_channel_id VARCHAR(50),
    approval_message_ts VARCHAR(50),

    -- Action payload
    payload JSONB NOT NULL,

    -- State management
    status VARCHAR(20) DEFAULT 'pending'
        CHECK (status IN ('pending', 'approved', 'rejected', 'expired', 'error')),
    expires_at TIMESTAMPTZ NOT NULL,

    -- Audit trail
    created_at TIMESTAMPTZ DEFAULT NOW(),
    resolved_at TIMESTAMPTZ,
    resolved_by_slack_user_id VARCHAR(50),
    resolution_note TEXT
);

-- Create indexes if they don't exist
CREATE INDEX IF NOT EXISTS idx_pending_actions_status
    ON alfred.pending_actions(status)
    WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_pending_actions_expires
    ON alfred.pending_actions(expires_at)
    WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_pending_actions_user
    ON alfred.pending_actions(slack_user_id, status);

CREATE INDEX IF NOT EXISTS idx_pending_actions_created
    ON alfred.pending_actions(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_pending_actions_approval_msg
    ON alfred.pending_actions(approval_message_ts)
    WHERE approval_message_ts IS NOT NULL;

-- Add unique constraint for approval message if not exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'unique_approval_message'
    ) THEN
        ALTER TABLE alfred.pending_actions
        ADD CONSTRAINT unique_approval_message UNIQUE (approval_message_ts);
    END IF;
EXCEPTION
    WHEN duplicate_object THEN
        NULL; -- Constraint already exists
END $$;

-- Add table comment
COMMENT ON TABLE alfred.pending_actions IS
'Queue for actions requiring human approval (HITL).
Currently supports email_send; extensible to other action types.
Expired actions are cleaned up by cron job every 5 minutes.

Status flow: pending -> approved/rejected/expired/error
';

-- Add column comments
COMMENT ON COLUMN alfred.pending_actions.action_type IS 'Type of action: email_send, calendar_delete, etc.';
COMMENT ON COLUMN alfred.pending_actions.payload IS 'Action-specific data stored as JSONB. Structure varies by action_type.';
COMMENT ON COLUMN alfred.pending_actions.status IS 'pending=awaiting approval, approved=executed, rejected=cancelled by user, expired=timed out, error=execution failed';
COMMENT ON COLUMN alfred.pending_actions.approval_message_ts IS 'Slack message timestamp of the approval card, used for updating the message';
COMMENT ON COLUMN alfred.pending_actions.resolved_by_slack_user_id IS 'Slack user ID of who clicked approve/reject (may differ from requester for admin approvals)';

COMMIT;

-- Verify table structure
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'alfred'
  AND table_name = 'pending_actions'
ORDER BY ordinal_position;

-- Show indexes
SELECT
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'alfred'
  AND tablename = 'pending_actions';
