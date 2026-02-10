# Design: Hierarchical Multi-Agent Team Architecture

## Context

Alfred currently operates as a monolithic AI agent with 18+ tools. As we expand capabilities (Marketing content, Research, etc.), this architecture cannot scale. Industry best practices point to **hierarchical multi-agent systems** that mirror organizational structures.

### Research Sources

- [LangGraph Hierarchical Agent Teams](https://langchain-ai.github.io/langgraph/tutorials/multi_agent/hierarchical_agent_teams/) - Two-tier supervisor model with subgraphs
- [Design Patterns for Multi-Agent Orchestration](https://www.wethinkapp.ai/blog/design-patterns-for-multi-agent-orchestration) - Coordinator, Pipeline, Role-Based Hierarchy patterns
- [n8n Agent Orchestration Frameworks](https://blog.n8n.io/ai-agent-orchestration-frameworks/) - Agent-to-Agent workflows, hierarchical delegation
- [Agentic Workflows with Claude](https://medium.com/@reliabledataengineering/agentic-workflows-with-claude-architecture-patterns-design-principles-production-patterns-72bbe4f7e85a) - Think → Act → Observe → Correct loops
- [Best Practices for Multi-Agent Orchestration](https://skywork.ai/blog/ai-agent-orchestration-best-practices-handoffs/) - Maker-checker loops, structured handoffs

## Goals / Non-Goals

### Goals
- Route simple tasks through fast path (Utility Worker) to maintain responsiveness
- Enable domain teams to iterate internally via feedback loops
- Support cross-team collaboration for complex multi-domain tasks
- Provide iteration guards to prevent runaway loops
- Make adding new teams/workers a modular operation
- Maintain shared tool layer accessible by any agent

### Non-Goals
- Real-time parallel execution across teams (v1 is sequential with future parallel support)
- Dynamic team creation (teams are predefined, workers can be added)
- Per-agent model selection (all use Claude Sonnet initially)
- Persistent team memory across sessions (conversation memory only)

## Architecture Decisions

### Decision 1: Three-Tier Hierarchy

**Choice**: Orchestrator → Team Manager → Specialist Worker

**Rationale**: Based on LangGraph's hierarchical agent teams pattern:
> "Work is distributed hierarchically... when the job for a single worker becomes too complex"

This mirrors real organizations:
- **Orchestrator** = CEO/Executive (strategic routing)
- **Team Manager** = Department Head (tactical coordination)
- **Specialist Worker** = Individual Contributor (execution)

**Alternatives Considered**:
1. **Flat Orchestrator → Worker** (previous proposal): Doesn't support iterative refinement within domains
2. **Peer-to-Peer Swarm**: Too complex for our use case, harder to trace decisions
3. **Single Supervisor**: Bottleneck as teams scale

### Decision 2: Task Complexity Classification via Predicate Evaluator

**Choice**: Use the existing AI Predicate Evaluator (`Rw7786cYTYOTQhH9`) for intelligent task classification

**Implementation**:
```javascript
// Invoke Predicate Evaluator sub-workflow
const classificationInput = {
  predicate: "isComplex",
  context: JSON.stringify({
    user_request: messageText,
    complexity_criteria: {
      complex_if: [
        "Request involves multiple sequential steps that build on each other",
        "Request requires creative content generation (blog posts, marketing copy, documents)",
        "Request explicitly asks for drafts, revisions, or iterative refinement",
        "Request requires research followed by synthesis or creation",
        "Request involves coordinating across multiple domains (e.g., research + writing + scheduling)"
      ],
      simple_if: [
        "Request is a single query for information (calendar, email lookup, search)",
        "Request is a direct action (send email, schedule event, update preference)",
        "Request can be completed with 1-2 tool calls",
        "Request does not require iteration or revision cycles"
      ]
    }
  })
};

// Predicate Evaluator returns { result: true } for complex, { result: false } for simple
```

**Rationale**:
- Leverages existing infrastructure (Predicate Evaluator uses Claude Haiku for fast, cheap classification)
- AI-based classification is more robust than regex patterns
- Context-aware: can understand nuance and intent
- Easy to tune: just update the complexity_criteria without code changes
- Default to simple (false) ensures fast path for ambiguous requests

### Decision 3: Utility Worker for Simple Path

**Choice**: Single worker workflow with ALL tools attached

**Implementation**:
```
┌─────────────────────────────────────────────────────────────────┐
│                       UTILITY WORKER                             │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  AI Agent (Claude Sonnet)                                │   │
│  │  System Prompt: General-purpose assistant                │   │
│  │  Max Iterations: 10                                      │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                   │
│         ┌────────────────────┼────────────────────┐             │
│         ▼                    ▼                    ▼             │
│  ┌────────────┐      ┌────────────┐      ┌────────────┐         │
│  │ Gmail Tool │      │ Calendar   │      │ Docs Tool  │   ...   │
│  │            │      │ Tool       │      │            │         │
│  └────────────┘      └────────────┘      └────────────┘         │
└─────────────────────────────────────────────────────────────────┘
```

**Rationale**:
- Avoids team overhead for simple requests
- Maintains current UX for majority of interactions
- Can be optimized with smaller model if needed

### Decision 4: Team Manager as Sub-Workflow with Agent

**Choice**: Each team manager is a separate n8n workflow containing:
- Execute Workflow Trigger (input from orchestrator)
- AI Agent node (manages workers)
- Worker dispatch tools (toolWorkflow connections)
- Iteration control logic

**Manager Workflow Structure**:
```
Input → AI Agent (Manager) → [Worker Tools] → Iteration Check → Output
              │                                      │
              └──────── Feedback Loop ◄──────────────┘
```

**Rationale**:
- Managers can make intelligent decisions about worker sequencing
- Feedback loops are managed within the team (not at orchestrator level)
- Teams are self-contained and testable independently

### Decision 5: Feedback Loop Implementation with Overrideable Iteration Caps

**Choice**: Maker-Checker pattern with default iteration guards that can be overridden via user prompt

**Default Iteration Caps by Team**:
| Team | Default Max Iterations | Rationale |
|------|------------------------|-----------|
| Marketing | 3 | Content quality requires refinement but diminishing returns after 3 |
| Communications | 2 | Email/messages benefit from review but shouldn't over-iterate |
| Research | 2 | Fact-checking loop, usually 1-2 passes sufficient |

**Override Detection**:
The orchestrator SHALL detect user intent to override defaults:
- "iterate until perfect" → max_iterations: 10
- "give me 5 revision rounds" → max_iterations: 5
- "quick draft, no revisions" → max_iterations: 0
- "just one review pass" → max_iterations: 1

**Pattern**:
```
1. Maker (e.g., Writer) produces output
2. Checker (e.g., Editor) evaluates output via Predicate Evaluator ("requiresMoreRevisions")
3. If requiresMoreRevisions=true AND iterations < max:
   → Return feedback to Maker
   → Maker revises
   → Go to step 2
4. If requiresMoreRevisions=false OR iterations >= max:
   → Return final output to Manager
```

**Implementation in n8n**:
```javascript
// Iteration Guard Node
const teamDefaults = {
  marketing: 3,
  communications: 2,
  research: 2
};

const teamName = $json.team_name || 'marketing';
const userOverride = $json.user_iteration_override; // From orchestrator parsing
const maxIterations = userOverride !== undefined ? userOverride : teamDefaults[teamName];
const currentIteration = $json.iteration_count || 0;

if (currentIteration >= maxIterations) {
  return [{
    json: {
      action: 'finalize',
      reason: 'max_iterations_reached',
      output: $json.current_draft,
      iterations: currentIteration,
      max_was: maxIterations
    }
  }];
}

// Review result from Predicate Evaluator
if ($json.requires_more_revisions === false) {
  return [{
    json: {
      action: 'finalize',
      reason: 'quality_approved',
      output: $json.current_draft,
      iterations: currentIteration
    }
  }];
}

return [{
  json: {
    action: 'revise',
    feedback: $json.review_feedback,
    current_draft: $json.current_draft,
    iteration_count: currentIteration + 1
  }
}];
```

**Rationale**:
- Prevents infinite loops with sensible defaults
- Respects user intent when they want more/fewer iterations
- Uses Predicate Evaluator for consistent binary quality decisions
- Traceable: logs max_was to show whether default or override was used

### Decision 6: Shared Tool Layer

**Choice**: Tools remain as separate workflows; any agent can access any tool via toolWorkflow

**Architecture**:
```
┌─────────────────────────────────────────────────────────────────┐
│                         TOOL REGISTRY                            │
│                                                                  │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌────────────┐ │
│  │ Gmail Tool  │ │ Docs Tool   │ │ Sheets Tool │ │ Calendar   │ │
│  │ Workflow    │ │ Workflow    │ │ Workflow    │ │ Tool       │ │
│  │ ID: xxx     │ │ ID: xxx     │ │ ID: xxx     │ │ ID: xxx    │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └────────────┘ │
│                                                                  │
│  Access Pattern: Any agent → toolWorkflow → Tool                 │
└─────────────────────────────────────────────────────────────────┘
```

**Rationale**:
- Tools are reusable across all agents
- No duplication of tool logic
- Tool updates apply everywhere
- Permissions enforced at tool level (not agent level)

### Decision 7: Cross-Team Handoff Protocol

**Choice**: Orchestrator manages handoffs with structured context passing

**Handoff Schema**:
```json
{
  "handoff": {
    "from_team": "research",
    "to_team": "marketing",
    "context": {
      "original_request": "Research competitors and write brief",
      "completed_subtask": "Competitor research",
      "output_summary": "Found 5 key competitors...",
      "full_output": { ... },
      "relevant_artifacts": ["doc_id_123"]
    },
    "next_task": {
      "instruction": "Using the research output, create a marketing brief",
      "constraints": ["Include all 5 competitors", "Format as one-pager"]
    }
  }
}
```

**Rationale**:
- Preserves context across team boundaries
- Explicit handoff > implicit shared state
- Orchestrator maintains visibility into cross-team flow

## Team Specifications

### Marketing Team

**Purpose**: Content ideation, creation, and refinement for organic social channels

**Manager System Prompt**:
```
You are the Marketing Team Manager. Your team specializes in creating
compelling content through collaborative ideation, writing, review,
image generation, and content tracking.

Your Team:
- Content Brainstormer: Researches and generates the winning content idea
- Content Writer: Creates channel-specific content drafts
- Reviewer/Editor: Reviews drafts against brand standards and best practices
- Image Generator: Creates AI-generated images for content, saves to Google Drive
- Content Calendar Manager: Updates Content Tracker, saves blog posts to Google Docs

Your Process:
1. Receive content request from orchestrator (may specify channels)
2. Delegate to Content Brainstormer for winning idea
3. Pass winning idea + target channels to Content Writer for drafts
4. Send drafts to Reviewer/Editor for quality assessment
5. FEEDBACK LOOP: If Reviewer says "requiresMoreRevisions", loop Writer with feedback
6. POST-APPROVAL PIPELINE (after content approved):
   a. Delegate to Image Generator for channel-appropriate images
   b. Delegate to Content Calendar Manager to update tracker and save blog
7. Return final content package: drafts + images + tracking info

Default iteration cap: 3 (can be overridden by user)
Supported channels: LinkedIn, Facebook, Twitter/X, Blog
```

**Specialist Workers**:

#### Content Brainstormer
**Purpose**: Generate and validate content ideas based on brand context and trends

**Workflow**:
```
1. PARALLEL FETCH (via new sub-flows):
   ├── Fetch Brand Guide (Google Doc) → brand_guide_content
   ├── Fetch Current Content Strategy (Google Doc) → strategy_content
   └── Fetch Content Calendar (Google Sheets via Analyst worker) → calendar_data

2. CONTEXT ASSEMBLY:
   - Combine brand guide, strategy, and calendar into unified context
   - Note recent posts to avoid repetition

3. IDEA GENERATION:
   - Research 5 potential content ideas using Web Search
   - Evaluate each against brand fit and trending potential

4. TREND ANALYSIS:
   - Use Web Search to assess trending probability for each idea
   - Score ideas by: brand alignment + trend potential + uniqueness

5. OUTPUT:
   - Return winning idea with rationale to Manager
```

**Tools**:
- Google Docs (read Brand Guide, read Content Strategy)
- Google Sheets (read Content Calendar via toolWorkflow)
- Web Search (research and trend validation)

**Output Format**:
```json
{
  "winning_idea": {
    "topic": "string",
    "angle": "string",
    "rationale": "string",
    "trend_score": "number (1-10)",
    "brand_alignment_score": "number (1-10)"
  },
  "runner_up_ideas": [...],
  "context_used": {
    "brand_guide_summary": "string",
    "recent_posts": ["string"],
    "strategy_priorities": ["string"]
  }
}
```

#### Content Writer
**Purpose**: Create channel-specific, brand-aligned content drafts

**Inputs**:
- content_idea: The winning idea from Brainstormer
- target_channels: Array of ["linkedin", "facebook", "twitter", "blog"]
- feedback: Optional revision feedback from Reviewer
- iteration_count: Current iteration number

**Workflow**:
```
1. IF first iteration (no feedback):
   - Analyze content idea and target channels
   - For each channel, apply:
     - Character limits (Twitter: 280, LinkedIn: 3000, etc.)
     - Best practices (hashtags, formatting, CTAs)
     - Brand voice from context

2. IF revision (feedback provided):
   - Parse reviewer feedback
   - Address each point in revised drafts
   - Maintain improvements from previous iteration

3. OUTPUT:
   - Return draft(s) for each requested channel
```

**Tools**: None required (pure LLM generation, can optionally save to Google Docs)

**Output Format**:
```json
{
  "drafts": {
    "linkedin": {
      "content": "string",
      "character_count": "number",
      "hashtags": ["string"]
    },
    "twitter": {
      "content": "string",
      "character_count": "number"
    }
    // ... per requested channel
  },
  "iteration": "number",
  "changes_made": ["string"] // If revision
}
```

#### Reviewer/Editor
**Purpose**: Quality assurance against brand standards and channel best practices

**Workflow**:
```
1. FETCH CONTEXT (via sub-flows):
   ├── Brand Guide (Google Doc)
   ├── Current Content Strategy (Google Doc)
   └── Content Calendar (Google Sheets) - for cohesion check

2. EVALUATE EACH DRAFT against:
   - Brand Guide adherence (voice, tone, values)
   - Content Strategy alignment (messaging pillars, goals)
   - Content Calendar cohesion (not repetitive, builds on recent posts)
   - Writing quality (clarity, engagement, grammar)
   - Virality potential (hooks, emotional resonance, shareability)
   - Channel best practices (format, length, hashtags, CTAs)

3. BINARY DECISION via Predicate Evaluator:
   - Predicate: "requiresMoreRevisions"
   - Context: { draft, evaluation_scores, critical_issues }
   - Returns: true (needs revision) or false (approved)

4. OUTPUT:
   - Detailed feedback if revisions needed
   - Approval with quality scores if passing
```

**Tools**:
- Google Docs (read Brand Guide, Content Strategy)
- Google Sheets (read Content Calendar)
- Predicate Evaluator (binary revision decision)

**Output Format**:
```json
{
  "requires_more_revisions": "boolean",
  "overall_score": "number (1-10)",
  "per_channel_feedback": {
    "linkedin": {
      "brand_alignment": "number",
      "strategy_fit": "number",
      "writing_quality": "number",
      "virality_potential": "number",
      "best_practices": "number",
      "issues": ["string"],
      "suggestions": ["string"]
    }
    // ... per channel
  },
  "critical_issues": ["string"], // Must-fix before approval
  "minor_suggestions": ["string"] // Nice-to-have improvements
}
```

#### Content Calendar Manager
**Purpose**: Track published content and save blog posts to Google Docs

**Inputs**:
- final_drafts: Approved content from review cycle
- content_metadata: { topic, channels, publish_date }
- action: "update_tracker" | "save_blog" | "both"

**Workflow**:
```
1. IF action includes "update_tracker":
   - Connect to Content Calendar Google Sheet (Content Tracker tab)
   - Add row with:
     - Topic/Title
     - Channels published to
     - Publish date
     - Status (draft/published)
     - Link to content (if blog, the Google Doc URL)

2. IF action includes "save_blog":
   - Use Google Docs Create utility to create new document
   - Apply blog formatting (headings, body, conclusion)
   - Set document title based on content topic
   - Return document ID and URL

3. OUTPUT:
   - Confirmation of tracker update
   - Blog document URL if created
```

**Tools**:
- Google Sheets (update Content Tracker via Shared Utility)
- Google Docs (create blog document via Shared Utility)

**Output Format**:
```json
{
  "tracker_updated": "boolean",
  "tracker_row_id": "string",
  "blog_created": "boolean",
  "blog_document": {
    "id": "string",
    "url": "string",
    "title": "string"
  },
  "errors": ["string"]
}
```

#### Image Generator
**Purpose**: Create AI-generated images for content and save to Google Drive

**Inputs**:
- content_context: The content/topic the image should complement
- image_requirements: { style, aspect_ratio, mood, brand_colors }
- target_channels: Which channels need images (different sizes)
- save_location: Google Drive folder path/ID

**Workflow**:
```
1. PROMPT GENERATION:
   - Analyze content context and requirements
   - Generate detailed image prompt based on:
     - Content topic and messaging
     - Brand visual guidelines
     - Target channel requirements (LinkedIn banner vs Twitter card)

2. IMAGE GENERATION via OpenAI:
   - Use OpenAI Image Generation utility (DALL-E 3)
   - Generate image(s) per channel requirements
   - Handle multiple sizes if needed:
     - LinkedIn: 1200x627
     - Twitter: 1600x900
     - Facebook: 1200x630
     - Blog: 1200x800

3. SAVE TO GOOGLE DRIVE:
   - Use Google Drive Save utility
   - Save to specified folder
   - Name with descriptive convention: {topic}_{channel}_{date}.png

4. OUTPUT:
   - Return file URLs and IDs for Manager to use
```

**Tools**:
- OpenAI Image Generation (new Shared Utility)
- Google Drive Save (new Shared Utility)

**Output Format**:
```json
{
  "images_generated": "number",
  "images": {
    "linkedin": {
      "file_id": "string",
      "file_url": "string",
      "dimensions": "1200x627"
    },
    "twitter": {
      "file_id": "string",
      "file_url": "string",
      "dimensions": "1600x900"
    }
  },
  "prompt_used": "string",
  "errors": ["string"]
}
```

## Shared Utility Flows

These are reusable sub-workflows that multiple workers can invoke to avoid duplicating common logic.

### Utility: DB Manager
**Purpose**: Public interface for database operations (config retrieval, logging, etc.)

**Workflow ID**: TBD (to be created)

**Why**: Centralizes all database access, allowing workflows to remain DB-agnostic. Configuration values (like document IDs) are stored in `alfred.system_config` rather than hardcoded.

**Input**:
```json
{
  "action": "get_config | set_config | log_execution",
  "config_key": "string (for get/set_config)",
  "config_value": "any (for set_config)",
  "log_data": "object (for log_execution)"
}
```

**Output**:
```json
{
  "success": "boolean",
  "value": "any (for get_config)",
  "error": "string (if failed)"
}
```

**Pre-configured Keys** (stored in `alfred.system_config`):
| Key | Description | Value |
|-----|-------------|-------|
| `marketing.brand_guide_doc_id` | Brand Guide Google Doc | `14_iOMjdagXCd9vX_wviQm4ruaMxRQOblUj9VL_2tZYY` |
| `marketing.content_calendar_sheet_id` | Content Calendar Google Sheet | `1Txc5v1Eeitm5-xvHleKvtEbH-KhxUk3hyxrBcr89rI0` |
| `marketing.content_strategy_doc_id` | Content Strategy Google Doc | TBD |
| `marketing.image_storage_folder_id` | Google Drive folder for images | TBD |

**Used By**: All workers needing configuration values, team managers for logging

### Utility: Fetch Google Doc
**Purpose**: Retrieve content from a Google Doc by ID or name

**Workflow ID**: TBD (to be created)

**Input**:
```json
{
  "document_id": "string (optional)",
  "document_name": "string (optional)",
  "slack_user_id": "string (required for credential resolution)"
}
```

**Output**:
```json
{
  "success": "boolean",
  "content": "string",
  "document_id": "string",
  "document_title": "string",
  "error": "string (if failed)"
}
```

**Used By**: Content Brainstormer, Reviewer/Editor

### Utility: Write Google Doc
**Purpose**: Create a new Google Doc with formatted content

**Workflow ID**: TBD (to be created)

**Input**:
```json
{
  "title": "string (required)",
  "content": "string (required)",
  "folder_id": "string (optional, defaults to root)",
  "slack_user_id": "string (required for credential resolution)"
}
```

**Output**:
```json
{
  "success": "boolean",
  "document_id": "string",
  "document_url": "string",
  "error": "string (if failed)"
}
```

**Used By**: Content Calendar Manager

### Utility: Update Google Sheet Row
**Purpose**: Add or update a row in a Google Sheet

**Workflow ID**: TBD (to be created)

**Input**:
```json
{
  "spreadsheet_id": "string (required)",
  "sheet_name": "string (required)",
  "row_data": "object (column name → value)",
  "action": "append | update",
  "row_id": "string (required for update)",
  "slack_user_id": "string (required for credential resolution)"
}
```

**Output**:
```json
{
  "success": "boolean",
  "row_id": "string",
  "action_taken": "appended | updated",
  "error": "string (if failed)"
}
```

**Used By**: Content Calendar Manager

### Utility: OpenAI Image Generation
**Purpose**: Generate images using OpenAI's DALL-E 3

**Workflow ID**: TBD (to be created)

**Input**:
```json
{
  "prompt": "string (required)",
  "size": "1024x1024 | 1792x1024 | 1024x1792",
  "quality": "standard | hd",
  "style": "vivid | natural",
  "n": "number (1-10, default 1)"
}
```

**Output**:
```json
{
  "success": "boolean",
  "images": [
    {
      "url": "string (temporary URL)",
      "revised_prompt": "string"
    }
  ],
  "error": "string (if failed)"
}
```

**Used By**: Image Generator

### Utility: Save to Google Drive
**Purpose**: Save a file (from URL or base64) to Google Drive

**Workflow ID**: TBD (to be created)

**Input**:
```json
{
  "source_url": "string (optional, URL to download)",
  "source_base64": "string (optional, base64 content)",
  "file_name": "string (required)",
  "mime_type": "string (required, e.g., 'image/png')",
  "folder_id": "string (optional, defaults to root)",
  "slack_user_id": "string (required for credential resolution)"
}
```

**Output**:
```json
{
  "success": "boolean",
  "file_id": "string",
  "file_url": "string (Google Drive shareable URL)",
  "error": "string (if failed)"
}
```

**Used By**: Image Generator

### Communications Team

**Purpose**: Professional messaging across channels

**Specialist Workers**:

| Worker | Purpose | Tools |
|--------|---------|-------|
| Email Specialist | Email composition | Gmail, Analyze Tone |
| Messaging Specialist | Slack/chat messages | Slack Message |
| Tone Analyst | Style matching | Analyze Email Tone |

### Research Team

**Purpose**: Information gathering and synthesis

**Specialist Workers**:

| Worker | Purpose | Tools |
|--------|---------|-------|
| Web Researcher | Search and gather | Web Search |
| Summarizer | Synthesize findings | None (pure LLM) |
| Fact Checker | Verify claims | Web Search |

## Workflow Directory Structure

```
alfred/workflows/
├── orchestrator/
│   └── team_assistant.json       # Main orchestrator (refactored)
│
├── workers/
│   └── utility_worker.json       # Simple task fast path
│
├── utilities/                    # Shared utility workflows (NEW)
│   ├── db_manager.json           # Public DB interface (config, logging)
│   ├── fetch_google_doc.json     # Read Google Doc by ID/name/config_key
│   ├── write_google_doc.json     # Create new Google Doc
│   ├── update_sheet_row.json     # Add/update Google Sheet row
│   ├── openai_image_generation.json  # Generate images via DALL-E 3
│   └── save_to_google_drive.json # Save file to Google Drive
│
├── teams/
│   ├── marketing/
│   │   ├── manager.json          # Marketing Team Manager
│   │   └── workers/
│   │       ├── brainstorm.json
│   │       ├── writer.json
│   │       ├── editor.json
│   │       ├── calendar_manager.json  # (NEW) Content Tracker + Blog
│   │       └── image_generator.json   # (NEW) AI image generation
│   │
│   ├── communications/
│   │   ├── manager.json
│   │   └── workers/
│   │       ├── email_specialist.json
│   │       ├── messaging_specialist.json
│   │       └── tone_analyst.json
│   │
│   └── research/
│       ├── manager.json
│       └── workers/
│           ├── web_researcher.json
│           ├── summarizer.json
│           └── fact_checker.json
│
├── tools/                        # Shared tool layer (existing)
│   ├── gmail.json
│   ├── google_docs.json
│   └── ...
│
└── sub_agents/                   # Infrastructure (existing)
    ├── user_lookup.json
    └── ...
```

## Database Schema Additions

### Team Execution Logs

```sql
CREATE TABLE alfred.team_execution_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  execution_id VARCHAR(255) NOT NULL,
  team_name VARCHAR(100) NOT NULL,
  manager_workflow_id VARCHAR(100),
  task_summary TEXT,
  started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  completed_at TIMESTAMP WITH TIME ZONE,
  total_iterations INTEGER DEFAULT 0,
  max_iterations_reached BOOLEAN DEFAULT FALSE,
  workers_invoked JSONB,  -- [{worker: 'writer', iterations: 2}, ...]
  final_status VARCHAR(50),  -- 'completed', 'max_iterations', 'error'
  error_message TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_team_logs_execution ON alfred.team_execution_logs(execution_id);
CREATE INDEX idx_team_logs_team ON alfred.team_execution_logs(team_name);
```

### System Configuration

```sql
CREATE TABLE alfred.system_config (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  config_key VARCHAR(255) NOT NULL UNIQUE,
  config_value JSONB NOT NULL,
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_system_config_key ON alfred.system_config(config_key);

-- Seed marketing configuration
INSERT INTO alfred.system_config (config_key, config_value, description) VALUES
  ('marketing.brand_guide_doc_id', '"14_iOMjdagXCd9vX_wviQm4ruaMxRQOblUj9VL_2tZYY"', 'Wrkbelt Brand Guide Google Doc ID'),
  ('marketing.content_calendar_sheet_id', '"1Txc5v1Eeitm5-xvHleKvtEbH-KhxUk3hyxrBcr89rI0"', 'Wrkbelt Content Calendar Google Sheet ID'),
  ('marketing.content_strategy_doc_id', 'null', 'Content Strategy Google Doc ID (TBD)'),
  ('marketing.image_storage_folder_id', 'null', 'Google Drive folder for generated images (TBD)');
```

## Risks / Trade-offs

| Risk | Impact | Mitigation |
|------|--------|------------|
| Increased latency for complex tasks | Medium | Simple path handles 80% of requests quickly |
| Team loops cause token explosion | High | Strict iteration guards (max 3 per task, 10 total) |
| Cross-team handoffs lose context | Medium | Structured handoff schema preserves all context |
| Debugging across teams is harder | Medium | Team execution logs + execution ID tracing |
| Manager makes poor worker decisions | Low | Clear worker descriptions + example routing |

## Migration Plan

### Phase 1: Foundation (Week 1)
- [ ] Create Utility Worker workflow
- [ ] Add task classification to orchestrator
- [ ] Route simple tasks to Utility Worker
- [ ] Validate simple path works end-to-end

### Phase 2: Marketing Team (Week 2)
- [ ] Create Marketing Manager workflow
- [ ] Create Brainstorm Worker
- [ ] Create Writer Worker
- [ ] Create Editor Worker
- [ ] Wire feedback loop with iteration guards

### Phase 3: Integration (Week 3)
- [ ] Connect Marketing Team to orchestrator
- [ ] Add team execution logging
- [ ] Test complex task routing
- [ ] Validate feedback loops work

### Phase 4: Additional Teams (Week 4+)
- [ ] Create Communications Team
- [ ] Create Research Team
- [ ] Enable cross-team handoffs
- [ ] Comprehensive testing

## Resolved Decisions

1. **Quality Threshold for Feedback**: How does Editor determine "quality"?
   - **Decision**: Editor returns `review_passed: boolean` based on LLM judgment
   - Uses Predicate Evaluator with predicate "requiresMoreRevisions" for consistent binary decisions

2. **Team Selection Ambiguity**: What if request spans multiple teams equally?
   - **Decision**: Orchestrator picks primary team, can invoke secondary teams in parallel OR in sequence (if dependencies exist)
   - The main Alfred AI orchestrator makes this decision based on the needs of the request (assuming request is classified as "complex")

3. **Model Selection per Agent**: Should some agents use cheaper/faster models?
   - **Decision**: All Claude Sonnet for consistency (for now)
   - May revisit in future iterations

4. **Session Memory Across Teams**: Should teams share memory?
   - **Decision**: Each team session is isolated
   - The main Alfred AI orchestrator shares relevant context with the team manager being delegated to
   - The team manager then shares relevant context with their workers as needed
   - This maintains clear boundaries while ensuring context flows appropriately
