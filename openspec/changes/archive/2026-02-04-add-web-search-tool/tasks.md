# Tasks: Add Web Search Tool

## 1. Setup & Configuration
- [x] 1.1 Create OpenAI API credential in n8n (if not exists)
- [x] 1.2 Document credential ID in `openspec/project.md` under External Dependencies

## 2. Tool Workflow Implementation
- [x] 2.1 Create `alfred/workflows/tools/web_search.json` workflow
  - Workflow Input trigger with `query`, `context`, `allowed_domains` parameters
  - Input validation node
  - HTTP Request node calling OpenAI Responses API
  - Citation formatter node (transform annotations to Slack mrkdwn)
  - Success/error response formatting
- [x] 2.2 Test workflow standalone in n8n with sample queries

## 3. Agent Integration
- [x] 3.1 Add `Tool: Web Search` toolWorkflow node to `team_assistant.json`
- [x] 3.2 Wire tool to Alfred AI Agent's tools array
- [x] 3.3 Update system prompt to describe web search capability and when to use it
- [x] 3.4 Sync updated workflow to n8n

## 4. Testing & Validation
- [x] 4.1 Test via Slack: `@Alfred what's the latest news about [topic]?`
- [x] 4.2 Test domain filtering: `@Alfred search openai.com for latest API updates`
- [x] 4.3 Verify citations display correctly in Slack
- [x] 4.4 Test error handling (invalid query, API errors)

## 5. Documentation
- [x] 5.1 Add web_search workflow ID to `openspec/project.md` Workflow IDs table
- [x] 5.2 Update README with web search capability notes
