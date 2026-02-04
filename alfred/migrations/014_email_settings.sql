-- Alfred Migration 014: Email Settings
-- Adds email_settings to user preferences for tone configuration and HITL approval settings
-- Safe to run multiple times (idempotent)

-- ============================================================================
-- EXPECTED email_settings SCHEMA AFTER MIGRATION:
-- ============================================================================
-- {
--   "email_settings": {
--     "tone_prompt": null,              -- Comprehensive few-shot style guide (2-4KB when configured)
--     "tone_last_updated": null,        -- ISO timestamp of last tone update
--     "tone_source": null,              -- 'analyzed' | 'manual' | null
--     "tone_emails_analyzed": null,     -- Number of emails used in analysis
--     "approval_required": true,        -- HITL guard enabled (default: on)
--     "approval_expiry_minutes": 60     -- How long approval cards stay active
--   }
-- }
-- ============================================================================

BEGIN;

-- Add email_settings with defaults for all users who don't have it yet
UPDATE alfred.users
SET preferences = preferences || jsonb_build_object(
  'email_settings', jsonb_build_object(
    -- Tone configuration
    'tone_prompt', null,
    'tone_last_updated', null,
    'tone_source', null,
    'tone_emails_analyzed', null,

    -- Approval settings
    'approval_required', true,
    'approval_expiry_minutes', 60
  )
)
WHERE preferences->'email_settings' IS NULL;

-- For users who already have partial email_settings, ensure all fields exist
UPDATE alfred.users
SET preferences = jsonb_set(
  preferences,
  '{email_settings}',
  COALESCE(preferences->'email_settings', '{}'::jsonb) || jsonb_build_object(
    'tone_prompt', COALESCE(preferences->'email_settings'->'tone_prompt', 'null'::jsonb),
    'tone_last_updated', COALESCE(preferences->'email_settings'->'tone_last_updated', 'null'::jsonb),
    'tone_source', COALESCE(preferences->'email_settings'->'tone_source', 'null'::jsonb),
    'tone_emails_analyzed', COALESCE(preferences->'email_settings'->'tone_emails_analyzed', 'null'::jsonb),
    'approval_required', COALESCE(preferences->'email_settings'->'approval_required', 'true'::jsonb),
    'approval_expiry_minutes', COALESCE(preferences->'email_settings'->'approval_expiry_minutes', '60'::jsonb)
  )
)
WHERE preferences->'email_settings' IS NOT NULL;

COMMIT;

-- Verify migration results
SELECT
  id,
  slack_username,
  preferences->'email_settings'->>'tone_prompt' IS NOT NULL as has_tone,
  preferences->'email_settings'->>'approval_required' as approval_required,
  preferences->'email_settings'->>'approval_expiry_minutes' as expiry_minutes,
  jsonb_pretty(preferences->'email_settings') as email_settings
FROM alfred.users
ORDER BY id;
