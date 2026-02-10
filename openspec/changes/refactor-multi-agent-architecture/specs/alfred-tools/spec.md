# alfred-tools Specification (Delta)

## Purpose
Updates to the alfred-tools specification reflecting the shared tool layer architecture where tools are accessible by any agent (Utility Worker, Team Managers, or Specialist Workers) rather than being owned by specific domains.

## MODIFIED Requirements

### Requirement: Web Search Tool
The system SHALL provide a web search tool that enables Alfred agents to search the internet for current information and return cited results. **This tool is now part of the shared tool layer accessible by multiple agents.**

#### Scenario: Basic web search
- **WHEN** any Alfred agent (Utility Worker, Brainstorm Worker, Web Researcher) invokes web_search
- **AND** the agent passes a query parameter
- **THEN** the tool SHALL return search results with inline citations
- **AND** the response SHALL include a sources list with clickable URLs

#### Scenario: Domain-filtered search
- **WHEN** an agent invokes web_search with an allowed_domains parameter
- **THEN** search results SHALL be limited to the specified domains
- **AND** results from other domains SHALL be excluded

#### Scenario: No results found
- **WHEN** a web search returns no relevant results
- **THEN** the tool SHALL return success=false
- **AND** the tool SHALL include a message suggesting query refinement

#### Scenario: API error handling
- **WHEN** the OpenAI API returns an error (rate limit, auth failure, etc.)
- **THEN** the tool SHALL return success=false
- **AND** the tool SHALL include a descriptive error message
- **AND** the invoking agent SHALL inform the user gracefully

### Requirement: Web Search Citation Formatting
The system SHALL format web search citations for optimal display in Slack.

#### Scenario: Citation display in Slack
- **WHEN** web search results are returned to the user via Slack
- **THEN** inline citations SHALL be preserved in the response text
- **AND** a "Sources" section SHALL list each cited URL with its title
- **AND** URLs SHALL be formatted as clickable Slack links (`<url|title>`)

### Requirement: Web Search Audit Logging
The system SHALL log web search tool invocations to the audit trail.

#### Scenario: Successful search logged
- **WHEN** a web search completes successfully
- **THEN** an audit log entry SHALL be created with action="web_search"
- **AND** the entry SHALL include the search query (not full results)
- **AND** the entry SHALL include success=true

#### Scenario: Failed search logged
- **WHEN** a web search fails
- **THEN** an audit log entry SHALL be created with action="web_search"
- **AND** the entry SHALL include success=false
- **AND** the entry SHALL include the error type

## ADDED Requirements

### Requirement: Shared Tool Layer Architecture
Tools SHALL be organized as a shared layer accessible by any authorized agent.

#### Scenario: Tool accessibility
- **WHEN** an agent (Utility Worker, Team Manager, or Specialist Worker) needs a tool
- **THEN** the agent MAY access any tool in the shared layer
- **AND** tool access SHALL be configured via toolWorkflow connections

#### Scenario: Tool registry
- **WHEN** the system is configured
- **THEN** the shared tool layer SHALL include:
  - Gmail (email operations)
  - Google Calendar (calendar operations)
  - Google Docs (document operations)
  - Google Sheets (spreadsheet operations)
  - Slack Message (messaging operations)
  - Web Search (research operations)
  - User Management (user operations)
  - Update User Preferences (preference operations)
  - Time Management (time operations)
  - Scheduled Tasks (scheduling operations)
  - Analyze Email Tone (analysis operations)
  - Approval Guard (approval operations)
  - Google Auth (authentication)

### Requirement: Tool Credential Resolution
Tools SHALL resolve user credentials based on passed context.

#### Scenario: Credential passthrough
- **WHEN** any agent invokes a tool
- **THEN** the agent SHALL pass slack_user_id in the request
- **AND** the tool SHALL use slack_user_id to resolve per-user OAuth credentials

#### Scenario: Credential validation
- **WHEN** a tool receives a request without valid credential context
- **THEN** the tool SHALL return an error indicating missing credentials
- **AND** the tool SHALL NOT fall back to default credentials

### Requirement: Tool Agent Agnosticism
Tools SHALL operate independently of which agent type invokes them.

#### Scenario: Consistent behavior
- **WHEN** a tool is invoked by Utility Worker vs Specialist Worker
- **THEN** the tool SHALL behave identically
- **AND** the tool output format SHALL be consistent

#### Scenario: Context propagation
- **WHEN** a tool needs user context
- **THEN** the invoking agent SHALL pass user_context
- **AND** the tool SHALL extract needed fields (email, timezone, role)
