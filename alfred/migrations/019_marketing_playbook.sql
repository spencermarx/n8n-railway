-- Alfred Migration 019: Marketing Playbook
-- Adds the marketing team playbook to system_config
-- Safe to run multiple times (idempotent)

-- ============================================================================
-- MARKETING PLAYBOOK
-- ============================================================================
-- Static playbook document that the Marketing Team Manager consults for:
-- - Content rules (80/20 value/sales ratio)
-- - Quality standards
-- - Channel requirements
-- - Approval flow guidelines
-- - Playbook templates (NEW_POST, REVISE_POST, ANALYZE_CONTENT, SCHEDULED_POST)
-- ============================================================================

BEGIN;

-- Insert the marketing playbook as a JSON string (newlines escaped as \n)
INSERT INTO alfred.system_config (config_key, config_value, description) VALUES
    ('marketing.playbook', '"# Marketing Team Playbook\n\n## Content Rules\n\n### 80/20 Value Rule\n- 80% of posts should be VALUE content (educational, helpful, insights)\n- 20% of posts can be SALES content (product, promotion, CTA-heavy)\n- Evaluate against last 20 posts when generating new content\n- If ratio is off, next post MUST be the underrepresented type\n\n### Post Quality Standards\n- Minimum 2 revision cycles before approval (unless truly exceptional)\n- All factual claims must be web-search verified\n- Hook must be compelling enough to stop scrolling\n- Clear value proposition in first 2 lines\n\n### Channel Requirements\n- LinkedIn: 1200-1500 chars, professional tone, 3-5 hashtags\n- Twitter/X: 280 chars max, punchy, 1-2 hashtags\n- Facebook: 40-80 chars optimal, casual, questions drive engagement\n- Blog post: 1500-2500 words, SEO headers, meta description\n\n## Scheduled Task Rules\n- 3x/week posting cadence\n- No back-to-back sales content\n- Variety in topics across the week\n\n## Approval Flow\n- All content requires user approval via Slack card\n- Users can approve OR provide feedback via thread reply\n- Feedback triggers REVISE_POST playbook automatically\n\n## Playbook Templates\n\n### NEW_POST\nTrigger: User requests new content creation\nFlow: Brainstorm -> Select -> Write -> Review (loop max 3x) -> Image -> Calendar -> Approval Card\n\n### REVISE_POST\nTrigger: User provides feedback on existing post\nFlow: Fetch existing -> Revise -> Review -> Update Calendar -> New Approval Card\n\n### ANALYZE_CONTENT\nTrigger: User asks about content (themes, patterns)\nFlow: Fetch recent posts -> Analyze -> Report\n\n### SCHEDULED_POST\nTrigger: Scheduled task with constraints\nFlow: Check 80/20 ratio -> Determine type -> NEW_POST with constraint\n\n## Content Type Classification\n\n### VALUE Content (Target: 80%)\n- Educational tutorials\n- Industry insights and trends\n- Tips and best practices\n- Case studies (focus on learnings)\n- Thought leadership\n- How-to guides\n- Research and data sharing\n\n### SALES Content (Target: 20%)\n- Product announcements\n- Feature highlights\n- Promotional offers\n- Direct CTAs to sign up/buy\n- Testimonials (focused on product)\n- Pricing/deals information\n\n## Quality Checklist (Reviewer)\n1. Hook Test: Would this stop YOUR scroll?\n2. Value Test: Does reader learn something or feel inspired?\n3. Brand Test: Does this sound like us?\n4. Fact Test: Are all claims verified?\n5. Format Test: Optimized for the channel?\n6. CTA Test: Clear next step (if appropriate)?"', 'Marketing team playbook with content rules, quality standards, and workflow templates')
ON CONFLICT (config_key) DO UPDATE SET
    config_value = EXCLUDED.config_value,
    description = EXCLUDED.description,
    updated_at = NOW();

COMMIT;

-- Verify the playbook was inserted
SELECT
    config_key,
    LEFT(config_value::text, 100) || '...' as value_preview,
    LENGTH(config_value::text) as total_length,
    description
FROM alfred.system_config
WHERE config_key = 'marketing.playbook';
