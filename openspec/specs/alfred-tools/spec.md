# alfred-tools Specification

## Purpose
Defines the tool capabilities available to Alfred AI Agent. Tools extend Alfred's functionality by enabling interactions with external services, APIs, and data sources. Each tool follows a consistent pattern: validate inputs, execute the action, format results for Slack, and handle errors gracefully.
## Requirements
### Requirement: Web Search Tool
The system SHALL provide a web search tool that enables Alfred to search the internet for current information and return cited results.

#### Scenario: Basic web search
- **WHEN** Alfred receives a request requiring current/real-time information
- **AND** Alfred invokes the web_search tool with a query
- **THEN** the tool SHALL return search results with inline citations
- **AND** the response SHALL include a sources list with clickable URLs

#### Scenario: Domain-filtered search
- **WHEN** Alfred invokes web_search with an allowed_domains parameter
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
- **AND** Alfred SHALL inform the user gracefully without exposing internal details

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

