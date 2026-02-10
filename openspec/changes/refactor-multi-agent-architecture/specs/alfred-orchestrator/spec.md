# alfred-orchestrator Specification

## Purpose
Defines the Alfred Orchestrator Agent that serves as the top-level coordinator in a three-tier hierarchical multi-agent system. The orchestrator classifies task complexity, routes to appropriate handlers (Utility Worker or Domain Team Managers), and coordinates cross-team collaboration.

## ADDED Requirements

### Requirement: Task Complexity Classification via Predicate Evaluator
The orchestrator SHALL use the AI Predicate Evaluator to classify incoming requests as either "simple" or "complex".

#### Scenario: Simple task classification
- **WHEN** a user sends a single-intent request like "What's on my calendar today?"
- **THEN** the orchestrator SHALL invoke Predicate Evaluator with predicate "isComplex"
- **AND** the evaluator SHALL return false
- **AND** the orchestrator SHALL route to the Utility Worker

#### Scenario: Complex task classification
- **WHEN** a user sends a multi-step request like "Research competitors and write a marketing brief"
- **THEN** the orchestrator SHALL invoke Predicate Evaluator with predicate "isComplex"
- **AND** the evaluator SHALL return true
- **AND** the orchestrator SHALL route to appropriate Domain Team Manager(s)

#### Scenario: Classification context
- **WHEN** invoking the Predicate Evaluator
- **THEN** the orchestrator SHALL provide context including:
  - The user request
  - Criteria for complex tasks (multi-step, creative, iterative)
  - Criteria for simple tasks (single query, direct action)

#### Scenario: Classification default
- **WHEN** the Predicate Evaluator returns false or errors
- **THEN** the orchestrator SHALL default to "simple" classification
- **AND** the orchestrator SHALL route to Utility Worker

### Requirement: Utility Worker Routing
The orchestrator SHALL route simple tasks to a Utility Worker for fast execution.

#### Scenario: Simple task dispatch
- **WHEN** a task is classified as "simple"
- **THEN** the orchestrator SHALL invoke the Utility Worker via toolWorkflow
- **AND** the orchestrator SHALL pass task_prompt, user_context, slack_context, and session_id

#### Scenario: Utility Worker response
- **WHEN** the Utility Worker returns a response
- **THEN** the orchestrator SHALL extract the result field
- **AND** the orchestrator SHALL format it for Slack delivery

### Requirement: Team Manager Routing
The orchestrator SHALL route complex tasks to appropriate Domain Team Managers.

#### Scenario: Team selection
- **WHEN** a task is classified as "complex"
- **THEN** the orchestrator SHALL analyze which domain(s) are needed
- **AND** the orchestrator SHALL invoke the appropriate Team Manager(s)

#### Scenario: Available teams
- **WHEN** the orchestrator needs to route a complex task
- **THEN** the orchestrator SHALL have access to these teams:
  - Marketing Team (content creation, briefs, blog posts)
  - Communications Team (email, messaging) [future]
  - Research Team (information gathering) [future]
  - Scheduling Team (calendar, reminders) [future]
  - Data Team (spreadsheets, analysis) [future]

#### Scenario: Team dispatch
- **WHEN** the orchestrator invokes a Team Manager
- **THEN** the orchestrator SHALL pass:
  - task_prompt: The delegated task description
  - additional_instructions: Task-specific guidance
  - user_context: User information (id, email, timezone, role)
  - slack_context: Response routing (channel_id, thread_ts)
  - team_config: Iteration limits and timeout settings

### Requirement: Cross-Team Coordination
The orchestrator SHALL coordinate handoffs when tasks require multiple teams.

#### Scenario: Multi-team task identification
- **WHEN** a task requires multiple teams
- **THEN** the orchestrator SHALL identify all teams needed
- **AND** the orchestrator SHALL determine execution strategy (parallel or sequential)

#### Scenario: Parallel team execution
- **WHEN** multiple teams are needed with no dependencies between them
- **THEN** the orchestrator SHALL invoke teams in parallel
- **AND** the orchestrator SHALL aggregate outputs when all complete

#### Scenario: Sequential team execution
- **WHEN** teams have dependencies (e.g., "Research X then write a brief")
- **THEN** the orchestrator SHALL execute teams sequentially
- **AND** the orchestrator SHALL pass prior team output to subsequent teams

#### Scenario: Execution strategy decision
- **WHEN** the orchestrator analyzes a complex multi-team request
- **THEN** the orchestrator SHALL decide parallel vs sequential based on task dependencies
- **AND** this decision SHALL be made by the AI orchestrator based on the needs of the request

#### Scenario: Handoff context preservation
- **WHEN** handing off between teams
- **THEN** the orchestrator SHALL include:
  - Original request context
  - Completed subtask summary
  - Full output from prior team
  - Relevant artifact IDs (doc IDs, etc.)

#### Scenario: Context sharing to teams
- **WHEN** delegating to a team manager
- **THEN** the orchestrator SHALL share sufficient relevant context for the team to execute
- **AND** the team manager SHALL then share relevant context with workers as needed

### Requirement: Response Aggregation
The orchestrator SHALL aggregate responses from workers and teams for user delivery.

#### Scenario: Single handler response
- **WHEN** a single Utility Worker or Team Manager responds
- **THEN** the orchestrator SHALL extract and format the result
- **AND** the orchestrator SHALL deliver via Response Router

#### Scenario: Multi-team aggregation
- **WHEN** multiple teams contribute to a response
- **THEN** the orchestrator SHALL combine outputs coherently
- **AND** the orchestrator SHALL summarize the collaborative result

#### Scenario: Error handling
- **WHEN** a worker or team returns an error
- **THEN** the orchestrator SHALL inform the user gracefully
- **AND** the orchestrator SHALL NOT automatically retry without user consent

### Requirement: Orchestrator System Prompt
The orchestrator SHALL operate with a routing-focused system prompt.

#### Scenario: Prompt content
- **WHEN** the orchestrator is initialized
- **THEN** its system prompt SHALL include:
  - Task classification guidance
  - Team capability descriptions
  - Routing decision criteria
  - Cross-team coordination rules
  - User context and personality

#### Scenario: No direct tool access
- **WHEN** the orchestrator processes a task
- **THEN** the orchestrator SHALL NOT have direct access to Gmail, Docs, etc.
- **AND** the orchestrator SHALL only access tools through workers or teams
