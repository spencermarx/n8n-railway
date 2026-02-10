-- Alfred Migration 017: System Config Table
-- Creates system_config table for storing configuration values
-- Safe to run multiple times (idempotent)

-- ============================================================================
-- SYSTEM_CONFIG TABLE
-- ============================================================================
-- Stores key-value configuration for the Alfred multi-agent system.
-- Used by DB Manager utility to provide configuration to all workers.
--
-- CONFIG_VALUE is JSONB to support:
-- - Simple strings: '"value"'
-- - Objects: '{"key": "value"}'
-- - Arrays: '["item1", "item2"]'
-- - Numbers: '42'
-- - Booleans: 'true'
-- - Null: 'null'
-- ============================================================================

BEGIN;

-- Create the system_config table if it doesn't exist
CREATE TABLE IF NOT EXISTS alfred.system_config (
    -- Primary key
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Configuration key (unique identifier)
    config_key VARCHAR(255) NOT NULL UNIQUE,

    -- Configuration value stored as JSONB for flexibility
    config_value JSONB NOT NULL,

    -- Human-readable description of the config
    description TEXT,

    -- Audit timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for fast key lookups
CREATE INDEX IF NOT EXISTS idx_system_config_key ON alfred.system_config(config_key);

-- ============================================================================
-- SEED DATA
-- ============================================================================
-- Marketing team configuration values

INSERT INTO alfred.system_config (config_key, config_value, description) VALUES
    ('marketing.brand_guide_doc_id', '"14_iOMjdagXCd9vX_wviQm4ruaMxRQOblUj9VL_2tZYY"', 'Wrkbelt Brand Guide Google Doc ID'),
    ('marketing.content_calendar_sheet_id', '"1Txc5v1Eeitm5-xvHleKvtEbH-KhxUk3hyxrBcr89rI0"', 'Wrkbelt Content Calendar Google Sheet ID'),
    ('marketing.content_calendar_sheet_name', '"Content Tracker"', 'Sheet tab name within the Content Calendar spreadsheet'),
    ('marketing.content_strategy_doc_id', '"1A-9IPf6UN4Vn-vdwivvRTJt6oFnB_KDTDOuVGzO66_U"', 'Wrkbelt Content Strategy Google Doc ID'),
    ('marketing.image_storage_folder_id', '"17gvqrL1VhE6BBx3ykxC_aH7kWA0jRvFL"', 'Google Drive folder for generated marketing images'),
    ('marketing.blog_drafts_folder_id', '"17gvqrL1VhE6BBx3ykxC_aH7kWA0jRvFL"', 'Google Drive folder for blog draft documents'),
    ('marketing.product_knowledge_doc_id', '"1zfkzfQAt-AlDCtXfKbdx2BZraLB-QEThXd2MVS7n0eA"', 'Wrkbelt Product Knowledge Google Doc ID - how schedulers work in the trades and how Wrkbelt Scheduler works'),
    ('marketing.voice_reference_doc_id', '"1pm9LllXVKF0Ezd6j5T-eGQRuZFeIhebvAJQaqCDWxi0"', 'Wrkbelt Voice Reference Google Doc ID - example posts showing Spencer Marx writing style')
ON CONFLICT (config_key) DO UPDATE SET
    config_value = EXCLUDED.config_value,
    description = EXCLUDED.description,
    updated_at = NOW();

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE alfred.system_config IS
'Key-value configuration store for Alfred multi-agent system.
Values are stored as JSONB for type flexibility.
Accessed via DB Manager utility workflow.

Naming convention: <domain>.<key_name>
Examples:
  - marketing.brand_guide_doc_id
  - marketing.content_calendar_sheet_id
  - slack.default_channel_id
';

COMMENT ON COLUMN alfred.system_config.config_key IS 'Unique configuration key using dot notation (e.g., marketing.brand_guide_doc_id)';
COMMENT ON COLUMN alfred.system_config.config_value IS 'Configuration value as JSONB. Use JSON.parse() to extract value in workflows.';
COMMENT ON COLUMN alfred.system_config.description IS 'Human-readable description of what this configuration controls';

COMMIT;

-- Verify table structure
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'alfred'
  AND table_name = 'system_config'
ORDER BY ordinal_position;

-- Show current configuration values
SELECT config_key, config_value, description FROM alfred.system_config ORDER BY config_key;
