-- Alfred Migration 020: Marketing Configs Table
-- Creates the marketing_configs table for storing user-specific marketing document references
-- Safe to run multiple times (idempotent)

BEGIN;

-- ============================================================================
-- MARKETING CONFIGS TABLE
-- ============================================================================
-- Stores per-user references to Google Docs/Sheets for marketing workflows:
-- - brand_guide: Google Doc ID containing brand guidelines
-- - content_strategy: Google Doc ID containing content strategy
-- - content_calendar: Google Sheet ID for content tracking
-- - marketing_playbook: Google Doc ID (optional, can use system default)
-- ============================================================================

CREATE TABLE IF NOT EXISTS alfred.marketing_configs (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES alfred.users(id) ON DELETE CASCADE,

    -- Config type: 'brand_guide', 'content_strategy', 'content_calendar', 'marketing_playbook'
    config_type VARCHAR(50) NOT NULL,

    -- Config value as JSONB (e.g., {"google_doc_id": "..."} or {"google_sheet_id": "..."})
    config_value JSONB NOT NULL,

    -- Status
    is_active BOOLEAN DEFAULT true,

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Each user can only have one active config of each type
    CONSTRAINT unique_user_config_type UNIQUE (user_id, config_type)
);

-- Index for efficient lookups
CREATE INDEX IF NOT EXISTS idx_marketing_configs_user_type
    ON alfred.marketing_configs(user_id, config_type)
    WHERE is_active = true;

-- Trigger to auto-update updated_at
CREATE OR REPLACE FUNCTION alfred.update_marketing_config_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_marketing_configs_updated ON alfred.marketing_configs;
CREATE TRIGGER trg_marketing_configs_updated
    BEFORE UPDATE ON alfred.marketing_configs
    FOR EACH ROW
    EXECUTE FUNCTION alfred.update_marketing_config_timestamp();

COMMIT;

-- Verify migration
SELECT
    'marketing_configs table' as object,
    CASE WHEN COUNT(*) > 0 THEN 'EXISTS' ELSE 'MISSING' END as status
FROM information_schema.tables
WHERE table_schema = 'alfred' AND table_name = 'marketing_configs';
