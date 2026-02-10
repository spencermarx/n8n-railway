# alfred-team-managers Specification

## Purpose
Defines Domain Team Managers that coordinate specialist workers within their domain. Each manager receives delegated tasks from the orchestrator, decomposes them into subtasks, manages feedback loops, and returns aggregated results.

## ADDED Requirements

### Requirement: Team Manager Input Contract
All Team Managers SHALL accept a standardized input schema from the orchestrator.

#### Scenario: Input fields
- **WHEN** the orchestrator invokes a Team Manager
- **THEN** the manager SHALL accept:
  - task_prompt (required): The delegated task description
  - additional_instructions (optional): Task-specific guidance from orchestrator
  - user_context (required): slack_user_id, email, name, timezone, role
  - slack_context (required): channel_id, thread_ts, response_type
  - team_config (optional): max_iterations, timeout_seconds, quality_threshold
  - handoff_context (optional): Prior team output for multi-team tasks

#### Scenario: Default team config
- **WHEN** team_config is not provided
- **THEN** the manager SHALL use team-specific defaults:
  - Marketing: max_iterations: 3
  - Communications: max_iterations: 2
  - Research: max_iterations: 2
  - timeout_seconds: 300 (all teams)

#### Scenario: User override of iteration caps
- **WHEN** the user request includes iteration intent (e.g., "iterate until perfect")
- **THEN** the orchestrator SHALL parse and pass user_iteration_override in team_config
- **AND** the manager SHALL use user_iteration_override instead of default
- Examples:
  - "iterate until perfect" → max_iterations: 10
  - "quick draft, no revisions" → max_iterations: 0
  - "give me 5 revision rounds" → max_iterations: 5

### Requirement: Team Manager Output Contract
All Team Managers SHALL return a standardized response format.

#### Scenario: Successful execution
- **WHEN** a team completes its task
- **THEN** the manager SHALL return:
  - success: true
  - result: The final output (text, document content, etc.)
  - iterations_used: Number of feedback iterations
  - workers_invoked: Array of {worker_name, invocation_count}
  - artifacts_created: Array of {type, id, url} (e.g., created docs)
  - quality_approved: Boolean indicating reviewer approval

#### Scenario: Failed or partial execution
- **WHEN** a team cannot complete its task
- **THEN** the manager SHALL return:
  - success: false
  - result: Partial output if available
  - error: Descriptive error message
  - iterations_used: Number of iterations attempted

### Requirement: Team Manager Worker Coordination
Team Managers SHALL coordinate specialist workers to accomplish delegated tasks.

#### Scenario: Worker dispatch
- **WHEN** the manager needs to invoke a specialist worker
- **THEN** the manager SHALL use toolWorkflow to call the worker
- **AND** the manager SHALL pass relevant context and subtask instructions

#### Scenario: Worker sequencing
- **WHEN** a task requires multiple workers
- **THEN** the manager SHALL determine optimal worker sequence
- **AND** the manager SHALL pass prior worker output to subsequent workers

#### Scenario: Context management
- **WHEN** the manager receives context from the orchestrator
- **THEN** the manager SHALL determine which context is relevant for each worker
- **AND** the manager SHALL share appropriate context with workers as they perform their tasks
- **AND** each team session SHALL remain isolated (no shared memory across teams)

#### Scenario: Manager as AI agent
- **WHEN** the manager workflow executes
- **THEN** an AI Agent node SHALL make intelligent decisions about:
  - Which workers to invoke
  - What order to invoke them
  - What context to share with each worker
  - When to initiate feedback loops
  - When to finalize output

### Requirement: Feedback Loop Management
Team Managers SHALL implement maker-checker feedback loops with iteration guards.

#### Scenario: Feedback loop initiation
- **WHEN** a maker worker (e.g., Writer) produces output
- **THEN** the manager SHALL send output to a checker worker (e.g., Editor)
- **AND** the manager SHALL process the checker's review

#### Scenario: Iteration continuation
- **WHEN** the checker uses Predicate Evaluator with predicate "requiresMoreRevisions"
- **AND** the evaluator returns true
- **AND** iterations < max_iterations
- **THEN** the manager SHALL return feedback to the maker worker
- **AND** the manager SHALL increment iteration count

#### Scenario: Iteration termination - quality approved
- **WHEN** the Predicate Evaluator returns false for "requiresMoreRevisions"
- **THEN** the manager SHALL finalize the output
- **AND** the manager SHALL return quality_approved=true

#### Scenario: Iteration termination - max reached
- **WHEN** iterations >= max_iterations
- **THEN** the manager SHALL finalize with current output
- **AND** the manager SHALL return quality_approved=false
- **AND** the manager SHALL note "max_iterations_reached" in response

#### Scenario: Timeout enforcement
- **WHEN** team execution exceeds timeout_seconds
- **THEN** the manager SHALL terminate gracefully
- **AND** the manager SHALL return partial output if available

### Requirement: Marketing Team Manager
The Marketing Team Manager SHALL coordinate content creation workflows for organic social channels.

#### Scenario: Marketing team workers
- **WHEN** the Marketing Manager is initialized
- **THEN** it SHALL have access to these workers:
  - Content Brainstormer: Researches and generates winning content idea
  - Content Writer: Creates channel-specific content drafts
  - Reviewer/Editor: Reviews drafts and determines revision needs
  - Content Calendar Manager: Updates Content Tracker and saves blog posts to Google Docs
  - Image Generator: Creates AI-generated images and saves to Google Drive

#### Scenario: Marketing team workflow
- **WHEN** the Marketing Manager receives a content task
- **THEN** it SHALL execute:
  1. Content Brainstormer → Fetch brand context, research 5 ideas, return winning idea
  2. Content Writer → Create drafts for specified channels (LinkedIn, Facebook, Twitter/X, Blog)
  3. Reviewer/Editor → Evaluate drafts, return binary revision decision via Predicate Evaluator
  4. (Loop) If requiresMoreRevisions=true AND iterations < max → Writer revises
  5. (Post-Approval) Image Generator → Create channel-appropriate images, save to Google Drive
  6. (Post-Approval) Content Calendar Manager → Update Content Tracker, save blog to Google Doc
  7. Return final content package (drafts, images, tracking info)

#### Scenario: Supported channels
- **WHEN** the Marketing Manager receives a content task
- **THEN** it SHALL support these target channels:
  - LinkedIn
  - Facebook
  - Twitter/X
  - Blog

#### Scenario: Marketing manager output
- **WHEN** the Marketing Manager completes a content task
- **THEN** it SHALL return:
  - drafts: Per-channel content
  - images: Per-channel image URLs and file IDs
  - content_tracked: Tracker row ID and blog document URL (if applicable)
  - iterations_used: Number of revision iterations
  - quality_approved: Boolean from Reviewer

#### Scenario: Marketing manager system prompt
- **WHEN** the Marketing Manager is initialized
- **THEN** its system prompt SHALL define:
  - Team purpose (organic social content creation)
  - Worker capabilities and sequencing (including post-approval pipeline)
  - Channel-specific requirements
  - Iteration cap handling (default 3, user-overrideable)

### Requirement: Team Execution Logging
Team Managers SHALL log execution details for observability.

#### Scenario: Execution logging
- **WHEN** a team starts and completes execution
- **THEN** the manager SHALL log to alfred.team_execution_logs:
  - execution_id
  - team_name
  - task_summary
  - started_at, completed_at
  - total_iterations
  - workers_invoked (JSONB)
  - final_status
  - error_message (if failed)
