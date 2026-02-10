# alfred-specialist-workers Specification

## Purpose
Defines Specialist Workers that execute focused subtasks within domain teams. Each worker has a specific skill set and limited tool access, enabling deep expertise in their area.

## ADDED Requirements

### Requirement: Specialist Worker Input Contract
All Specialist Workers SHALL accept a standardized input schema from their Team Manager.

#### Scenario: Input fields
- **WHEN** a Team Manager invokes a Specialist Worker
- **THEN** the worker SHALL accept:
  - subtask_prompt (required): The specific subtask to perform
  - context (optional): Prior worker output or relevant background
  - feedback (optional): Revision guidance from checker workers
  - iteration_count (optional): Current iteration number
  - user_context (required): Passthrough of user information

#### Scenario: First invocation vs revision
- **WHEN** iteration_count is 0 or undefined
- **THEN** the worker SHALL treat this as initial creation
- **WHEN** iteration_count > 0 and feedback is provided
- **THEN** the worker SHALL treat this as a revision request

### Requirement: Specialist Worker Output Contract
All Specialist Workers SHALL return a standardized response format.

#### Scenario: Successful execution
- **WHEN** a worker completes its subtask
- **THEN** the worker SHALL return:
  - success: true
  - output: The worker's deliverable (text, structured data, etc.)
  - output_type: Enum (ideas, draft, review, data, etc.)
  - artifacts: Array of created artifacts (doc IDs, etc.)

#### Scenario: Failed execution
- **WHEN** a worker cannot complete its subtask
- **THEN** the worker SHALL return:
  - success: false
  - error: Descriptive error message

### Requirement: Content Brainstormer Worker
The Content Brainstormer Worker SHALL generate and validate content ideas based on brand context and trends.

#### Scenario: Tool access
- **WHEN** the Content Brainstormer is initialized
- **THEN** it SHALL have access to:
  - Google Docs (read Brand Guide, read Content Strategy)
  - Google Sheets (read Content Calendar via toolWorkflow)
  - Web Search (for research and trend validation)

#### Scenario: Context fetching
- **WHEN** the Content Brainstormer receives a task
- **THEN** the worker SHALL fetch in parallel:
  - Brand Guide (Google Doc)
  - Current Content Strategy (Google Doc)
  - Content Calendar (Google Sheets)
- **AND** the worker SHALL use this context to inform ideation

#### Scenario: Idea generation and selection
- **WHEN** the Content Brainstormer has context
- **THEN** the worker SHALL:
  - Research 5 potential content ideas using Web Search
  - Evaluate each against brand fit and trending potential
  - Score ideas by: brand alignment + trend potential + uniqueness
  - Return the winning idea with rationale

#### Scenario: Output format
- **WHEN** the Content Brainstormer completes
- **THEN** the worker SHALL return:
  - winning_idea: { topic, angle, rationale, trend_score, brand_alignment_score }
  - runner_up_ideas: Array of alternatives
  - context_used: { brand_guide_summary, recent_posts, strategy_priorities }

#### Scenario: System prompt focus
- **WHEN** the Content Brainstormer is initialized
- **THEN** its system prompt SHALL emphasize:
  - Brand voice adherence
  - Trend awareness and research
  - Content calendar cohesion (avoid repetition)
  - Data-driven idea selection

### Requirement: Content Writer Worker
The Content Writer Worker SHALL create channel-specific, brand-aligned content drafts.

#### Scenario: Tool access
- **WHEN** the Content Writer is initialized
- **THEN** it SHALL have access to:
  - No required tools (pure LLM generation)
  - Optional: Google Docs (for saving drafts)

#### Scenario: Initial draft creation
- **WHEN** the Content Writer receives a winning idea and target channels
- **THEN** the worker SHALL create drafts for each channel:
  - Apply channel-specific character limits (Twitter: 280, LinkedIn: 3000, etc.)
  - Apply channel best practices (hashtags, formatting, CTAs)
  - Maintain brand voice from context

