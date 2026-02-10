# Marketing Team Enhancement Proposal

## Problem Statement

The current Marketing Team implementation is:
1. **Too rigid** - Only handles "generate a post" flow
2. **Too permissive reviewer** - Approves whatever is passed (complacent)
3. **No feedback loop** - Can't revise based on user input after generation
4. **No query capability** - Can't analyze existing content
5. **No constraint passing** - Can't enforce rules like 80/20 value/sales
6. **Silent execution** - User only sees final result, not the team's process
7. **No user approval step** - Content goes to calendar without explicit user sign-off

---

## Proposed Architecture

### Core Principle: Agency + Playbooks + Transparency + User Approval

```
┌─────────────────────────────────────────────────────────────────┐
│                     MARKETING TEAM MANAGER                       │
│                                                                  │
│  FULL AGENCY to handle ANY marketing request                    │
│  + PLAYBOOK TEMPLATES for common scenarios                      │
│  + REAL-TIME PROGRESS UPDATES to user                           │
│  + USER APPROVAL via Slack cards                                │
│                                                                  │
│  Playbooks:                                                      │
│  ├── 📝 NEW_POST: Generate fresh content                        │
│  ├── 🔄 REVISE_POST: Rework based on feedback                   │
│  ├── 🔍 ANALYZE_CONTENT: Query/summarize existing posts         │
│  ├── 📊 SCHEDULED_POST: Generate with constraints (80/20 rule)  │
│  └── 🎯 CUSTOM: Manager decides approach for novel requests     │
│                                                                  │
│  Static Playbook Reference: Rules, constraints, guidelines      │
│                                                                  │
└──────────────────────┬──────────────────────────────────────────┘
                       │
        ┌──────────────┼──────────────┬─────────────┬─────────────┐
        ▼              ▼              ▼             ▼             ▼
   ┌─────────┐   ┌─────────┐   ┌──────────┐  ┌─────────┐  ┌───────────┐
   │BRAIN-   │   │CONTENT  │   │REVIEWER/ │  │IMAGE    │  │CALENDAR   │
   │STORMER  │   │WRITER   │   │EDITOR    │  │GENERATOR│  │MANAGER    │
   │         │   │         │   │          │  │         │  │           │
   │Specialty│   │Specialty│   │Specialty │  │Specialty│  │Specialty  │
   │Generate │   │Write    │   │Critical  │  │Create   │  │Read/Write │
   │ideas    │   │content  │   │review &  │  │visuals  │  │calendar   │
   │         │   │         │   │fact-check│  │         │  │           │
   └─────────┘   └─────────┘   └──────────┘  └─────────┘  └───────────┘

   Workers have NO process knowledge.
   They receive assignments, execute their specialty, return results.
```

---

## Key Design Decisions

| Decision | Answer | Rationale |
|----------|--------|-----------|
| **Max revision iterations** | 3 | Prevents infinite loops while ensuring quality |
| **Progress communication** | Manager sends real-time updates | User sees team's internal dialog, builds trust |
| **Calendar revision behavior** | Overwrite existing row | Clean data, single source of truth per post |
| **Constraint/rule storage** | Static Playbook document | Central reference for rules like 80/20, easy to update |
| **User approval** | Slack approval card in thread | User can approve OR provide feedback inline |

---

## Slack Approval Card System

### Overview

When content is ready for user review, Alfred sends an **approval card** in a Slack thread. The user can:
1. **✅ Approve** - Click button to finalize the post
2. **💬 Provide Feedback** - Reply in thread with changes needed

This leverages the existing `Approval Guard` and `Approval Handler` workflows, made **generic** to support any content type (emails, posts, scheduled tasks, etc.).

