# Change: Refactor Alfred to Hierarchical Multi-Agent Team Architecture

## Why

The current Alfred architecture has a single monolithic AI agent with 18+ tools directly connected. While the previous proposal suggested a flat orchestrator → worker model, a **hierarchical team-based architecture** better mirrors real organizational structures and enables:

1. **Task Complexity Routing**: Simple tasks use a fast path; complex tasks get full team orchestration
2. **Emergent Collaboration**: Domain teams can iterate, provide feedback, and refine outputs together
3. **Scalable Team Addition**: New domains (Marketing, Engineering, etc.) are self-contained teams
4. **Specialized Expertise**: Each team has workers with focused skills (brainstorm, write, review)
5. **Feedback Loops**: Maker-checker patterns with iteration guards ensure quality

This approach is validated by industry patterns:
- [LangGraph Hierarchical Agent Teams](https://langchain-ai.github.io/langgraph/tutorials/multi_agent/hierarchical_agent_teams/)
- [Multi-Agent Supervisor Architecture at Scale](https://www.databricks.com/blog/multi-agent-supervisor-architecture-orchestrating-enterprise-ai-scale)
- [n8n Agent Orchestration Frameworks](https://blog.n8n.io/ai-agent-orchestration-frameworks/)

## What Changes

### New Architecture: Three-Tier Hierarchy

```
                           USER REQUEST (Slack)
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        ALFRED ORCHESTRATOR                                   │
│   • Task complexity classification (simple vs complex)                       │
│   • Route to Utility Worker OR Domain Team Manager(s)                       │
│   • Coordinate cross-team collaboration                                      │
│   • Aggregate final responses                                                │
└────────────────────┬─────────────────────────────┬──────────────────────────┘
                     │                             │
         ┌───────────┴───────────┐     ┌───────────┴───────────┐
         ▼                       ▼     ▼                       ▼
┌─────────────────┐      ┌─────────────────────────────────────────────────┐
│ UTILITY WORKER  │      │              DOMAIN TEAM MANAGERS               │
│ (Simple Tasks)  │      │                                                 │
│                 │      │  ┌─────────────┐ ┌─────────────┐ ┌───────────┐  │
│ • All tools     │      │  │ Marketing   │ │Communications│ │ Research │  │
│ • Fast path     │      │  │   Manager   │ │   Manager   │ │  Manager │  │
│ • Single agent  │      │  └──────┬──────┘ └──────┬──────┘ └─────┬─────┘  │
└─────────────────┘      │         │               │              │        │
                         │         ▼               ▼              ▼        │
                         │  ┌────────────┐  ┌────────────┐  ┌──────────┐   │
                         │  │ Specialist │  │ Specialist │  │Specialist│   │
                         │  │  Workers   │  │  Workers   │  │ Workers  │   │
                         │  └────────────┘  └────────────┘  └──────────┘   │
                         └─────────────────────────────────────────────────┘
                                              │
                         ┌────────────────────┴────────────────────┐
                         ▼                                        ▼
              ┌──────────────────────────────────────────────────────────────┐
              │                    SHARED TOOL LAYER                         │
              │  Gmail │ Docs │ Sheets │ Calendar │ Slack │ Web Search │ ... │
              └──────────────────────────────────────────────────────────────┘
```

### Tier 1: Alfred Orchestrator

The top-level orchestrator has three primary responsibilities:

| Responsibility | Description |
|----------------|-------------|
| **Task Classification** | Analyze request complexity: simple (single action) vs complex (multi-step, creative, collaborative) |
| **Routing Decision** | Simple → Utility Worker; Complex → appropriate Domain Team Manager(s) |
| **Cross-Team Coordination** | When multiple teams needed, manage handoffs and aggregate outputs |

**Classification via Predicate Evaluator:**

Uses the existing AI Predicate Evaluator (`Rw7786cYTYOTQhH9`) with predicate `"isComplex"`:
- **Simple (false)**: "What's on my calendar today?", "Send a quick email to John", "Look up X"
- **Complex (true)**: "Research competitors and write a marketing brief", "Draft a document and get feedback", "Create a LinkedIn post about our new product"

Default: Simple (if Predicate Evaluator returns false or errors)

### Tier 2A: Utility Worker (Simple Path)

A single worker with access to **all tools** for fast execution of simple tasks:

- Direct access to: Gmail, Calendar, Docs, Sheets, Slack, Web Search, User Management, etc.
- No team coordination overhead
- Responds directly to orchestrator
- Use case: 80% of requests that are single-intent actions

### Tier 2B: Domain Team Managers (Complex Path)

Each domain has a **Manager Agent** that:
- Receives task delegation from orchestrator
- Decomposes into subtasks for specialist workers
- Manages iteration/feedback loops within the team
- Reports results back to orchestrator

### Tier 3: Specialist Workers

Domain-specific workers with focused capabilities:

| Team | Manager | Specialist Workers |
|------|---------|-------------------|
| **Marketing** | Marketing Manager | Brainstorm Agent, Writer Agent, Editor/Reviewer Agent |
| **Communications** | Comms Manager | Email Specialist, Messaging Specialist, Tone Analyst |
| **Research** | Research Manager | Web Researcher, Summarizer, Fact Checker |
| **Scheduling** | Schedule Manager | Calendar Specialist, Reminder Specialist, Availability Analyst |
| **Data** | Data Manager | Spreadsheet Specialist, Data Analyst, Report Generator |

### Shared Tool Layer

Tools are **not owned by teams** but available to any agent that needs them:

```
┌─────────────────────────────────────────────────────────────────┐
│                      SHARED TOOL REGISTRY                        │
├─────────────────────────────────────────────────────────────────┤
│  Category         │  Tools                                      │
├───────────────────┼─────────────────────────────────────────────┤
│  Documents        │  Google Docs (read, create, append)         │
│  Spreadsheets     │  Google Sheets (read, write, create)        │
│  Email            │  Gmail (list, read, send)                   │
│  Calendar         │  Google Calendar (list, create, update)     │
│  Messaging        │  Slack (send message, DM)                   │
│  Research         │  Web Search                                 │
│  User Data        │  User Lookup, Preferences                   │
│  Time             │  Time Management, Scheduled Tasks           │
│  Approval         │  Approval Guard                             │
│  Analysis         │  Analyze Email Tone                         │
└─────────────────────────────────────────────────────────────────┘
```

### Feedback Loops & Iteration Guards

Teams support **maker-checker patterns** with configurable iteration:

```
┌─────────────────────────────────────────────────────────────────┐
│                    MARKETING TEAM EXAMPLE                        │
│                                                                  │
│   ┌──────────────┐      ┌──────────────┐      ┌──────────────┐ │
│   │  Brainstorm  │ ───► │    Writer    │ ───► │   Editor/    │ │
│   │    Agent     │      │    Agent     │      │   Reviewer   │ │
│   └──────────────┘      └──────┬───────┘      └──────┬───────┘ │
│                                │                      │         │
│                                │    ◄─── Feedback ────┘         │
│                                │         Loop                   │
│                                ▼         (max 3 iterations)     │
│                         ┌──────────────┐                        │
│                         │  Refined     │                        │
│                         │   Output     │                        │
│                         └──────────────┘                        │
└─────────────────────────────────────────────────────────────────┘
```

**Iteration Guard Configuration:**
```json
{
  "team_config": {
    "max_iterations_per_task": 3,
    "max_total_iterations": 10,
    "timeout_seconds": 300,
    "escalate_on_max": true
  }
}
```

### Cross-Team Collaboration

The orchestrator can invoke multiple teams and manage handoffs:

```
User: "Research our competitors and create a marketing brief document"

Orchestrator Analysis:
  → Task Type: Complex (multi-step, cross-domain)
  → Teams Needed: Research Team → Marketing Team
  → Handoff Plan:
      1. Research Team: Gather competitor intel
      2. Marketing Team: Create brief using research output
      3. Orchestrator: Aggregate and deliver
```

## First Implementation: Marketing Team

### Marketing Team Structure

```
Marketing Manager
├── Content Brainstormer
│   └── Fetches Brand Guide (Google Doc)
│   └── Fetches Content Strategy (Google Doc)
│   └── Fetches Content Calendar (Google Sheets)
│   └── Researches 5 ideas, picks winning trending topic
│   └── Tools: Fetch Google Doc, Google Sheets, Web Search
│
├── Content Writer
│   └── Receives winning idea + target channels (LinkedIn, Facebook, Twitter/X, Blog)
│   └── Creates channel-aware, best-practice drafts
│   └── Handles revision feedback from Reviewer
│   └── Tools: None (pure LLM generation)
│
├── Reviewer/Editor
│   └── Reviews drafts against Brand Guide, Content Strategy, Content Calendar
│   └── Evaluates: brand cohesion, writing quality, virality potential, channel best practices
│   └── Uses Predicate Evaluator for binary "requiresMoreRevisions" decision
│   └── Tools: Fetch Google Doc, Google Sheets, Predicate Evaluator
│
├── Content Calendar Manager
│   └── Updates Content Tracker TABLE in Content Calendar Google Sheet
│   └── Creates blog posts as Google Docs
│   └── Links published content for tracking
│   └── Tools: Update Google Sheet Row, Write Google Doc
│
└── Image Generator
    └── Generates AI images for content using OpenAI DALL-E 3
    └── Creates channel-appropriate sizes (LinkedIn, Twitter, Facebook, Blog)
    └── Saves to Google Drive with proper naming
    └── Tools: OpenAI Image Generation, Save to Google Drive
```

### Shared Utility Flows

Common operations are packaged into reusable sub-workflows:

| Utility | Purpose | Used By |
|---------|---------|---------|
| **DB Manager** | Public interface for database (config, logging) | All workers |
| Fetch Google Doc | Read content from a Google Doc by ID/name | Brainstormer, Reviewer |
| Write Google Doc | Create a new Google Doc with formatted content | Calendar Manager |
| Update Google Sheet Row | Add/update row in a Google Sheet | Calendar Manager |
| OpenAI Image Generation | Generate images via DALL-E 3 | Image Generator |
| Save to Google Drive | Save file (URL or base64) to Drive | Image Generator |

### Database-Stored Configuration

Configuration values are stored in `alfred.system_config` (not hardcoded):

| Key | Description |
|-----|-------------|
| `marketing.brand_guide_doc_id` | Wrkbelt Brand Guide Google Doc |
| `marketing.content_calendar_sheet_id` | Wrkbelt Content Calendar Google Sheet |
| `marketing.content_strategy_doc_id` | Content Strategy Google Doc |
| `marketing.image_storage_folder_id` | Google Drive folder for images |

### Marketing Team Workflow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         MARKETING TEAM WORKFLOW                              │
│                                                                              │
│  1. Manager receives task + channels (e.g., "Create LinkedIn post about X") │
│                              │                                               │
│                              ▼                                               │
│  2. ┌─────────────────────────────────────────────┐                         │
│     │        CONTENT BRAINSTORMER                  │                         │
│     │  ┌────────────────────────────────────────┐ │                         │
│     │  │ PARALLEL FETCH (via Shared Utilities): │ │                         │
│     │  │  • Brand Guide (Google Doc)            │ │                         │
│     │  │  • Content Strategy (Google Doc)       │ │                         │
│     │  │  • Content Calendar (Google Sheets)    │ │                         │
│     │  └────────────────────────────────────────┘ │                         │
│     │  Research 5 ideas → Pick highest trending   │                         │
│     └─────────────────────┬───────────────────────┘                         │
│                           │ winning_idea                                     │
│                           ▼                                                  │
│  3. ┌─────────────────────────────────────────────┐                         │
│     │        CONTENT WRITER                        │                         │
│     │  Create drafts for each target channel      │                         │
│     │  (LinkedIn, Facebook, Twitter/X, Blog)      │                         │
│     └─────────────────────┬───────────────────────┘                         │
│                           │ drafts                                           │
│                           ▼                                                  │
│  4. ┌─────────────────────────────────────────────┐                         │
│     │        REVIEWER/EDITOR                       │                         │
│     │  Evaluate vs Brand Guide, Strategy, Calendar│                         │
│     │  Check: quality, virality, best practices   │                         │
│     │  → Predicate: "requiresMoreRevisions"       │                         │
│     └─────────────────────┬───────────────────────┘                         │
│                           │                                                  │
│              ┌────────────┴────────────┐                                     │
│              │ requiresMoreRevisions?  │                                     │
│              └────────────┬────────────┘                                     │
│                 TRUE      │      FALSE                                       │
│           ┌───────────────┴───────────────┐                                  │
│           │                               │                                  │
│           ▼                               ▼                                  │
│    [iterations < max?]            5. POST-APPROVAL PIPELINE                  │
│       YES → Loop to Writer              │                                    │
│       NO → Finalize anyway              ▼                                    │
│                            ┌────────────────────────────┐                    │
│                            │     IMAGE GENERATOR        │                    │
│                            │  Generate channel images   │                    │
│                            │  Save to Google Drive      │                    │
│                            └─────────────┬──────────────┘                    │
│                                          ▼                                   │
│                            ┌────────────────────────────┐                    │
│                            │  CONTENT CALENDAR MANAGER  │                    │
│                            │  Update Content Tracker    │                    │
│                            │  Save blog to Google Doc   │                    │
│                            └─────────────┬──────────────┘                    │
│                                          ▼                                   │
│                            6. FINALIZE: Return content                       │
│                               + images + tracking info                       │
│                               to orchestrator                                │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Iteration Caps

| Default | Override Examples |
|---------|-------------------|
| 3 iterations | "iterate until perfect" → 10 |
| | "quick draft, no revisions" → 0 |
| | "give me 5 revision rounds" → 5 |

## Impact

- **New specs**: `alfred-orchestrator`, `alfred-team-managers`, `alfred-specialist-workers`, `alfred-shared-utilities`
- **Modified specs**: `alfred-tools` (converted to shared layer)
- **New workflows**:
  - `alfred/workflows/orchestrator/team_assistant.json` (refactored)
  - `alfred/workflows/workers/utility_worker.json`
  - `alfred/workflows/teams/marketing/manager.json`
  - `alfred/workflows/teams/marketing/workers/brainstorm.json`
  - `alfred/workflows/teams/marketing/workers/writer.json`
  - `alfred/workflows/teams/marketing/workers/editor.json`
  - `alfred/workflows/teams/marketing/workers/calendar_manager.json`
  - `alfred/workflows/teams/marketing/workers/image_generator.json`
- **New shared utilities**:
  - `alfred/workflows/utilities/db_manager.json` (public DB interface)
  - `alfred/workflows/utilities/fetch_google_doc.json`
  - `alfred/workflows/utilities/write_google_doc.json`
  - `alfred/workflows/utilities/update_sheet_row.json`
  - `alfred/workflows/utilities/openai_image_generation.json`
  - `alfred/workflows/utilities/save_to_google_drive.json`
- **Database**:
  - Add `alfred.system_config` for configuration storage (doc IDs, folder IDs, etc.)
  - Add `alfred.team_execution_logs` for iteration tracking

### Migration Path

1. **Phase 1**: Create Utility Worker + task classification in orchestrator
2. **Phase 1.5**: Create Shared Utility workflows (Google Doc, Sheets, Drive, OpenAI)
3. **Phase 2**: Create Marketing Team (manager + 5 workers)
4. **Phase 3**: Add feedback loop infrastructure
5. **Phase 4**: Create additional teams (Communications, Research, etc.)
6. **Phase 5**: Enable cross-team collaboration

### Breaking Changes

- **BREAKING**: Tool access now through shared layer (not direct attachment)
- **BREAKING**: Complex requests route through teams (changed latency profile)
- Simple requests remain fast via Utility Worker path