#### Scenario: Supported channels
- **WHEN** creating drafts
- **THEN** the worker SHALL support:
  - LinkedIn
  - Facebook
  - Twitter/X
  - Blog

#### Scenario: Draft revision
- **WHEN** the Content Writer receives feedback from Reviewer
- **THEN** the worker SHALL:
  - Parse reviewer feedback
  - Address each point in revised drafts
  - Maintain improvements from previous iteration
  - Track changes_made for transparency

#### Scenario: Output format
- **WHEN** the Content Writer completes
- **THEN** the worker SHALL return:
  - drafts: { [channel]: { content, character_count, hashtags } }
  - iteration: Current iteration number
  - changes_made: Array of changes (if revision)

#### Scenario: System prompt focus
- **WHEN** the Content Writer is initialized
- **THEN** its system prompt SHALL emphasize:
  - Channel-specific best practices
  - Brand voice consistency
  - Engagement optimization
  - Constructive revision handling

### Requirement: Reviewer/Editor Worker
The Reviewer/Editor Worker SHALL evaluate content against brand standards and provide binary revision decisions.

#### Scenario: Tool access
- **WHEN** the Reviewer/Editor is initialized
- **THEN** it SHALL have access to:
  - Google Docs (read Brand Guide, read Content Strategy)
  - Google Sheets (read Content Calendar)
  - Predicate Evaluator (for binary revision decision)

#### Scenario: Context fetching
- **WHEN** the Reviewer/Editor receives drafts to review
- **THEN** the worker SHALL fetch:
  - Brand Guide (Google Doc)
  - Current Content Strategy (Google Doc)
  - Content Calendar (Google Sheets) for cohesion check

#### Scenario: Evaluation criteria
- **WHEN** evaluating drafts
- **THEN** the Reviewer/Editor SHALL assess:
  - Brand Guide adherence (voice, tone, values)
  - Content Strategy alignment (messaging pillars, goals)
  - Content Calendar cohesion (not repetitive, builds on recent posts)
  - Writing quality (clarity, engagement, grammar)
  - Virality potential (hooks, emotional resonance, shareability)
  - Channel best practices (format, length, hashtags, CTAs)

#### Scenario: Binary revision decision
- **WHEN** evaluation is complete
- **THEN** the worker SHALL invoke Predicate Evaluator with:
  - predicate: "requiresMoreRevisions"
  - context: { draft, evaluation_scores, critical_issues }
- **AND** the worker SHALL return the binary result

#### Scenario: Output format
- **WHEN** the Reviewer/Editor completes
- **THEN** the worker SHALL return:
  - requires_more_revisions: Boolean (from Predicate Evaluator)
  - overall_score: Number 1-10
  - per_channel_feedback: { [channel]: { scores, issues, suggestions } }
  - critical_issues: Array of must-fix items
  - minor_suggestions: Array of nice-to-have improvements

#### Scenario: System prompt focus
- **WHEN** the Reviewer/Editor is initialized
- **THEN** its system prompt SHALL emphasize:
  - Objective evaluation against documented standards
  - Constructive, specific feedback
  - Clear distinction between critical and minor issues
  - Consistent quality threshold

### Requirement: Content Calendar Manager Worker
The Content Calendar Manager Worker SHALL track published content and save blog posts as Google Docs.

#### Scenario: Tool access
- **WHEN** the Content Calendar Manager is initialized
- **THEN** it SHALL have access to:
  - Update Google Sheet Row (Shared Utility)
  - Write Google Doc (Shared Utility)

#### Scenario: Tracker update
- **WHEN** the Content Calendar Manager receives approved content
- **THEN** the worker SHALL update the Content Tracker TABLE with:
  - Topic/Title of the content
  - Channels published to
  - Publish date
  - Status (draft/scheduled/published)
  - Link to content (Google Doc URL for blog)