### User Experience Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│ SLACK THREAD                                                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│ 👤 User: "Create a LinkedIn post about booking optimization"        │
│                                                                     │
│ 🤖 Alfred: "🧠 Brainstorming ideas..."                              │
│                                                                     │
│ 🤖 Alfred: "✍️ Got a strong angle - drafting content..."            │
│                                                                     │
│ 🤖 Alfred: "🔄 Editor feedback: Hook needs punch - revising..."     │
│                                                                     │
│ 🤖 Alfred: "✅ Approved after 2 revisions - generating images..."   │
│                                                                     │
│ 🤖 Alfred: "✨ Here's your post for review:"                        │
│                                                                     │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ 📝 Content Approval Required                                    │ │
│ │                                                                 │ │
│ │ **Channel:** LinkedIn                                           │ │
│ │ **Topic:** Click Minimization in Booking Experiences            │ │
│ │                                                                 │ │
│ │ **Preview:**                                                    │ │
│ │ > I've been analyzing booking conversion data across 50+        │ │
│ │ > trade businesses, and there's one pattern that stands out... │ │
│ │ > [truncated]                                                   │ │
│ │                                                                 │ │
│ │ 🖼️ Image: [thumbnail]                                          │ │
│ │                                                                 │ │
│ │ 📊 Calendar Status: Under review                                │ │
│ │ ⏰ Expires in 60 minutes                                        │ │
│ │                                                                 │ │
│ │ [✅ Approve & Schedule]  [📝 View Full Post]  [❌ Cancel]       │ │
│ └─────────────────────────────────────────────────────────────────┘ │
│                                                                     │
│ 👤 User: "Make the hook more punchy and add a specific stat"        │
│         (feedback reply in thread)                                  │
│                                                                     │
│ 🤖 Alfred: "📋 Got your feedback - sending back to the team..."     │
│                                                                     │
│ 🤖 Alfred: "✍️ Revising based on your feedback..."                  │
│                                                                     │
│ 🤖 Alfred: "✨ Updated! Here's the revised post:"                   │
│                                                                     │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ 📝 Content Approval Required (Revision 1)                       │ │
│ │ ...                                                             │ │
│ │ [✅ Approve & Schedule]  [📝 View Full Post]  [❌ Cancel]       │ │
│ └─────────────────────────────────────────────────────────────────┘ │
│                                                                     │
│ 👤 User: [clicks ✅ Approve & Schedule]                             │
│                                                                     │
│ 🤖 Alfred: "🎉 Post approved! Calendar updated to 'Ready'"          │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Generic Approval System

The existing approval system (`Approval Guard` + `Approval Handler`) needs to become **content-type agnostic**.

#### Current State (Email-specific)
```
action_type: "send_email"
Card: "📧 Email Approval Required"
       To, From, Subject, Body preview
       [✅ Send Email] [❌ Cancel]
Handler: → Send via Gmail API
```

#### Proposed State (Generic)
```
action_type: "send_email" | "publish_content" | "schedule_task" | ...
Card: Dynamic based on action_type
Handler: Routes to appropriate handler based on action_type
```

### Approval Card Templates

#### For Content Posts (`action_type: "publish_content"`)
```
┌─────────────────────────────────────────────────────────┐
│ 📝 Content Approval Required                            │
│                                                         │
│ **Channel:** LinkedIn                                   │
│ **Topic:** [Post summary/title]                         │
│                                                         │
│ **Preview:**                                            │
│ > [First 500 chars of content]                          │
│                                                         │
│ 🖼️ **Image:** [thumbnail or "None"]                    │
│ 📊 **Calendar:** [Link to row]                          │
│ ⏰ Expires in [X] minutes                               │
│                                                         │
│ [✅ Approve & Schedule] [📝 View Full] [❌ Cancel]      │
└─────────────────────────────────────────────────────────┘
```

#### For Emails (`action_type: "send_email"`)
```
┌─────────────────────────────────────────────────────────┐
│ 📧 Email Approval Required                              │
│                                                         │
│ **To:** recipient@example.com                           │
│ **Subject:** [Subject line]                             │
│                                                         │
│ **Preview:**                                            │
│ > [First 500 chars of body]                             │
│                                                         │
│ ⏰ Expires in [X] minutes                               │
│                                                         │
│ [✅ Send Email] [📝 View Full] [❌ Cancel]              │
└─────────────────────────────────────────────────────────┘
```

### Approval Handler Routing

