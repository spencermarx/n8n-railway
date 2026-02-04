-- Alfred Migration 003: Create Role Permissions Table
-- RBAC permission definitions for each role
-- Safe to run multiple times (idempotent)

CREATE TABLE IF NOT EXISTS alfred.role_permissions (
    role VARCHAR(20) PRIMARY KEY,
    permissions JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Verify table exists
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'alfred' AND table_name = 'role_permissions'
ORDER BY ordinal_position;
