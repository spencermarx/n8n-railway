# alfred-utility-worker Specification

## Purpose
Defines the Utility Worker that handles simple, single-intent tasks with direct access to all tools. The Utility Worker provides a fast execution path for the majority of user requests that don't require team collaboration.

## ADDED Requirements

### Requirement: Utility Worker Tool Access
The Utility Worker SHALL have access to all shared tools for versatile task execution.

#### Scenario: Available tools
- **WHEN** the Utility Worker is initialized
- **THEN** it SHALL have access to:
  - Gmail (list, read, send)
  - Google Calendar (list, create, update, delete, rsvp)
  - Google Docs (read, create, append)
  - Google Sheets (read, write, append, create)
  - Slack Message (send to other users)
  - Web Search
  - User Management (list, lookup)
  - Update User Preferences
  - Time Management
  - Scheduled Tasks
  - Analyze Email Tone
  - Approval Guard

#### Scenario: Tool invocation
- **WHEN** the Utility Worker receives a simple task
- **THEN** the worker SHALL select and invoke appropriate tool(s)
- **AND** the worker SHALL complete the task in a single execution flow

### Requirement: Utility Worker Input Contract
The Utility Worker SHALL accept a standardized input from the orchestrator.

#### Scenario: Input fields
- **WHEN** the orchestrator invokes the Utility Worker
- **THEN** the worker SHALL accept:
  - task_prompt (required): The task to perform
  - user_context (required): slack_user_id, email, name, timezone, role
  - slack_context (required): channel_id, thread_ts, response_type
  - session_id (required): For conversation memory

#### Scenario: Context propagation
- **WHEN** the worker invokes a tool
- **THEN** the worker SHALL pass slack_user_id for credential resolution
- **AND** the worker SHALL include user_context for personalization

### Requirement: Utility Worker Output Contract
The Utility Worker SHALL return a standardized response format.

#### Scenario: Successful execution
- **WHEN** the worker completes a task
- **THEN** the worker SHALL return:
  - success: true
  - result: The response text for the user
  - actions_taken: Array of action summaries
  - requires_approval: Boolean if approval pending
  - pending_action_id: ID if approval required

#### Scenario: Failed execution
- **WHEN** the worker encounters an error
- **THEN** the worker SHALL return:
  - success: false
  - result: null
  - error: Descriptive error message

### Requirement: Utility Worker System Prompt
The Utility Worker SHALL operate with a general-purpose assistant prompt.

#### Scenario: Prompt focus
- **WHEN** the Utility Worker is initialized
- **THEN** its system prompt SHALL:
  - Describe all available tools and their capabilities
  - Include user context (name, email, timezone)
  - Apply user's personality preference
  - Emphasize efficiency and directness
  - Include tool usage rules (email approval, user lookup before send)

#### Scenario: Single-agent execution
- **WHEN** the Utility Worker processes a task
- **THEN** it SHALL complete the task without spawning sub-agents
- **AND** it SHALL use only the tools directly available to it

### Requirement: Utility Worker Performance
The Utility Worker SHALL optimize for speed on simple tasks.

#### Scenario: Execution limits
- **WHEN** the Utility Worker processes a task
- **THEN** the worker SHALL complete within 10 agent iterations maximum
- **AND** the worker SHALL aim for minimal tool calls

#### Scenario: Memory continuity
- **WHEN** the worker processes requests from the same session
- **THEN** the worker SHALL have access to conversation memory via session_id