```
┌─────────────────────────────────────────────────────────────────┐
│                      APPROVAL HANDLER                            │
│                                                                  │
│  Slack Interaction Webhook                                       │
│           │                                                      │
│           ▼                                                      │
│  Parse Payload + Lookup Pending Action                           │
│           │                                                      │
│           ▼                                                      │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ Route by Button Action                                   │    │
│  │  ├── approve_action ──► Route by Content Type            │    │
│  │  │                       ├── send_email ──► Gmail Send   │    │
│  │  │                       ├── publish_content ──► [NEW]   │    │
│  │  │                       │   └► Update Calendar "Ready"  │    │
│  │  │                       │   └► Notify user              │    │
│  │  │                       └── schedule_task ──► [NEW]     │    │
│  │  │                                                       │    │
│  │  └── reject_action ──► Update DB + Card "Cancelled"      │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Thread Feedback Detection

When user replies in a thread (instead of clicking a button), Alfred needs to detect this as feedback:

```
┌─────────────────────────────────────────────────────────────────┐
│                      ALFRED ORCHESTRATOR                         │
│                                                                  │
│  Slack Message Received                                          │
│           │                                                      │
│           ▼                                                      │
│  Is this a thread reply?                                         │
│    │                                                             │
│    ├── YES: Is there a pending approval in this thread?          │
│    │         │                                                   │
│    │         ├── YES: Treat as FEEDBACK on pending content       │
│    │         │        └► Route to Marketing Team (REVISE_POST)   │
│    │         │                                                   │
│    │         └── NO: Normal conversation continuation            │
│    │                                                             │
│    └── NO: New request → Route normally                          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Approval Payload Structure

```json
{
  "action_type": "publish_content",
  "user_id": "uuid",
  "slack_user_id": "U123...",
  "slack_channel_id": "C123...",
  "slack_thread_ts": "1234567890.123456",
  "expiry_minutes": 60,
  "payload": {
    "content_type": "linkedin_post",
    "post_summary": "Click Minimization in Booking",
    "drafts": {
      "linkedin": {
        "content": "Full post content here...",
        "character_count": 1450,
        "hashtags": ["#ServiceTitan", "#HVAC"]
      }
    },
    "images": {
      "linkedin": {
        "url": "https://...",
        "dimensions": "1200x627"
      }
    },
    "calendar_row_id": "row_123",
    "calendar_sheet_id": "sheet_abc"
  }
}
```

### On Approval: Actions Taken

When user clicks **✅ Approve & Schedule**:
1. Update `pending_actions` table → status: "approved"
2. Update Slack card → "✅ Approved by @user"
3. Calendar Manager → Update row status to "Ready" or "Scheduled"
4. Send confirmation message in thread
5. (Optional) Trigger actual posting if auto-publish enabled

### On Feedback (Thread Reply)

When user replies with feedback text:
1. Alfred detects thread reply + pending approval
2. Extracts feedback text
3. Routes to Marketing Team Manager with:
   ```json
   {
     "mode": "revise",
     "previous_content": { ... },
     "user_feedback": "Make the hook more punchy...",
     "calendar_row_id": "row_123"
   }
   ```
4. Marketing Team executes REVISE_POST playbook
5. New approval card sent (replacing or alongside old)

---

## Non-Slack-Origin Requests (Scheduler, Cron, etc.)

When a request originates from a scheduler or other non-Slack source, there's no existing thread for progress updates and approval cards.

### Solution: Create Thread Context

Alfred or the Marketing Team Manager **initiates** the conversation:

```
┌─────────────────────────────────────────────────────────────────────┐
│ SCHEDULER TRIGGER                                                    │
│                                                                      │
│  Scheduled Task: "Generate weekly LinkedIn post (80/20 rule)"        │
│  Target User: @spencer                                               │
│  Target Channel: (optional) #marketing                               │
│                                                                      │
│           │                                                          │
│           ▼                                                          │
│  Alfred sends DM (or channel message):                               │
│  "📅 Starting scheduled content generation..."                       │
│           │                                                          │
│           ▼                                                          │
│  This message becomes the THREAD for:                                │
│  - Progress updates                                                  │
│  - Approval card                                                     │
│  - User feedback                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Routing Priority

1. If `target_channel` specified → Post to channel
2. Else if `target_user` specified → DM to user
3. Else → DM to default admin user

### Initial Message Format

```
📅 **Scheduled Content Generation**

Starting work on: [task description]
Playbook: SCHEDULED_POST
Constraints: 80/20 value rule

I'll update you on progress in this thread...
```

---

## Playbook Management via Slack

Users can view and modify the Marketing Team playbook by asking Alfred directly.

### How It Works

The existing **DB Manager** tool is generic enough to handle CRUD operations on any `alfred.*` table, including `alfred.system_config` where the playbook lives.

```
User: "Show me the current marketing playbook"
Alfred → DB Manager: { action: "read", table: "system_config", key: "marketing.playbook" }

