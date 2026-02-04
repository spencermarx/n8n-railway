# Gmail HITL Guard + AI-Learned Email Tone Implementation Plan

> **Status:** Implementation Complete - Ready for Testing
> **Created:** 2026-02-04
> **Last Updated:** 2026-02-04

## Workflow IDs (n8n)

| Workflow | ID | Status |
|----------|-----|--------|
| 🛡️ Sub-Agent \| Approval Guard | `1S0dhI1K4X0528Dy` | Inactive |
| 🔔 Trigger \| Approval Handler | `iuU0eyfTN2We4uPR` | Inactive |
| ⏰ Cron \| Expire Pending Actions | `O8GcnPA3wdzG8uMy` | Inactive |
| 🎨 Sub-Agent \| Analyze Email Tone | `LSlDQ7mxMjxUddfa` | Inactive |

**Slack Interactivity Webhook URL:**
```
https://wrkbelt-ai-team.up.railway.app/webhook/approval-handler
```

---

## Executive Summary

This plan implements two integrated features for Alfred's Gmail tool:

1. **Human-in-the-Loop (HITL) Guard** — All outbound emails require user approval via Slack before sending
2. **AI-Learned Email Tone** — Users can configure their email writing style through conversation, with Alfred analyzing their sent emails to synthesize a comprehensive few-shot prompt

