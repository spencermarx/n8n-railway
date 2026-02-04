# Alfred - Intelligent Team AI System

## Purpose

Alfred is a JARVIS-inspired AI assistant built on n8n that provides intelligent, proactive assistance to team members via Slack. It orchestrates complex multi-system operations across Google Workspace, Slack, and task management tools while maintaining per-user context, permissions, and personality customization.

**Vision:** Transform from a reactive assistant into an anticipatory AI that handles complex multi-step requests, builds new automations on demand, and proactively manages team workflows.

## Tech Stack

### Core Platform
- **n8n** (v2.6.2+) - Workflow automation platform (self-hosted on Railway)
- **PostgreSQL** - Shared database with isolated `alfred` schema
- **Node.js 22** - Runtime environment

### AI/LLM
- **Claude** (Anthropic) - Primary AI model for agent reasoning
- **Postgres Chat Memory** - Conversation history per user

### Integrations
- **Slack** - Primary user interface (mentions, DMs, slash commands)
- **Google Workspace** - Calendar, Gmail, Docs, Sheets (per-user OAuth)
- **n8n API** - Meta-agent workflow creation capabilities

### Infrastructure
- **Railway** - Cloud hosting platform
- **Docker** - Containerized deployment

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     TRIGGER LAYER                                │
│  Slack Mention → Slack DM → CRON Schedule → Webhook             │
└─────────────────────────────────┬───────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                  CONTEXT & AUTH LAYER                            │
│  User Lookup → Permission Check → Personality Resolution        │
└─────────────────────────────────┬───────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ALFRED CORE AGENT                             │
│  Claude AI Brain with Tool Orchestration                        │
└─────────────────────────────────┬───────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                      TOOL LAYER                                  │
│  Google Calendar │ Gmail │ Docs │ Sheets │ Slack │ Scheduling   │
└─────────────────────────────────┬───────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                    OUTPUT LAYER                                  │
│  Response Router → Slack Formatter → Audit Logger               │
└─────────────────────────────────────────────────────────────────┘
```

## Workflow Organization

### Directory Structure
```
alfred/
├── migrations/              # SQL migrations (versioned, idempotent)
│   ├── 001_create_schema.sql
│   ├── ...
│   └── 015_pending_actions.sql
│
├── workflows/
│   ├── _setup/              # One-time setup workflows
│   │   └── database_schema.json
│   │
│   ├── _infrastructure/     # Internal infrastructure
│   │   └── audit_logger.json
│   │
│   ├── _utilities/          # Shared formatting utilities
│   │   ├── slack_formatter.json
│   │   ├── slack_service.json
│   │   └── email_formatter.json
│   │
│   ├── sub_agents/          # Reusable sub-agent workflows
│   │   ├── user_lookup.json
│   │   ├── permission_checker.json
│   │   ├── response_router.json
│   │   ├── get_personality.json
│   │   ├── approval_guard.json
│   │   └── analyze_email_tone.json
│   │
│   ├── tools/               # AI Agent tools (via toolWorkflow)
│   │   ├── google_calendar.json
│   │   ├── gmail.json
│   │   ├── google_docs.json
│   │   ├── google_sheets.json
│   │   ├── google_auth.json
│   │   ├── user_management.json
│   │   ├── update_user_preferences.json
│   │   ├── daily_schedule_preferences.json
│   │   ├── scheduled_tasks.json
│   │   ├── time_management.json
│   │   └── slack_message.json
│   │
│   ├── triggers/            # Main entry-point workflows
│   │   ├── team_assistant.json    # Primary Alfred agent
│   │   └── approval_handler.json  # HITL approval webhook
│   │
│   └── cron/                # Scheduled workflows
│       ├── unified_task_scheduler.json
│       └── expire_pending_actions.json
│
└── README.md
```

### Naming Conventions
| Prefix | Purpose |
|--------|---------|
| `_` prefix | Internal/infrastructure (not user-facing) |
| `Sub-Agent \|` | Reusable workflows called by other workflows |
| `Tool \|` | AI agent tools (exposed via toolWorkflow) |
| `Trigger \|` | Main entry points (Slack, webhooks) |
| `CRON \|` | Scheduled/recurring workflows |
| `Utility \|` | Shared formatting/helper workflows |

## Database Schema

All Alfred data lives in the `alfred` PostgreSQL schema, isolated from n8n's `public` schema.

### Core Tables

| Table | Purpose |
|-------|---------|
| `alfred.users` | User registry with credentials, role, preferences |
| `alfred.role_permissions` | RBAC permission definitions (admin/member/guest) |
| `alfred.audit_log` | Action audit trail (all actions logged) |
| `alfred.daily_schedule_preferences` | Per-user daily briefing schedules |
| `alfred.scheduled_tasks` | User-scheduled tasks and reminders |
| `alfred.pending_actions` | Human-in-the-loop approval queue |
| `alfred.email_settings` | Per-user email handling preferences |

### Key Functions
- `alfred.get_due_scheduled_tasks()` - Retrieves tasks due for execution
- `alfred.complete_scheduled_task(task_id)` - Marks task as completed
- `alfred.expire_old_pending_actions()` - Cleans up stale approvals

### RBAC Roles

| Role | Description |
|------|-------------|
| `admin` | Full system access, workflow creation, user management |
| `member` | Standard access, personal resources read/write |
| `guest` | Limited read-only access |

## Key Features

### 1. Multi-User Support
- Per-user OAuth credentials for Google services
- Isolated conversation memory per Slack user
- User-specific preferences (timezone, personality, briefing times)

### 2. Personality System
Users can customize Alfred's communication style:
- `alfred` - Alfred Pennyworth (dignified, dry wit) - **default**
- `jarvis` - JARVIS (efficient, analytical)
- `dwight` - Dwight Schrute (intense, literal)
- `jim` - Jim Halpert (laid-back, humorous)
- `donna` - Donna Paulsen (confident, anticipatory)
- `custom` - User-defined personality

### 3. Unified Task Scheduler
Single CRON workflow that handles all scheduled tasks:
- Daily briefings (per-user configured times)
- Scheduled reminders
- Recurring tasks
- Task expiration cleanup

### 4. Human-in-the-Loop (HITL) Approvals
Sensitive actions require user approval:
- Email sending/replying
- Calendar event creation
- Document modifications
- Approval via Slack interactive buttons

### 5. Google Workspace Integration
Full integration with user's Google account:
- **Calendar**: List, create, modify events; find availability
- **Gmail**: Read, send, reply; tone analysis for drafts
- **Docs**: Read, create, append content
- **Sheets**: Read ranges, write data, create spreadsheets

## Important Constraints

### Database Safety
- **NEVER** modify tables in `public` schema (n8n's data)
- All DDL uses `IF NOT EXISTS` for idempotency
- All inserts use `ON CONFLICT DO NOTHING`
- Only operate on `alfred.*` tables

### Credential Management
- Per-user OAuth credentials stored in n8n
- Credential IDs referenced in `alfred.users` table
- Service account option for domain-wide delegation (future)

### Permission Enforcement
- All actions checked against user's effective permissions
- Denied actions logged to audit trail
- User-friendly denial messages with alternatives

## External Dependencies

### Credentials (in n8n)
| Service | Credential ID | Notes |
|---------|---------------|-------|
| PostgreSQL | `8nTSHxonyIBczkvN` | Railway DB, SSL ignored |
| Slack | `apG1iXE1E50lr9RH` | Bot token |
| Anthropic | `iKUsIHimnjBUibjJ` | Claude API |
| Google Calendar | `yBNZEWLXitD9cSiU` | Spencer's OAuth |
| Gmail | `v2wjW0tm9a1TxnZP` | Spencer's OAuth |

### Workflow IDs
| Workflow | ID | Status |
|----------|-----|--------|
| Team Assistant | `KJpZBr3isT66Rzoa` | Active |
| User Lookup | `mHy10eByiuuyr8U1` | Active |
| Audit Logger | `Ui3uhPgKsfXVnIss` | Active |
| Response Router | `aPGhgQ2p6A7aygUt` | Active |
| Get Personality | `Cu7YnA1ZgLBjzSvr` | Active |
| Google Calendar | `9rzYXSNhqSF6tVNC` | Active |
| Gmail | `4o06kwV3LGoZjGY9` | Active |
| Unified Task Scheduler | `RUHxLZdoh1kNNXvs` | Active |
| Approval Handler | `iuU0eyfTN2We4uPR` | Active |
| Approval Guard | `1S0dhI1K4X0528Dy` | Active |

### External URLs
- **n8n Instance**: `https://wrkbelt-ai-team.up.railway.app`
- **Webhook Base**: `https://wrkbelt-ai-team.up.railway.app/webhook/`