User: "Update the 80/20 rule to 70/30"
Alfred → DB Manager: { action: "update", table: "system_config", key: "marketing.playbook", ... }
```

### No New Tool Required

Alfred coordinates, DB Manager executes. The DB Manager should accept:
- `table`: Any `alfred.*` table name
- `action`: read, update, insert, delete
- `key` or `filters`: Row identification
- `data`: For writes

This keeps the architecture clean - playbook management is just another data operation.

---

## Alfred's Downstream Architecture

Within Alfred's domain, **all specialists are team tools** - even single-agent ones.

```
┌─────────────────────────────────────────────────────────────────────┐
│                           ALFRED                                     │
│                    (Complex Task Orchestrator)                       │
│                                                                      │
│  Team Tools:                                                         │
│  ├── 🎯 Marketing Team                                              │
│  │       Multi-agent team (Brainstormer, Writer, Reviewer, etc.)    │
│  │       For: Content creation, review cycles, calendar management  │
│  │                                                                   │
│  └── 🔧 Utility Worker                                              │
│          Single-agent "team" with all utility tools                  │
│          For: Google Docs, Sheets, DB Manager, Web Search, etc.     │
│          Receives FULL context from Alfred                           │
│                                                                      │
│  Direct Tools:                                                       │
│  └── 💬 Slack (for progress updates, approval cards)                │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Benefits

| Benefit | Description |
|---------|-------------|
| **Consistency** | All delegation follows same pattern (Alfred → Team) |
| **Flexibility** | Alfred can chain: Marketing Team → Utility Worker |
| **Clean mental model** | Teams are specialists, Alfred orchestrates |
| **Full context** | Utility Worker receives Alfred's memory/context |

### Example Flow: Post + Sheet Update

```
User: "Create a LinkedIn post and add it to the Q1 planning sheet"

Alfred:
1. → Marketing Team: "Create LinkedIn post about..."
2. ← Marketing Team: { drafts, images, calendar_row }
3. → Utility Worker: "Add this to Q1 planning sheet: [data]"
4. ← Utility Worker: { success: true, row_id: 45 }
5. → User: "Done! Post created and added to Q1 planning sheet"
```

### Note: Simple vs Complex Routing Unchanged

The upstream routing remains:
- **Simple tasks** → Utility Worker (direct, fast)
- **Complex tasks** → Alfred → Team tools

This change only affects Alfred's downstream architecture.

---

## Static Playbook

A reference document the Manager consults for rules, constraints, and guidelines.

**Storage**: `alfred.system_config` table with key `marketing.playbook`

```markdown
# Marketing Team Playbook

## Content Rules

### 80/20 Value Rule
- 80% of posts should be VALUE content (educational, helpful, insights)
- 20% of posts can be SALES content (product, promotion, CTA-heavy)
- Evaluate against last 20 posts when generating new content
- If ratio is off, next post MUST be the underrepresented type

### Post Quality Standards
- Minimum 2 revision cycles before approval (unless truly exceptional)
- All factual claims must be web-search verified
- Hook must be compelling enough to stop scrolling
- Clear value proposition in first 2 lines

### Channel Requirements
- LinkedIn: 1200-1500 chars, professional tone, 3-5 hashtags
- Twitter/X: 280 chars max, punchy, 1-2 hashtags
- Blog post: 1500-2500 words, SEO headers, meta description

## Scheduled Task Rules
- 3x/week posting cadence
- No back-to-back sales content
- Variety in topics across the week
```

---

## Manager Playbook Templates

### Playbook 1: NEW_POST
```
Trigger: User requests new content creation

Flow:
1. 📢 Update user: "🧠 Brainstorming ideas..."
2. Brainstormer → Generate ideas (pass any constraints from Playbook)
3. 📢 Update user: "✍️ Got a winning angle - drafting content..."
4. Writer → Draft content for winning idea
5. 📢 Update user: "📝 Draft complete - sending to review..."
6. Reviewer → Critical review (iteration 1 of 3)
7. IF revision needed:
   - 📢 Update user: "🔄 Reviewer feedback: [summary] - revising..."
   - Writer → Revise based on feedback
   - Reviewer → Review again (iteration N of 3)
   - Repeat until approved OR iteration 3 reached
8. 📢 Update user: "✅ Content approved - generating images..."
9. Image Generator → Create visuals
10. 📢 Update user: "🖼️ Images ready - updating calendar..."
11. Calendar Manager → Add row (Status: "Under review")
12. 📢 Send approval card in thread for user sign-off
13. AWAIT user response (approve button OR thread feedback)
```

