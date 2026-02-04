# Alfred - Intelligent Team AI System

This directory contains all Alfred-related code, migrations, and workflow definitions.

## Directory Structure

```
alfred/
├── migrations/                    # SQL migration files (version controlled)
│   ├── 000_run_all_migrations.sql # Combined migration runner (includes all below)
│   └── 007_update_personality_default.sql # Update Spencer's personality
│
├── workflows/                     # Exported n8n workflow JSON files
│   ├── _setup/                    # One-time setup workflows
│   │   └── database_schema.json
│   ├── _infrastructure/           # Internal infrastructure workflows
│   │   └── audit_logger.json
│   ├── sub_agents/                # Reusable sub-agent workflows
│   │   ├── user_lookup.json
│   │   ├── permission_checker.json
│   │   ├── response_router.json
│   │   └── get_personality.json   # Personality resolver
│   ├── tools/                     # AI Agent tools (called via toolWorkflow)
│   │   ├── update_user_preferences.json
│   │   ├── google_auth.json       # Google auth router
│   │   ├── google_calendar.json   # Calendar operations
│   │   ├── gmail.json             # Email operations
│   │   ├── google_docs.json       # Docs operations
│   │   ├── google_sheets.json     # Sheets operations
│   │   └── web_search.json        # Web search via OpenAI
│   ├── triggers/                  # Main entry-point workflows
│   └── cron/                      # Scheduled workflows
│
├── scripts/                       # Utility scripts
└── README.md
```

## Workflow Organization

### Naming Convention
- `_` prefix = internal/infrastructure (not user-facing)
- Sub-agents = reusable workflows called by other workflows
- Triggers = main entry points (Slack, webhooks, etc.)
- CRON = scheduled/recurring workflows

### n8n Tags
Workflows are tagged in n8n for filtering:
| Tag | Purpose |
|-----|---------|
| `Alfred` | All Alfred-related workflows |
| `Sub-Agent` | Reusable sub-workflows |
| `Setup` | One-time setup workflows |
| `Internal` | Infrastructure (not user-facing) |
| `Trigger` | Main entry points |
| `CRON` | Scheduled workflows |

## Database Schema

All Alfred data lives in the `alfred` PostgreSQL schema, completely isolated from n8n's `public` schema.

### Tables

| Table | Purpose |
|-------|---------|
| `alfred.users` | User registry with credentials and preferences |
| `alfred.role_permissions` | RBAC permission definitions |
| `alfred.audit_log` | Action audit trail (all actions logged) |

### Roles

| Role | Description |
|------|-------------|
| `admin` | Full system access, can create workflows and manage users |
| `member` | Standard access, can read/write personal resources |
| `guest` | Limited read-only access |

## Running Migrations

### Option 1: n8n Workflow (Recommended)
Use the `🔧 Setup | Alfred Database Schema` workflow in n8n.

### Option 2: Combined SQL Migration
```bash
psql $DATABASE_URL -f alfred/migrations/000_run_all_migrations.sql
```

### Option 3: Individual Migrations
Run each migration file in numerical order.

## Safety Notes

- All migrations are **idempotent** (safe to run multiple times)
- All DDL uses `IF NOT EXISTS` to prevent errors
- All inserts use `ON CONFLICT DO NOTHING` for safe re-runs
- **NEVER** modify n8n's `public` schema tables

## Key Credential IDs

| Credential | ID | Notes |
|------------|-----|-------|
| Postgres | `8nTSHxonyIBczkvN` | Railway DB, SSL issues ignored |
| Google Calendar | `yBNZEWLXitD9cSiU` | Spencer's OAuth |
| Gmail | `v2wjW0tm9a1TxnZP` | Spencer's OAuth |
| Anthropic | `iKUsIHimnjBUibjJ` | API key |
| Slack | `apG1iXE1E50lr9RH` | Bot token |
| OpenAI | `K0dJSGlrxig3qa2p` | Web Search API |

## Workflow IDs

| Workflow | ID | Status |
|----------|-----|--------|
| 🤖 Alfred \| Team Assistant | `KJpZBr3isT66Rzoa` | Active |
| 🔧 Setup \| Alfred Database Schema | `eaZaG81eMN0XJioM` | Inactive (run manually) |
| 🔍 Sub-Agent \| User Lookup | `mHy10eByiuuyr8U1` | Active |
| 📋 Sub-Agent \| Audit Logger | `Ui3uhPgKsfXVnIss` | Active |
| 🔐 Sub-Agent \| Permission Checker | `0UQHV4EGcuywth6R` | Inactive |
| 📤 Sub-Agent \| Response Router | `aPGhgQ2p6A7aygUt` | Active |
| 🎭 Sub-Agent \| Get Personality | `Cu7YnA1ZgLBjzSvr` | Active |
| 🔧 Tool \| Update User Preferences | `XQIgdUEsFw2nH6a7` | Needs activation |
| 🗓️ Tool \| Google Calendar | `OBtXcgpqP8nX2d1b` | Needs implementation |
| 📧 Tool \| Gmail | `psE4SWIXWBtxKbXr` | Needs implementation |
| 📄 Tool \| Google Docs | `47994CB1Uhj0KELL` | Needs implementation |
| 📊 Tool \| Google Sheets | `NKxdmK1mn5lLCFow` | Needs implementation |
| 🌐 Tool \| Web Search | `F0TUHVEzA79rroyS` | Active |

## Conversation Memory

