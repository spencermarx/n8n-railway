# Change: Add Web Search Tool to Alfred

## Why
Alfred currently lacks the ability to search the web for real-time information. Users asking about current events, recent news, live data, or information outside Alfred's training data receive stale or incomplete answers. Adding web search enables Alfred to provide up-to-date, cited responses.

## What Changes
- Add new `web_search.json` tool workflow in `alfred/workflows/tools/`
- Wire the tool to Alfred AI Agent in `team_assistant.json` via `toolWorkflow` node
- Store OpenAI API credentials in n8n for Responses API access
- Format search results with Slack-friendly citations

## Impact
- **Affected specs**: `alfred-tools` (new capability)
- **Affected code**: 
  - `alfred/workflows/tools/web_search.json` (new)
  - `alfred/workflows/triggers/team_assistant.json` (add tool node)
- **New dependency**: OpenAI API (Responses API with web_search tool)
- **Cost implications**: OpenAI charges per web search tool call (see pricing)