### Playbook 2: REVISE_POST
```
Trigger: User provides feedback on existing post (via thread reply)

Flow:
1. 📢 Update user: "📋 Got your feedback - working on revisions..."
2. Calendar Manager → Fetch existing post data
3. 📢 Update user: "✍️ Revising based on your feedback..."
4. Writer → Revise based on user feedback + existing content
5. 📢 Update user: "📝 Revision complete - reviewing..."
6. Reviewer → Critical review
7. IF revision needed: Loop (max 3 total)
8. 📢 Update user: "🖼️ Updating visuals if needed..."
9. Image Generator → Update visuals if content changed significantly
10. 📢 Update user: "📊 Updating calendar entry..."
11. Calendar Manager → UPDATE existing row (overwrite)
12. 📢 Send NEW approval card for user sign-off
```

### Playbook 3: ANALYZE_CONTENT
```
Trigger: User asks about existing content (themes, patterns, etc.)

Flow:
1. 📢 Update user: "🔍 Fetching recent posts..."
2. Calendar Manager → Fetch recent posts (last N posts)
3. 📢 Update user: "📊 Analyzing patterns..."
4. Manager → Analyze/summarize based on query
5. 📢 Update user: "[Analysis results]"
```

### Playbook 4: SCHEDULED_POST (with constraints)
```
Trigger: Scheduled task with rules (e.g., 80/20 value/sales)

Flow:
1. 📢 Update user: "📊 Checking content balance..."
2. Calendar Manager → Fetch last 20 posts
3. Manager → Calculate current value/sales ratio
4. Manager → Determine what type of content is needed
5. 📢 Update user: "📈 Current ratio: X/Y - generating [VALUE/SALES] content..."
6. Brainstormer → Generate ideas WITH constraint: "MUST be [type] content"
7. Continue NEW_POST flow with constraint awareness throughout
8. Reviewer → Verify constraint compliance (is this actually VALUE content?)
9. 📢 Send approval card (or auto-approve if scheduled task config allows)
```

---

## Worker Specialty Definitions

### Content Brainstormer
**Role**: Idea generation specialist
**Receives from Manager**:
- Topic/direction
- Constraints (if any): "Must be VALUE content", "80/20 rule applies", etc.
- Brand context

**Returns**: Structured ideas with rationale
**NO knowledge of**: What happens after, other workers, process flow

---

### Content Writer
**Role**: Writing specialist
**Receives from Manager**:
- Winning idea to develop
- Target channels
- Feedback (if revision): specific critique to address
- Constraints

**Returns**: Polished drafts per channel
**NO knowledge of**: Review process, calendar, images

---

### Reviewer/Editor (CRITICAL CHANGES)
**Role**: Demanding quality gatekeeper

**Receives from Manager**:
- Drafts to review
- Constraints to verify (e.g., "must be VALUE content")
- Iteration info: "This is revision 2 of 3 max"

**Returns**:
- Detailed critique with scores
- Fact-check results (via web search)
- Clear APPROVE or REVISE decision
- If REVISE: specific, actionable feedback

**Behavioral Requirements**:
```
DEFAULT STANCE: "This needs work"

You are a demanding editor who cares deeply about quality.
Your job is to push the team to excellence, not rubber-stamp content.

ONLY approve content that makes you think "I'd be proud to publish this."

If you're not excited about it, REQUEST REVISIONS with specific feedback.

A typical good piece goes through 2-3 revisions. First drafts are rarely ready.

On iteration 3 of 3: You MUST make a final decision. If still not great,
approve with noted reservations rather than blocking indefinitely.

ALWAYS fact-check claims using web search before approving.
```

**NO knowledge of**: Who wrote it, what happens after approval

---

### Image Generator
**Role**: Visual creation specialist
**Receives from Manager**:
- Approved content for visual context
- Style guidance
- Target channels

**Returns**: Generated images with URLs
**NO knowledge of**: Review process, calendar

---

### Calendar Manager (ENHANCED)
**Role**: Content calendar specialist

