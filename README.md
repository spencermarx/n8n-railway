# n8n-railway

Self-hosted [n8n](https://n8n.io) instance on Railway, powering **Alfred** - an intelligent team AI assistant.

## Quick Start

```bash
# Clone the repository
git clone https://github.com/aclarify/n8n-railway.git
cd n8n-railway

# Deploy to Railway (requires Railway CLI)
railway up
```

## What's Included

### n8n Platform
- **Version**: 2.6.2+
- **Runtime**: Node.js 22 Alpine
- **Database**: PostgreSQL (Railway-managed)

### Alfred - AI Team Assistant

Alfred is a JARVIS-inspired AI assistant that provides intelligent, proactive assistance via Slack. It orchestrates operations across Google Workspace while maintaining per-user context, permissions, and personality customization.

**Key Features:**
- Slack integration (mentions, DMs)
- Google Calendar, Gmail, Docs, Sheets integration
- Per-user OAuth credentials and preferences
- Role-based access control (admin/member/guest)
- Customizable AI personalities
- Scheduled tasks and daily briefings
- Human-in-the-loop approval workflows

## Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                        ALFRED SYSTEM                            │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  TRIGGERS           CORE AGENT          TOOLS                  │
│  ─────────          ──────────          ─────                  │
│  Slack Mention  →   Claude AI    →      Google Calendar        │
│  Slack DM       →   (Claude)     →      Gmail                  │
│  CRON Schedule  →   User Context →      Google Docs            │
│  Webhooks       →   Permissions  →      Google Sheets          │
│                                         Slack Messaging        │
│                                         Task Scheduling        │
│                                                                │
│  INFRASTRUCTURE                                                │
│  ──────────────                                                │
│  PostgreSQL (alfred schema)                                    │
│  Audit Logging                                                 │
│  Approval Workflows                                            │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
n8n-railway/
├── Dockerfile              # n8n container configuration
├── .env                    # Environment variables (Railway)
│
├── alfred/                 # Alfred AI assistant
│   ├── migrations/         # SQL migrations (15 files)
│   │   ├── 001_create_schema.sql
│   │   ├── ...
│   │   └── 015_pending_actions.sql
│   │
│   ├── workflows/          # n8n workflow JSON exports
│   │   ├── triggers/       # Main entry points (2 workflows)
│   │   ├── tools/          # AI agent tools (12 workflows)
│   │   ├── sub_agents/     # Reusable sub-workflows (6 workflows)
│   │   ├── cron/           # Scheduled jobs (2 workflows)
│   │   ├── _utilities/     # Formatting helpers (3 workflows)
│   │   ├── _infrastructure/# Internal workflows (1 workflow)
│   │   └── _setup/         # Setup workflows (1 workflow)
│   │
│   └── README.md           # Alfred-specific documentation
│
├── openspec/               # OpenSpec project documentation
│   └── project.md          # Comprehensive system spec
│
├── ALFRED_SPEC.md          # Full Alfred specification
└── ALFRED_IMPLEMENTATION_TASKS.md  # Implementation checklist
```

## Workflows (26 Active)

### Triggers
| Workflow | Description |
|----------|-------------|
| Team Assistant | Main Alfred agent - handles Slack interactions |
| Approval Handler | Processes HITL approval button clicks |

### Tools (AI Agent Callable)
| Workflow | Capabilities |
|----------|--------------|
| Google Calendar | List, create, modify events; find availability |
| Gmail | Read, send, reply; with tone analysis |
| Google Docs | Read, create, append content |
| Google Sheets | Read/write ranges, create spreadsheets |
| Slack Message | Send formatted messages |
| Scheduled Tasks | Create/manage user reminders |
| Time Management | Timezone-aware time operations |
| User Management | CRUD operations for users (admin) |
| Daily Schedule | Manage briefing preferences |
| Update Preferences | Modify user settings |

### CRON Jobs
| Workflow | Schedule | Purpose |
|----------|----------|---------|
| Unified Task Scheduler | Every 5 min | Execute due tasks & briefings |
| Expire Pending Actions | Hourly | Clean up stale approvals |

## Database Schema

All Alfred data lives in the `alfred` PostgreSQL schema, completely isolated from n8n's `public` schema.

### Tables
| Table | Purpose |
|-------|---------|
| `alfred.users` | User registry (credentials, role, preferences) |
| `alfred.role_permissions` | RBAC definitions |
| `alfred.audit_log` | Action audit trail |
| `alfred.daily_schedule_preferences` | Per-user briefing schedules |
| `alfred.scheduled_tasks` | User reminders and tasks |
| `alfred.pending_actions` | HITL approval queue |
| `alfred.email_settings` | Email handling preferences |

### Running Migrations
```bash
# Using n8n workflow (recommended)
# Execute "🔧 Setup | Alfred Database Schema" workflow

# Or via CLI
psql $DATABASE_URL -f alfred/migrations/000_run_all_migrations.sql
```

## Configuration

### Environment Variables
```bash
DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=<railway-host>
DB_POSTGRESDB_PORT=<port>
DB_POSTGRESDB_DATABASE=railway
DB_POSTGRESDB_USER=postgres
DB_POSTGRESDB_PASSWORD=<password>

WEBHOOK_URL=https://wrkbelt-ai-team.up.railway.app
PORT=5678

# Execution settings
EXECUTIONS_DATA_PRUNE=true
EXECUTIONS_DATA_PRUNE_MAX_COUNT=200
```

### Required n8n Credentials
| Service | Purpose |
|---------|---------|
| PostgreSQL | Database access |
| Slack | Bot token for messaging |
| Anthropic | Claude API for AI |
| Google Calendar OAuth | Per-user calendar access |
| Gmail OAuth | Per-user email access |

## Development

### Syncing Workflows
Download workflows from n8n to local JSON files:

```bash
API_KEY="your-api-key"
BASE_URL="https://wrkbelt-ai-team.up.railway.app/api/v1/workflows"

# Sync a single workflow
curl -s -H "X-N8N-API-KEY: $API_KEY" "$BASE_URL/$WORKFLOW_ID" | \
  jq '.' > alfred/workflows/path/to/workflow.json
```

### Adding a New User
1. Create OAuth credentials in n8n for their Google account
2. Insert into `alfred.users`:
```sql
INSERT INTO alfred.users (
  slack_user_id, slack_username, email, role,
  google_calendar_credential_id, gmail_credential_id
) VALUES (
  'UXXXXXXXX', 'username', 'user@example.com', 'member',
  'credential-id', 'credential-id'
);
```

### Adding a New Tool
1. Create workflow in `alfred/workflows/tools/`
2. Add Execute Workflow node in Team Assistant
3. Connect to AI Agent's tools array
4. Deploy and activate in n8n

## Personality System

Users can customize Alfred's communication style:

| Key | Character | Description |
|-----|-----------|-------------|
| `alfred` | Alfred Pennyworth | Dignified butler, dry wit (default) |
| `jarvis` | JARVIS | Efficient AI, analytical |
| `dwight` | Dwight Schrute | Intense, literal |
| `jim` | Jim Halpert | Laid-back, humorous |
| `donna` | Donna Paulsen | Confident, anticipatory |
| `custom` | User-defined | Custom personality prompt |

Set via:
```sql
UPDATE alfred.users
SET preferences = jsonb_set(preferences, '{personality}', '"jarvis"')
WHERE slack_user_id = 'UXXXXXXXX';
```

## RBAC Permissions

| Role | Capabilities |
|------|--------------|
| `admin` | Full access, workflow creation, user management |
| `member` | Personal resources, read/write own data |
| `guest` | Read-only access to shared resources |

## Related Documentation

- [alfred/README.md](alfred/README.md) - Detailed Alfred documentation
- [ALFRED_SPEC.md](ALFRED_SPEC.md) - Full system specification
- [ALFRED_IMPLEMENTATION_TASKS.md](ALFRED_IMPLEMENTATION_TASKS.md) - Implementation checklist
- [openspec/project.md](openspec/project.md) - OpenSpec project context

## License

Private repository - Aclarify internal use only.
