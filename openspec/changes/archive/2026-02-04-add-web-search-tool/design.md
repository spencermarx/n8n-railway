# Design: Web Search Tool

## Context
Alfred is a Claude-based AI agent that orchestrates tools via n8n workflows. To enable real-time web search, we need to integrate OpenAI's Web Search API (Responses API) as a callable tool. This design addresses the integration pattern, API selection, and output formatting.

## Goals / Non-Goals

**Goals:**
- Give Alfred the ability to search the web for current information
- Return cited, verifiable sources in responses
- Follow existing toolWorkflow pattern for consistency
- Support optional domain filtering for focused searches

**Non-Goals:**
- Deep research mode (multi-minute investigations) - future enhancement
- Caching/storing search results in database
- User-configurable search preferences (v1 uses sensible defaults)

## Decisions

### 1. API Selection: OpenAI Responses API with `web_search` tool
**Decision:** Use OpenAI's Responses API with `{ type: "web_search" }` tool.

**Rationale:**
- Native web search integration - no need to manage search engine APIs separately
- Built-in citation annotations with URLs and titles
- Domain filtering support (up to 100 allowed domains)
- Three tiers available: quick lookup, agentic search, deep research

**Alternatives considered:**
- **Bing Search API**: More control but requires separate API setup, no built-in citation formatting
- **Google Custom Search**: Similar complexity, daily quota limits
- **SerpAPI**: Third-party wrapper, additional cost and dependency

### 2. Integration Pattern: Standalone Tool Workflow
**Decision:** Create `web_search.json` as a standalone toolWorkflow, matching existing patterns like `slack_message.json`.

**Flow:**
```
Alfred Agent → toolWorkflow(web_search) → OpenAI Responses API → Format Citations → Return to Agent
```

**Inputs:**
- `query` (required): The search query
- `context` (optional): Additional context for better results
- `allowed_domains` (optional): Comma-separated domain allow-list

**Outputs:**
- `success`: boolean
- `result`: Search result text with inline citations
- `sources`: Array of cited URLs with titles
- `search_queries`: The actual queries used by OpenAI

### 3. Model Selection for Web Search
**Decision:** Use `gpt-4o` for non-reasoning web search (fast lookups).

**Rationale:**
- Fastest response time for typical queries
- Lower cost than reasoning models
- Sufficient for most real-time information needs
- Can upgrade to `gpt-4o` with reasoning or `o3` for complex research later

### 4. Citation Formatting for Slack
**Decision:** Transform OpenAI's `url_citation` annotations into Slack mrkdwn format.

**Format:**
```
[Search result text with inline citations]

📚 Sources:
• <https://example.com|Title of Source 1>
• <https://example.com/page|Title of Source 2>
```

### 5. Error Handling
**Decision:** Return structured error responses, don't fail silently.

**Error cases:**
- No results found → Return message suggesting query refinement
- API rate limit → Return retry message with backoff suggestion
- Invalid API key → Return configuration error message

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| OpenAI API costs per search | Document cost expectations; consider rate limiting in future |
| Search latency (1-3s typical) | Set user expectations; async isn't needed for this duration |
| OpenAI service outage | Return graceful error; Alfred continues with other tools |
| Stale credential | Standard n8n credential management; clear error message |

## Resolved Questions

1. **User-level search preferences?** → Defer to v2; start simple
2. **Audit logging?** → Yes, log query and success/failure for debugging
3. **Max results per search?** → Let OpenAI determine contextually