**Actions**:
| Action | Description | Parameters |
|--------|-------------|------------|
| `add_row` | Create new calendar entry | Post data |
| `update_row` | **Overwrite existing entry** | Row identifier + new data |
| `read_recent` | Fetch last N posts | Count, optional filters |
| `query` | Search posts by criteria | Search params |

**Receives from Manager**:
- Action type
- Data as appropriate

**Returns**: Requested data or confirmation
**NO knowledge of**: Content creation process

---

## Real-Time Progress Updates

The Manager owns communication with the user throughout the process.

**Update Format**:
```
📢 [Emoji] [Brief status] - [Optional detail]
```

**Examples**:
```
🧠 Brainstorming ideas for LinkedIn post about booking optimization...
✍️ Got a strong angle - writing first draft...
📝 Draft complete - sending to editor for review...
🔄 Editor feedback: "Hook needs more punch, add specific data" - revising...
✍️ Addressing feedback - strengthening the hook...
📝 Revision 2 complete - back to editor...
✅ Approved! "Strong hook, verified stats, on-brand" - generating images...
🖼️ Created LinkedIn-optimized image - updating calendar...
✨ Here's your post for review: [approval card]
```

This gives users visibility into the team's "internal dialog" - they see the back-and-forth, building trust in the process.

---

## Implementation Plan

### Phase 1: Critical Reviewer (Immediate Impact)
**Effort**: Low | **Impact**: High

1. Update Reviewer system prompt to be demanding
2. Add iteration tracking (N of 3)
3. Enforce minimum quality standards
4. Default to requesting revisions

### Phase 2: Calendar Manager Read/Update (Enables Feedback Loop)
**Effort**: Medium | **Impact**: High

1. Add `read_recent` action
2. Add `update_row` action (overwrite, not append)
3. Add `query` action
4. Update workflow inputs/outputs

### Phase 3: Generic Approval System
**Effort**: Medium | **Impact**: High

1. Update `Approval Guard` card builder to be template-driven
2. Add content post card template
3. Update `Approval Handler` to route by content type
4. Add `publish_content` handler (update calendar status)

### Phase 4: Static Playbook (Constraint System)
**Effort**: Low | **Impact**: Medium

1. Create `marketing.playbook` config entry in DB
2. Manager fetches playbook at start of execution
3. Pass relevant constraints to workers
4. Ensure DB Manager is generic for `alfred.*` table CRUD

### Phase 5: Manager Playbooks + Progress Updates
**Effort**: High | **Impact**: High

1. Rewrite Manager system prompt with full playbook templates
2. Add progress update calls throughout flow
3. Add approval card step at end of content flow
4. Enable query/analysis mode

### Phase 6: Thread Feedback Detection
**Effort**: Medium | **Impact**: High

1. Alfred detects thread replies on approval cards
2. Links reply to pending approval
3. Routes as REVISE_POST to Marketing Team
4. Handles revision → new approval card flow

### Phase 7: Alfred Architecture Refactor
**Effort**: Medium | **Impact**: High

1. Refactor Alfred to use team tools pattern
2. Marketing Team as tool (existing, wire up)
3. Utility Worker as tool (pass full context)
4. Add non-Slack-origin thread creation logic
5. Update context passing to include full memory for Utility Worker

---

## Files to Modify

| File/Workflow | Changes |
|---------------|---------|
| `Worker \| Reviewer/Editor` | New demanding system prompt, iteration tracking |
| `Worker \| Content Calendar Manager` | Add read_recent, update_row, query actions |
| `Manager \| Marketing Team` | Full rewrite with playbooks, progress updates, approval step |
| `Tool \| Approval Guard` | Generic card builder with templates |
| `Trigger \| Approval Handler` | Route by content type, add publish_content handler |
| `Alfred Orchestrator` | Thread feedback detection, team tools pattern, non-Slack thread creation |
| `Worker \| Utility Worker` | Ensure accepts full context from Alfred |
| `Tool \| DB Manager` | Verify generic CRUD for any `alfred.*` table |
| `alfred.system_config` | Add `marketing.playbook` entry |

---

## Success Metrics

1. **Review iterations**: Average revisions before approval should be 2-3 (not 1)
2. **User approval rate**: Users actively approve/revise via cards (not ignored)
3. **Feedback loops**: Users can revise posts via thread replies
4. **Constraint compliance**: 80/20 rule maintained across posts
5. **Query capability**: Users can ask about content themes
6. **Transparency**: Users report understanding what the team is doing