Alfred uses **Postgres Chat Memory** to remember conversation context per user.

### How It Works
- Memory keyed by `slack_user_id` - each user has isolated history
- Stores last 10 message pairs (configurable via `contextWindowLength`)
- Table: `alfred_chat_history` (auto-created by n8n)
- Persists across n8n restarts

### User Experience
```
User: "My favorite color is blue"
Alfred: "Noted! I'll remember that."

[Later...]

User: "What's my favorite color?"
Alfred: "Your favorite color is blue, as you mentioned earlier."
```

### Memory Table Schema (auto-created)
The `alfred_chat_history` table is created automatically by n8n's Postgres Chat Memory node.

## Personality Customization

Users can customize Alfred's personality via the `preferences.personality` field in `alfred.users`.

### Available Personalities

| Key | Character | Style |
|-----|-----------|-------|
| `alfred` | Alfred Pennyworth (Batman) | Dignified butler, dry wit, anticipatory |
| `jarvis` | JARVIS (Iron Man) | Capable AI, efficient, analytical |
| `dwight` | Dwight Schrute (The Office) | Intensely dedicated, confident, literal |
| `jim` | Jim Halpert (The Office) | Laid-back, observant, genuinely helpful |
| `donna` | Donna Paulsen (Suits) | Supremely competent, always ahead |
| `custom` | User-defined | Uses `preferences.custom_personality` |

### Setting User Personality

```sql
-- Set user to JARVIS personality
UPDATE alfred.users
SET preferences = jsonb_set(preferences, '{personality}', '"jarvis"')
WHERE slack_user_id = 'U12345';

-- Set custom personality
UPDATE alfred.users
SET preferences = preferences || '{"personality": "custom", "custom_personality": "You are a friendly pirate assistant..."}'::jsonb
WHERE slack_user_id = 'U12345';
```

### Deploying Personality Feature

1. **Activate the Get Personality sub-workflow** in n8n:
   - Open `🎭 Sub-Agent | Get Personality` (ID: `Cu7YnA1ZgLBjzSvr`)
   - Click "Activate" to publish it

2. **Update the Team Assistant workflow** (if not already done):
   - The JSON in `workflows/triggers/team_assistant.json` contains the updated workflow
   - Copy nodes and connections to n8n, or import the entire workflow

## Google Integration

Alfred has integrated Google tools (Calendar, Gmail, Docs, Sheets) connected to the AI Agent. These tools are wired up in the main workflow but require backend implementation.

### Architecture

The Google tools support a **hybrid authentication model**:
- **@aclarify.com users**: Service Account with Domain-Wide Delegation (impersonation)
- **External users**: Individual OAuth credentials stored per-user

### Setup Requirements

1. **GCP Service Account Setup** (for domain users)
   - Create a service account in Google Cloud Console
   - Enable Domain-Wide Delegation
   - Add required scopes in Google Admin Console:
     - `https://www.googleapis.com/auth/calendar`
     - `https://www.googleapis.com/auth/gmail.modify`
     - `https://www.googleapis.com/auth/documents`
     - `https://www.googleapis.com/auth/spreadsheets`
   - Download the JSON key file

2. **n8n Environment Variable**
   ```
   GOOGLE_SERVICE_ACCOUNT_KEY=<base64-encoded JSON key>
   ```

3. **Database Migration**
   Run migration `008_add_google_auth_method.sql` to add the `google_auth_method` column to users table.

4. **Implement Tool Workflows**
   The tool workflows (Calendar, Gmail, Docs, Sheets) have JSON stubs. They need full implementation with:
   - Google Auth sub-workflow call
   - Action routing (Switch node)
   - API calls via HTTP Request nodes
   - Result formatting

### User Auth Methods

| Method | Description |
|--------|-------------|
| `service_account` | For @aclarify.com domain users (uses impersonation) |
| `oauth_credential` | For external users (uses stored OAuth tokens) |
| `none` | No Google access configured |

### Google Tools Connected to Agent

| Tool | Actions |
|------|---------|
| google_calendar | list_events, create_event, get_availability |
| gmail | list_messages, get_message, send_email |
| google_docs | get_document, create_document, append_text |
| google_sheets | read_range, write_range, append_rows, create_spreadsheet |

## Web Search

Alfred can search the web for real-time information using OpenAI's Responses API with the `web_search_preview` tool.

### Capabilities

- Search for current news and events
- Look up real-time information not in training data
- Domain filtering (limit searches to specific websites)
- Returns results with cited sources formatted for Slack

### Usage Examples

```
@Alfred what's the latest news about AI regulation?
@Alfred search openai.com for the latest API updates
@Alfred what's the current weather in Chicago?
```

### How It Works

1. Alfred receives a request requiring current information
2. Invokes `web_search` tool with the query
3. OpenAI performs web search and returns cited results
4. Results are formatted with Slack-friendly citation links

### Tool Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `query` | Yes | The search query |
| `context` | No | Additional context to improve results |
| `allowed_domains` | No | Comma-separated list of domains to limit search |

### Output Format

```
[Search results with inline information]

📚 Sources:
• <url|Source Title 1>
• <url|Source Title 2>
```

## Related Documentation

- [ALFRED_SPEC.md](../ALFRED_SPEC.md) - Full system specification
- [ALFRED_IMPLEMENTATION_TASKS.md](../ALFRED_IMPLEMENTATION_TASKS.md) - Implementation task list