Both features work together: when an email is composed using the user's learned tone and Gmail signature, it's presented for approval before sending.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Component Inventory](#component-inventory)
3. [Database Migrations](#database-migrations)
4. [Workflow Specifications](#workflow-specifications)
5. [Tone Prompt Specification](#tone-prompt-specification)
6. [UX Flows](#ux-flows)
7. [Implementation Phases](#implementation-phases)
8. [Progress Tracking](#progress-tracking)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              COMPLETE EMAIL FLOW                                │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  User: "Send an email to john@client.com about the project update"             │
│                                                                                 │
│                                    │                                            │
│                                    ▼                                            │
│  ┌──────────────────────────────────────────────────────────────┐              │
│  │ 1. AI AGENT COMPOSES EMAIL                                   │              │
│  │    • Retrieves user's tone_prompt from preferences           │              │
│  │    • Applies learned writing style to draft                  │              │
│  │    • Does NOT include signature (added later)                │              │
│  └─────────────────────────────────┬────────────────────────────┘              │
│                                    │                                            │
│                                    ▼                                            │
│  ┌──────────────────────────────────────────────────────────────┐              │
│  │ 2. GMAIL TOOL: send_email action                             │              │
│  │    • Receives: to, subject, body, cc, bcc                    │              │
│  └─────────────────────────────────┬────────────────────────────┘              │
│                                    │                                            │
│                                    ▼                                            │
│  ┌──────────────────────────────────────────────────────────────┐              │
│  │ 3. FETCH GMAIL SIGNATURE                                     │              │
│  │    • GET /users/me/settings/sendAs/{email}                   │              │
│  │    • Extract HTML signature                                  │              │
│  │    • Append to email body                                    │              │
│  └─────────────────────────────────┬────────────────────────────┘              │
│                                    │                                            │
│                                    ▼                                            │
│  ┌──────────────────────────────────────────────────────────────┐              │
│  │ 4. APPROVAL GUARD                                            │              │
│  │    • Store pending email in database                         │              │
│  │    • Send Slack approval card with preview                   │              │
│  │    • Return "pending approval" to AI agent                   │              │
│  └─────────────────────────────────┬────────────────────────────┘              │
│                                    │                                            │
│                                    ▼                                            │
│  ┌──────────────────────────────────────────────────────────────┐              │
│  │ 5. USER REVIEWS IN SLACK                                     │              │
│  │    ┌─────────────────────────────────────────────────────┐   │              │
│  │    │ 📧 Email Approval Required                          │   │              │
│  │    │                                                     │   │              │
│  │    │ To: john@client.com                                 │   │              │
│  │    │ Subject: Project Update - Q1 Milestones             │   │              │
│  │    │                                                     │   │              │
│  │    │ Preview:                                            │   │              │
│  │    │ > Hi John,                                          │   │              │
│  │    │ > Quick update on the Q1 milestones...              │   │              │
│  │    │                                                     │   │              │
│  │    │ ⏰ Expires in 60 minutes                            │   │              │
│  │    │                                                     │   │              │
│  │    │ [✅ Send] [❌ Cancel]                               │   │              │
│  │    └─────────────────────────────────────────────────────┘   │              │
│  └─────────────────────────────────┬────────────────────────────┘              │
│                                    │                                            │
│                          ┌─────────┴─────────┐                                  │
│                          │                   │                                  │
│                          ▼                   ▼                                  │
│                     [✅ Send]           [❌ Cancel]                             │
│                          │                   │                                  │
│                          ▼                   ▼                                  │
│  ┌────────────────────────────┐  ┌────────────────────────────┐                │
│  │ 6a. SEND VIA GMAIL API     │  │ 6b. MARK CANCELLED         │                │
│  │     Update card: "✅ Sent"  │  │     Update card: "❌ Cancelled" │           │
│  │     Notify user            │  │     Notify user            │                │
│  └────────────────────────────┘  └────────────────────────────┘                │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Component Inventory

### Database Migrations

| File | Purpose | Status |
|------|---------|--------|
| `migrations/014_email_settings.sql` | Add `email_settings` to user preferences | ✅ Created |
| `migrations/015_pending_actions.sql` | Create `pending_actions` table for HITL queue | ✅ Created |

### New Workflows

| File | Type | Purpose | Status |
|------|------|---------|--------|
| `workflows/sub_agents/analyze_email_tone.json` | Sub-agent | Fetch sent emails, synthesize comprehensive tone_prompt | ✅ Created |
| `workflows/sub_agents/approval_guard.json` | Sub-agent | Store pending action, send Slack approval card | ✅ Created |
| `workflows/triggers/approval_handler.json` | Trigger | Webhook handler for Slack button clicks | ✅ Created |
| `workflows/cron/expire_pending_actions.json` | Cron | Clean up expired pending actions | ✅ Created |

### Modified Workflows

| File | Changes | Status |
|------|---------|--------|
| `workflows/tools/gmail.json` | Add `get_signature` action; route `send_email` through approval guard | ✅ Scopes updated (manual n8n routing needed) |
| `workflows/tools/google_auth.json` | Add `gmail.settings.basic` scope | ⚠️ Requires manual verification |
| `workflows/triggers/team_assistant.json` | Include `tone_prompt` in AI agent system context | ✅ Updated |

### Slack App Configuration

| Item | Purpose | Status |
|------|---------|--------|
| Interactivity URL | Point to `approval_handler.json` webhook | ⚠️ Manual configuration required |

---

## Database Migrations

### Migration 014: Email Settings

**File:** `migrations/014_email_settings.sql`

```sql
-- Migration: 014_email_settings.sql
-- Adds email_settings to user preferences for tone configuration and approval settings

BEGIN;

-- Add email_settings with defaults for all existing users
UPDATE alfred.users
SET preferences = preferences || jsonb_build_object(
  'email_settings', jsonb_build_object(
    -- Tone configuration
    'tone_prompt', null,                -- Comprehensive few-shot style guide (null = not configured)
    'tone_last_updated', null,          -- ISO timestamp of last update
    'tone_source', null,                -- 'analyzed' | 'manual' | null
    'tone_emails_analyzed', null,       -- Number of emails used in analysis

    -- Approval settings
    'approval_required', true,          -- HITL guard enabled (default: on)
    'approval_expiry_minutes', 60       -- How long approval cards stay active
  )
)
WHERE preferences->'email_settings' IS NULL;

-- Add comment documenting expected structure
COMMENT ON COLUMN alfred.users.preferences IS
'User preferences JSONB.
email_settings.tone_prompt: Comprehensive few-shot style guide (2-4KB), generated by analyzing user sent emails.
email_settings.approval_required: When true, all outbound emails require Slack approval before sending.';

COMMIT;

-- Verify migration
SELECT
  id,
  slack_username,
  preferences->'email_settings' as email_settings
FROM alfred.users
ORDER BY id;
```

### Migration 015: Pending Actions

**File:** `migrations/015_pending_actions.sql`

```sql
-- Migration: 015_pending_actions.sql
-- Creates pending_actions table for human-in-the-loop approval queue

BEGIN;

CREATE TABLE IF NOT EXISTS alfred.pending_actions (
    -- Primary key
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Action classification
    action_type VARCHAR(50) NOT NULL,  -- 'email_send', future: 'calendar_delete', etc.

    -- User context
    user_id UUID NOT NULL REFERENCES alfred.users(id) ON DELETE CASCADE,
    slack_user_id VARCHAR(50) NOT NULL,
    slack_channel_id VARCHAR(50),       -- Channel where request originated
    slack_thread_ts VARCHAR(50),        -- Thread where request originated

    -- Slack approval message tracking
    approval_channel_id VARCHAR(50),    -- Channel where approval card was sent
    approval_message_ts VARCHAR(50),    -- Message TS of approval card (for updating)

    -- Action payload (the email details)
    payload JSONB NOT NULL,
    /*
      For action_type='email_send':
      {
        "to": "john@example.com",
        "cc": "boss@example.com",
        "bcc": "",
        "subject": "Project Update",
        "body_plain": "Hi John, ...",
        "body_html": "<html>...",
        "signature_html": "<div>Best, Spencer</div>",
        "tone_prompt_used": true,
        "user_email": "spencer@aclarify.com"
      }
    */

    -- State management
    status VARCHAR(20) DEFAULT 'pending'
        CHECK (status IN ('pending', 'approved', 'rejected', 'expired', 'error')),
    expires_at TIMESTAMPTZ NOT NULL,

    -- Audit trail
    created_at TIMESTAMPTZ DEFAULT NOW(),
    resolved_at TIMESTAMPTZ,
    resolved_by_slack_user_id VARCHAR(50),  -- Who clicked the button
    resolution_note TEXT,                    -- Optional: reason for rejection, error message

    -- Prevent duplicate approval messages
    CONSTRAINT unique_approval_message UNIQUE (approval_message_ts)
);

-- Indexes for common queries
CREATE INDEX idx_pending_actions_status
    ON alfred.pending_actions(status)
    WHERE status = 'pending';

CREATE INDEX idx_pending_actions_expires
    ON alfred.pending_actions(expires_at)
    WHERE status = 'pending';

CREATE INDEX idx_pending_actions_user
    ON alfred.pending_actions(slack_user_id, status);

CREATE INDEX idx_pending_actions_created
    ON alfred.pending_actions(created_at DESC);

-- Add comment
COMMENT ON TABLE alfred.pending_actions IS
'Queue for actions requiring human approval (HITL).
Currently supports email_send; extensible to other action types.
Expired actions are cleaned up by cron job.';

COMMIT;
```

---

## Workflow Specifications

### 1. Sub-Agent: `analyze_email_tone.json`

**Purpose:** Fetch user's sent emails and synthesize a comprehensive tone prompt

**Workflow Inputs:**
```javascript
{
  slack_user_id: string,     // Required: user to analyze
  mode: "recent" | "specific",
  count: number,             // For mode=recent: how many emails (default: 15, max: 25)
  message_ids: string[]      // For mode=specific: specific email IDs
}
```

**Workflow Output:**
```javascript
{
  success: boolean,
  tone_prompt: string,       // The comprehensive few-shot style guide
  emails_analyzed: number,
  date_range: string,        // e.g., "Jan 15 - Feb 4, 2026"
  summary: {
    formality_level: string,
    avg_email_length: string,
    key_patterns: string[],
    signature_phrases: string[]
  },
  error: string | null
}
```

**Flow:**
```
Workflow Input
      │
      ▼
┌─────────────────────────────┐
│ Get Google Auth             │
│ Scopes: gmail.readonly      │
└──────────────┬──────────────┘
               │
      ┌────────┴────────┐
      │                 │
      ▼                 ▼
 mode=recent      mode=specific
      │                 │
      ▼                 ▼
┌─────────────┐  ┌─────────────┐
│ List Sent   │  │ Get Each    │
│ q=in:sent   │  │ Message by  │
│ maxResults  │  │ ID          │
└──────┬──────┘  └──────┬──────┘
       │                │
       └────────┬───────┘
                │
                ▼
┌─────────────────────────────┐
│ Fetch Full Content          │
│ For each message:           │
│ - GET message with full fmt │
│ - Extract body text         │
│ - Extract metadata          │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│ Prepare Analysis Input      │
│ - Strip quoted replies      │
│ - Remove signatures         │
│ - Format for AI analysis    │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│ AI Analysis (Claude)        │
│ [Full analysis prompt]      │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│ Validate Output             │
│ - Min 1500 chars            │
│ - Required sections present │
│ - At least 3 examples       │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│ Return Result               │
└─────────────────────────────┘
```

---

### 2. Sub-Agent: `approval_guard.json`

**Purpose:** Store pending action and send Slack approval card

**Workflow Inputs:**
```javascript
{
  action_type: "email_send",
  slack_user_id: string,
  slack_channel_id: string,
  slack_thread_ts: string | null,
  user_id: string,              // UUID from alfred.users
  payload: {
    to: string,
    cc: string,
    bcc: string,
    subject: string,
    body_plain: string,
    body_html: string,
    signature_html: string,
    user_email: string
  },
  expiry_minutes: number        // From user preferences
}
```

**Workflow Output:**
```javascript
{
  success: boolean,
  pending_action_id: string,    // UUID for tracking
  approval_message_ts: string,  // Slack message TS
  expires_at: string,           // ISO timestamp
  message: string               // For AI agent response
}
```

**Slack Block Kit Template:**
```javascript
{
  "blocks": [
    {
      "type": "header",
      "text": {
        "type": "plain_text",
        "text": "📧 Email Approval Required",
        "emoji": true
      }
    },
    {
      "type": "section",
      "fields": [
        { "type": "mrkdwn", "text": "*To:*\n${payload.to}" },
        { "type": "mrkdwn", "text": "*From:*\n${payload.user_email}" }
      ]
    },
    {
      "type": "section",
      "text": { "type": "mrkdwn", "text": "*Subject:*\n${payload.subject}" }
    },
    { "type": "divider" },
    {
      "type": "section",
      "text": { "type": "mrkdwn", "text": "*Preview:*" }
    },
    {
      "type": "section",
      "text": { "type": "mrkdwn", "text": ">>> ${truncate(payload.body_plain, 1500)}" }
    },
    {
      "type": "context",
      "elements": [
        { "type": "mrkdwn", "text": "⏰ Expires in ${expiry_minutes} minutes • Requested by <@${slack_user_id}>" }
      ]
    },
    {
      "type": "actions",
      "block_id": "email_approval_${pending_action_id}",
      "elements": [
        {
          "type": "button",
          "text": { "type": "plain_text", "text": "✅ Send Email", "emoji": true },
          "style": "primary",
          "action_id": "approve_action",
          "value": "${pending_action_id}",
          "confirm": {
            "title": { "type": "plain_text", "text": "Send this email?" },
            "text": { "type": "mrkdwn", "text": "This will send the email to *${payload.to}*" },
            "confirm": { "type": "plain_text", "text": "Send" },
            "deny": { "type": "plain_text", "text": "Cancel" }
          }
        },
        {
          "type": "button",
          "text": { "type": "plain_text", "text": "❌ Cancel", "emoji": true },
          "style": "danger",
          "action_id": "reject_action",
          "value": "${pending_action_id}"
        }
      ]
    }
  ]
}
```

---

### 3. Trigger: `approval_handler.json`

**Purpose:** Webhook handler for Slack interactive button clicks

**Trigger Type:** Webhook (receives Slack Block Actions payload)

**Flow:**
```
Slack Block Action Webhook
          │
          ▼
┌─────────────────────────────┐
│ Parse Slack Payload         │
│ - action_id (approve/reject)│
│ - value (pending_action_id) │
│ - user.id (who clicked)     │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│ Lookup pending_action by ID │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│ Validate                    │
│ - Status is 'pending'       │
│ - Not expired               │
│ - User authorized           │
└──────────────┬──────────────┘
               │
      ┌────────┴────────┐
      │                 │
      ▼                 ▼
approve_action    reject_action
      │                 │
      ▼                 ▼
┌─────────────┐  ┌─────────────┐
│ Send Email  │  │ Mark        │
│ via Gmail   │  │ Rejected    │
│ Update DB   │  │ Update DB   │
│ Update Card │  │ Update Card │
└─────────────┘  └─────────────┘
```

---

### 4. Cron: `expire_pending_actions.json`

**Purpose:** Clean up expired pending actions

**Schedule:** Every 5 minutes

**Flow:**
```
Cron Trigger (every 5 min)
          │
          ▼
┌─────────────────────────────┐
│ Find expired pending actions│
│ WHERE status = 'pending'    │
│   AND expires_at < NOW()    │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│ For each expired action:    │
│ 1. Update status='expired'  │
│ 2. Update Slack card        │
│ 3. Optionally notify user   │
└─────────────────────────────┘
```

---

### 5. Modified: `gmail.json`

**New Actions:**
- `get_signature` - Fetch user's Gmail signature

**Modified Actions:**
- `send_email` - Route through signature fetch + approval guard

**Required Scope Addition:**
```
gmail.settings.basic
```

**`get_signature` API Call:**
```
GET https://gmail.googleapis.com/gmail/v1/users/me/settings/sendAs/{user_email}

Response: {
  "sendAsEmail": "spencer@aclarify.com",
  "displayName": "Spencer Marx",
  "signature": "<div>Best regards,<br>Spencer</div>",
  "isPrimary": true
}
```

---

## Tone Prompt Specification

The AI-generated tone prompt must be **thorough enough to serve as a complete style guide**. Required elements:

### Required Structure

```markdown
# Email Writing Style Guide for {User Name}

## Voice & Tone Profile
**Overall Tone:** [description]
**Formality Level:** [1-10 with description]
**Warmth Level:** [1-10 with description]
**Directness:** [description]

## Structural Patterns

### Opening Lines
[Primary patterns with percentages, what to avoid]

### Body Structure
[Paragraph length, email length, formatting triggers]

### Closing Patterns
[Primary and secondary closings with percentages, sign-offs]

## Language Patterns
[Word choices table, contractions, sentence characteristics]

## Contextual Adaptations
[How style shifts for different contexts]

## Signature Phrases & Recurring Expressions
[Frequently used phrases, transitions]

## Few-Shot Examples

### Example 1: [Category]
```
[Actual email from analyzed set]
```
**Why this works:** [Annotation]

### Example 2: [Category]
...

### Example 3: [Category]
...

### Example 4: [Category]
...

### Example 5: [Category]
...

## Anti-Patterns to Avoid
[Explicit list of phrases and patterns to never use]

---
**Analysis metadata:** [emails analyzed, date range]
```

### Validation Requirements

1. **Minimum length:** 1,500 characters
2. **Required sections:** Voice profile, structural patterns, at least 5 examples
3. **Examples must be actual user content** (not AI-generated placeholders)

### AI Analysis Prompt

```
You are an expert writing coach analyzing a user's email writing style to create a comprehensive style guide.

## Your Task
Analyze the provided emails and create a DETAILED, ACTIONABLE style guide that another AI can use to write emails that are indistinguishable from emails the user would write themselves.

## Requirements for Your Analysis

1. **Be Specific and Quantified**
   - Don't say "tends to be concise" — say "averages 5.2 sentences per email"
   - Don't say "often uses bullet points" — say "uses bullet points in 7 of 10 emails when listing 3+ items"

2. **Include Multiple Annotated Examples**
   - Provide at least 5 example emails from the analyzed set
   - For each example, add a brief annotation explaining why it exemplifies the user's style
   - Examples should cover: standard update, external communication, brief acknowledgment, request/ask, and one other notable pattern

3. **Document Anti-Patterns**
   - Explicitly list phrases and patterns the user NEVER uses
   - This is as important as what they DO use

4. **Note Contextual Variations**
   - How does their style shift for different recipient types?
   - How do they handle different email purposes?

5. **Capture Signature Phrases**
   - What recurring phrases or expressions appear across multiple emails?
   - What are their go-to transitions and closings?

## Output Format
Use the exact structure shown in the template. Be thorough — this guide will be used for months without being updated.

Remember: The goal is that someone reading ONLY your style guide (without seeing the original emails) could write emails that the user's colleagues would believe came from the user.
```

---

## UX Flows

### Flow 1: First Email Send (No Tone Configured)

```
User: "Send an email to john@client.com saying the report is ready"

Alfred: "I've drafted the email for John:

         ---
         Subject: Report Ready

         Hi John,

         The report is ready for your review. Let me know if you
         have any questions.

         Best,
         Spencer
         [Your Gmail signature will be added]
         ---

         📋 I've sent this to you for approval.

         Note: You haven't set up your email writing style yet.
         Want me to analyze your sent emails to learn your tone?
         Just say 'learn my email style' anytime."

[Approval card appears in Slack]
```

### Flow 2: Setting Up Tone

```
User: "Learn my email writing style from my recent emails"

Alfred: "I'll analyze your recent sent emails to learn your writing style..."

[30 seconds pass]

Alfred: "I've analyzed 15 of your sent emails from the past 2 weeks.

         **Your Writing Style Profile:**

         • *Tone:* Professional-casual (7/10 formality)
         • *Structure:* Lead with key point, avg 5 sentences
         • *Openings:* 'Hi [Name],' (80%), 'Hey [Name],' (20%)
         • *Closings:* Question prompting response (65%)
         • *Patterns:* Frequent bullet points, avoids jargon

         *Signature phrases I noticed:*
         • 'Quick update —'
         • 'Let me know if you have questions'
         • 'Happy to discuss'

         I've saved this as your email style. You can:
         • Say 'show my full email style guide' to see the details
         • Say 'make it more formal' to adjust
         • Say 'test my email style' to see a sample

         I'll use this style for all your emails going forward."
```

### Flow 3: Adjusting Tone via Chat

```
User: "Make my emails more formal for external recipients"

Alfred: "Updated your email style. For external recipients, I'll now:

         • Use 'Hello' instead of 'Hi'
         • Avoid contractions in the first paragraph
         • Add slightly more context before requests

         Your internal email style stays casual as before.
         Want to see a sample external email in this style?"
```

```
User: "I never use the phrase 'circle back' - add that to things to avoid"

Alfred: "Got it — I've added 'circle back' to your avoid list.

         Current phrases I'll never use for you:
         • 'Circle back'
         • 'Please do not hesitate'
         • 'I hope this email finds you well'
         • 'Per my last email'

         Anything else to add?"
```

### Flow 4: Email with Approval

```
User: "Email sarah@client.com about rescheduling Thursday's meeting to Friday"

Alfred: "I've drafted the email using your style:

         ---
         Subject: Rescheduling Thursday's Meeting

         Hi Sarah,

         Quick heads up — I need to reschedule our Thursday meeting.
         Would Friday at the same time work for you?

         Let me know and I'll send an updated invite.

         Thanks,
         Spencer
         [+ Your Gmail signature]
         ---

         📋 Approval card sent. Click 'Send' when ready, or 'Cancel'
         to discard."

[Slack shows approval card]

User: [Clicks ✅ Send]

[Card updates to "✅ Sent by @spencer"]

Alfred: "Email sent to sarah@client.com."
```

### Flow 5: Expired Approval

```
[60 minutes pass with no action on approval card]

[Card updates to show:]
┌─────────────────────────────────────────────────┐
│ 📧 Email Expired ⏰                             │
│                                                 │
│ To: sarah@client.com                            │
│ Subject: Rescheduling Thursday's Meeting        │
│                                                 │
│ ⏰ Expired - no action taken                    │
│ Request another send if still needed.           │
└─────────────────────────────────────────────────┘
```

---

## Implementation Phases

| Phase | Components | Dependencies | Status |
|-------|------------|--------------|--------|
| **Phase 1: Database** | `014_email_settings.sql`, `015_pending_actions.sql` | None | ✅ Complete |
| **Phase 2: Core HITL** | `approval_guard.json`, `approval_handler.json`, `expire_pending_actions.json` | Phase 1 | ✅ Complete |
| **Phase 3: Gmail Updates** | Modify `gmail.json` (add `get_signature`, route through guard), update `google_auth.json` scopes | Phase 2 | ⚠️ Partial (manual n8n routing needed) |
| **Phase 4: Slack Config** | Configure Interactivity webhook URL | Phase 3 | ⚠️ Manual step required |
| **Phase 5: Tone Analysis** | `analyze_email_tone.json` | Phase 1 | ✅ Complete |
| **Phase 6: Integration** | Update `team_assistant.json` with tone context and instructions | Phase 5 | ✅ Complete |
| **Phase 7: Testing** | End-to-end testing of all flows | All | ⬜ Ready for Testing |

---

## Progress Tracking

### Success Criteria

#### HITL Guard
- [ ] All `send_email` actions create pending_action record
- [ ] Approval card appears in Slack with full preview
- [ ] ✅ Send button sends email via Gmail API
- [ ] ❌ Cancel button marks rejected, updates card
- [ ] Expired actions update card and optionally notify user
- [ ] Gmail signature auto-appended to all emails

#### Email Tone
- [ ] `analyze_email_tone` fetches sent emails and synthesizes comprehensive prompt
- [ ] Generated `tone_prompt` is 2-4KB with all required sections
- [ ] At least 5 annotated examples in generated prompt
- [ ] AI agent uses `tone_prompt` when composing emails
- [ ] Users can adjust tone via natural conversation
- [ ] Users can view full style guide on request

#### Integration
- [ ] New users get sensible defaults (approval on, no tone yet)
- [ ] AI suggests tone setup for users who haven't configured it
- [ ] All components work together in complete flow

---

## Notes & Decisions

### Design Decisions

| Decision | Rationale |
|----------|-----------|
| Fetch Gmail signature at send time | Ensures sync with user's Gmail settings; single source of truth |
| Chat-driven tone adjustments | Maintains conversational UX; no modals or forms |
| Store tone as comprehensive prompt | More accurate than predefined categories; learns user's actual voice |
| Separate webhook for approvals | Block actions need immediate response; can't block AI agent |
| Database storage for pending actions | Survives restarts, enables audit trail, supports expiration |
| Confirmation dialog on approve button | Extra protection against accidental clicks |

### API References

- [Gmail SendAs Resource](https://developers.google.com/workspace/gmail/api/reference/rest/v1/users.settings.sendAs)
- [Gmail SendAs.get Method](https://developers.google.com/gmail/api/reference/rest/v1/users.settings.sendAs/get)
- [Slack Block Kit Builder](https://app.slack.com/block-kit-builder)
- [Slack Interactivity](https://api.slack.com/interactivity)

---

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-02-04 | Initial plan created | Claude + Spencer |
| 2026-02-04 | Implementation complete - all workflows and migrations created | Claude |

---

## Manual Steps Required

The following items require manual action in n8n UI or Slack:

### 1. Run Database Migrations
```bash
# Run these SQL files against your PostgreSQL database
psql $DATABASE_URL -f alfred/migrations/014_email_settings.sql
psql $DATABASE_URL -f alfred/migrations/015_pending_actions.sql
```

### 2. Import New Workflows to n8n
Import these JSON files via n8n UI (Settings > Import):
- `alfred/workflows/sub_agents/approval_guard.json`
- `alfred/workflows/sub_agents/analyze_email_tone.json`
- `alfred/workflows/triggers/approval_handler.json`
- `alfred/workflows/cron/expire_pending_actions.json`

### 3. Connect Gmail send_email to Approval Guard
In n8n UI, modify the `gmail.json` workflow:
1. Find the `send_email` action branch
2. Before the Gmail API call, add an "Execute Workflow" node calling `approval_guard.json`
3. Pass the email details (to, subject, body, etc.) and user context
4. The guard will handle storing the pending action and returning status

### 4. Configure Slack Interactivity Webhook
1. Go to your Slack App settings: https://api.slack.com/apps
2. Navigate to "Interactivity & Shortcuts"
3. Enable Interactivity
4. Set Request URL to your `approval_handler.json` webhook URL (get this from n8n after import)
5. Save Changes

### 5. Verify OAuth Scopes
Ensure your Google OAuth credentials include:
- `gmail.settings.basic` (for signature fetching)
- `gmail.send` (for sending emails)
- `gmail.readonly` (for analyzing sent emails)

### 6. Test the Complete Flow
1. Ask Alfred to send an email
2. Verify approval card appears in Slack
3. Click "Send" and verify email is sent
4. Test "Cancel" and expiration flows