## Development Workflow

### Adding a New Tool
1. Create tool workflow in `alfred/workflows/tools/`
2. Add Execute Workflow node in Team Assistant
3. Wire tool to AI Agent's tools array
4. Sync workflow to n8n using curl/API
5. Activate workflow in n8n

### Adding a New User
1. Create OAuth credentials in n8n (if needed)
2. Insert user record into `alfred.users`
3. Set appropriate role (admin/member/guest)
4. Configure preferences (timezone, personality)

### Running Migrations
```bash
# Via n8n workflow (recommended)
# Use "🔧 Setup | Alfred Database Schema" workflow

# Via command line
psql $DATABASE_URL -f alfred/migrations/000_run_all_migrations.sql
```

### Syncing Workflows
```bash
# Download from n8n to local
curl -s -H "X-N8N-API-KEY: $API_KEY" \
  "https://wrkbelt-ai-team.up.railway.app/api/v1/workflows/$ID" | \
  jq '.' > alfred/workflows/path/to/workflow.json
```

## Git Conventions

### Commit Messages
- Use conventional commits: `feat:`, `fix:`, `docs:`, `chore:`
- Reference workflow names when applicable
- Include `Co-Authored-By: Claude` for AI-assisted commits

### Branch Strategy
- `main` - Production-ready code
- Feature branches for new capabilities

## Testing

### Manual Testing
1. Test via Slack @mention: `@Alfred what's on my calendar today?`
2. Test via DM to Alfred bot
3. Verify audit logs in `alfred.audit_log`
4. Check scheduled task execution via CRON logs

### Workflow Validation
- Use n8n's built-in execution testing
- Check for proper error handling paths
- Verify permission checks are enforced
