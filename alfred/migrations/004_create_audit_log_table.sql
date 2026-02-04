-- Alfred Migration 004: Create Audit Log Table
-- Tracks all actions (permitted and denied) for security and compliance
-- Safe to run multiple times (idempotent)

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

-- Indexes for efficient audit queries
CREATE INDEX IF NOT EXISTS idx_audit_log_user ON alfred.audit_log(slack_user_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_timestamp ON alfred.audit_log(timestamp);
CREATE INDEX IF NOT EXISTS idx_audit_log_action ON alfred.audit_log(action);
CREATE INDEX IF NOT EXISTS idx_audit_log_permitted ON alfred.audit_log(permitted);

-- Verify table exists
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'alfred' AND table_name = 'audit_log'
ORDER BY ordinal_position;