#### Scenario: Blog document creation
- **WHEN** the approved content includes a blog post
- **THEN** the worker SHALL:
  - Use Write Google Doc utility to create new document
  - Apply blog formatting (headings, body, conclusion)
  - Set document title based on content topic
  - Return document ID and URL to Manager

#### Scenario: Output format
- **WHEN** the Content Calendar Manager completes
- **THEN** the worker SHALL return:
  - tracker_updated: Boolean
  - tracker_row_id: String (if updated)
  - blog_created: Boolean
  - blog_document: { id, url, title } (if blog created)
  - errors: Array of any errors encountered

#### Scenario: System prompt focus
- **WHEN** the Content Calendar Manager is initialized
- **THEN** its system prompt SHALL emphasize:
  - Accurate record-keeping
  - Consistent naming conventions
  - Proper document formatting
  - Error handling for failed operations

### Requirement: Image Generator Worker
The Image Generator Worker SHALL create AI-generated images for content using OpenAI DALL-E 3.

#### Scenario: Tool access
- **WHEN** the Image Generator is initialized
- **THEN** it SHALL have access to:
  - OpenAI Image Generation (Shared Utility)
  - Save to Google Drive (Shared Utility)

#### Scenario: Prompt generation
- **WHEN** the Image Generator receives content context
- **THEN** the worker SHALL generate a detailed image prompt based on:
  - Content topic and messaging
  - Brand visual guidelines (if provided)
  - Target channel requirements (dimensions, style)

#### Scenario: Channel-specific images
- **WHEN** generating images for multiple channels
- **THEN** the worker SHALL create appropriately sized images:
  - LinkedIn: 1200x627 pixels
  - Twitter: 1600x900 pixels
  - Facebook: 1200x630 pixels
  - Blog: 1200x800 pixels

#### Scenario: Image saving
- **WHEN** images are generated
- **THEN** the worker SHALL:
  - Save each image to specified Google Drive folder
  - Use descriptive naming: {topic}_{channel}_{date}.png
  - Return file IDs and URLs to Manager

#### Scenario: Output format
- **WHEN** the Image Generator completes
- **THEN** the worker SHALL return:
  - images_generated: Number
  - images: { [channel]: { file_id, file_url, dimensions } }
  - prompt_used: String
  - errors: Array of any errors encountered

#### Scenario: System prompt focus
- **WHEN** the Image Generator is initialized
- **THEN** its system prompt SHALL emphasize:
  - Brand-appropriate visual style
  - Channel-specific requirements
  - Clear, descriptive prompt generation
  - Proper file organization

### Requirement: Email Specialist Worker (Future)
The Email Specialist Worker SHALL compose professional email communications.

#### Scenario: Tool access
- **WHEN** the Email Specialist Worker is initialized
- **THEN** it SHALL have access to:
  - Gmail (send, reply)
  - Analyze Email Tone

#### Scenario: Email composition
- **WHEN** the worker receives an email task
- **THEN** the worker SHALL produce properly formatted email content
- **AND** the worker SHALL adapt tone to context (formal, casual, etc.)

### Requirement: Web Researcher Worker (Future)
The Web Researcher Worker SHALL gather information from the web.

#### Scenario: Tool access
- **WHEN** the Web Researcher Worker is initialized
- **THEN** it SHALL have access to:
  - Web Search

#### Scenario: Research output
- **WHEN** the worker completes research
- **THEN** the worker SHALL return:
  - Synthesized findings
  - Source citations
  - Confidence assessment

### Requirement: Specialist Worker System Prompts
All Specialist Workers SHALL have focused system prompts.

#### Scenario: Prompt structure
- **WHEN** a Specialist Worker is initialized
- **THEN** its system prompt SHALL include:
  - Clear role definition
  - Specific capabilities and limitations
  - Output format expectations
  - Quality standards for the specialty

#### Scenario: Prompt brevity
- **WHEN** defining worker system prompts
- **THEN** prompts SHALL be concise and focused
- **AND** prompts SHALL NOT include unrelated tool instructions
