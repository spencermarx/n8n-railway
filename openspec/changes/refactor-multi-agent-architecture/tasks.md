# Tasks: Hierarchical Multi-Agent Team Architecture

## Phase 1: Foundation - Task Classification & Utility Worker

### 1.1 Task Classification System (via Predicate Evaluator)
- [x] 1.1.1 Add Predicate Evaluator invocation to orchestrator
  - Invoke `Rw7786cYTYOTQhH9` with predicate "isComplex"
  - Pass complexity criteria context (multi-step, creative, iterative indicators)
  - Default to simple (false) on evaluator error
- [x] 1.1.2 Create routing logic after classification
  - Simple (false) → Utility Worker
  - Complex (true) → Team Manager selection
- [x] 1.1.3 Add iteration override parsing
  - Detect phrases: "iterate until perfect", "no revisions", "X revision rounds"
  - Pass user_iteration_override in team_config

### 1.2 Utility Worker
- [x] 1.2.1 Create `alfred/workflows/workers/utility_worker.json`
  - Execute Workflow Trigger with standard input schema
  - AI Agent node with general-purpose system prompt
  - Connect ALL existing tools (Gmail, Calendar, Docs, Sheets, etc.)
- [x] 1.2.2 Define Utility Worker input/output contracts
  - Input: task_prompt, user_context, slack_context, session_id
  - Output: success, result, actions_taken, requires_approval
- [x] 1.2.3 Wire Utility Worker as toolWorkflow in orchestrator
- [ ] 1.2.4 Test simple task routing end-to-end

## Phase 1.5: Shared Utility Flows

### 1.5.0 DB Manager Utility (Foundation)
- [x] 1.5.0.1 Create migration: `017_system_config.sql`
  - Create `alfred.system_config` table (config_key, config_value JSONB, description)
  - Seed initial marketing configuration:
    - `marketing.brand_guide_doc_id` = `14_iOMjdagXCd9vX_wviQm4ruaMxRQOblUj9VL_2tZYY`
    - `marketing.content_calendar_sheet_id` = `1Txc5v1Eeitm5-xvHleKvtEbH-KhxUk3hyxrBcr89rI0`
    - `marketing.content_strategy_doc_id` = TBD
    - `marketing.image_storage_folder_id` = TBD
- [x] 1.5.0.2 Create `alfred/workflows/utilities/db_manager.json`
  - Execute Workflow Trigger with action-based input
  - Support actions: get_config, set_config, log_execution
  - Connect to Postgres via existing credential
  - Output: { success, value, error }
- [ ] 1.5.0.3 Test DB Manager get_config for marketing keys

### 1.5.1 Google Doc Utilities
- [x] 1.5.1.1 Create `alfred/workflows/utilities/fetch_google_doc.json`
  - Input: document_id or document_name, slack_user_id
  - Use DB Manager to resolve document_id from config key if needed
  - Output: { success, content, document_id, document_title, error }
  - Used by: Brainstormer, Reviewer/Editor
- [x] 1.5.1.2 Create `alfred/workflows/utilities/write_google_doc.json`
  - Input: title, content, folder_id (optional), slack_user_id
  - Output: { success, document_id, document_url, error }
  - Used by: Content Calendar Manager

### 1.5.2 Google Sheets Utilities
- [x] 1.5.2.1 Create `alfred/workflows/utilities/update_sheet_row.json`
  - Input: spreadsheet_id (or config_key), sheet_name, row_data, action (append|update), slack_user_id
  - Use DB Manager to resolve spreadsheet_id from config key if needed
  - Output: { success, row_id, action_taken, error }
  - Used by: Content Calendar Manager

### 1.5.3 Google Drive Utilities
- [x] 1.5.3.1 Create `alfred/workflows/utilities/save_to_google_drive.json`
  - Input: source_url or source_base64, file_name, mime_type, folder_id (or config_key), slack_user_id
  - Use DB Manager to resolve folder_id from config key if needed
  - Output: { success, file_id, file_url, error }
  - Used by: Image Generator

### 1.5.4 OpenAI Utilities
- [x] 1.5.4.1 Create `alfred/workflows/utilities/openai_image_generation.json`
  - Input: prompt, size, quality (standard|hd), style (vivid|natural)
  - Output: { success, images: [{ url, revised_prompt }], error }
  - Used by: Image Generator

### 1.5.5 Configuration (via DB Manager)
- [ ] 1.5.5.1 Identify Content Strategy Google Doc ID
  - Update `marketing.content_strategy_doc_id` in system_config via DB Manager
- [ ] 1.5.5.2 Identify Image Storage Google Drive Folder ID
  - Update `marketing.image_storage_folder_id` in system_config via DB Manager

## Phase 2: Marketing Team - First Domain Team

### 2.1 Marketing Team Manager
- [x] 2.1.1 Create `alfred/workflows/teams/marketing/manager.json`
  - Execute Workflow Trigger with team input schema
  - AI Agent (Manager) with team coordination system prompt
  - Worker dispatch tools (5 workers):
    - Content Brainstormer
    - Content Writer
    - Reviewer/Editor
    - Content Calendar Manager
    - Image Generator
  - Iteration tracking state with user override support
- [x] 2.1.2 Define Manager input contract
  - task_prompt, target_channels (LinkedIn, Facebook, Twitter/X, Blog)
  - user_context, slack_context
  - team_config (max_iterations default 3, user_iteration_override)
- [x] 2.1.3 Define Manager output contract
  - success, drafts (per channel), iterations_used, quality_approved
  - images: { [channel]: { file_id, file_url } }
  - content_tracked: { tracker_row_id, blog_document_url }
  - artifacts_created: array of { type, id, url }

### 2.2 Content Brainstormer Worker
- [x] 2.2.1 Create `alfred/workflows/teams/marketing/workers/content_brainstormer.json`
  - Execute Workflow Trigger
  - AI Agent with brand-aware ideation system prompt
- [x] 2.2.2 Implement parallel context fetching
  - Fetch Brand Guide (Google Doc via fetch_google_doc sub-flow)
  - Fetch Content Strategy (Google Doc via fetch_google_doc sub-flow)
  - Fetch Content Calendar (Google Sheets via existing sheets tool)
- [x] 2.2.3 Implement idea research and ranking
  - Generate 5 content ideas using Web Search
  - Score by trend potential + brand alignment
  - Return winning idea with rationale
- [x] 2.2.4 Define output format
  - winning_idea: { topic, angle, rationale, scores }
  - context_used: { brand_summary, recent_posts, strategy_priorities }

### 2.3 Content Writer Worker
- [x] 2.3.1 Create `alfred/workflows/teams/marketing/workers/content_writer.json`
  - Execute Workflow Trigger (accepts winning_idea, target_channels, optional feedback)
  - AI Agent with channel-aware writing system prompt
- [x] 2.3.2 Implement channel-specific draft generation
  - LinkedIn: Up to 3000 chars, professional tone, hashtags
  - Facebook: Casual tone, engagement-focused
  - Twitter/X: 280 chars max, hooks, threads if needed
  - Blog: Long-form, SEO-aware
- [x] 2.3.3 Implement revision handling
  - Accept feedback from Reviewer
  - Track changes_made for transparency
- [x] 2.3.4 Define output format
  - drafts: { [channel]: { content, character_count, hashtags } }
  - iteration, changes_made

### 2.4 Reviewer/Editor Worker
- [x] 2.4.1 Create `alfred/workflows/teams/marketing/workers/reviewer_editor.json`
  - Execute Workflow Trigger (accepts drafts)
  - AI Agent with evaluation system prompt
- [x] 2.4.2 Implement context fetching (same as Brainstormer)
  - Brand Guide, Content Strategy, Content Calendar
- [x] 2.4.3 Implement multi-criteria evaluation
  - Brand alignment, strategy fit, calendar cohesion
  - Writing quality, virality potential, channel best practices
- [x] 2.4.4 Implement binary revision decision via Predicate Evaluator
  - Invoke `Rw7786cYTYOTQhH9` with predicate "requiresMoreRevisions"
  - Pass evaluation context (scores, critical issues)
- [x] 2.4.5 Define output format
  - requires_more_revisions: boolean
  - overall_score, per_channel_feedback, critical_issues, minor_suggestions

### 2.5 Content Calendar Manager Worker
- [x] 2.5.1 Create `alfred/workflows/teams/marketing/workers/calendar_manager.json`
  - Execute Workflow Trigger (accepts final_drafts, content_metadata, action)
  - AI Agent with record-keeping system prompt
- [x] 2.5.2 Implement Content Tracker update
  - Wire update_sheet_row utility for Content Calendar Google Sheet
  - Add row with: topic, channels, publish_date, status, content_link
- [x] 2.5.3 Implement blog document creation
  - Wire write_google_doc utility
  - Apply blog formatting (headings, body, conclusion)
  - Return document ID and URL
- [x] 2.5.4 Define output format
  - tracker_updated: boolean, tracker_row_id
  - blog_created: boolean, blog_document: { id, url, title }
  - errors: array

### 2.6 Image Generator Worker
- [x] 2.6.1 Create `alfred/workflows/teams/marketing/workers/image_generator.json`
  - Execute Workflow Trigger (accepts content_context, image_requirements, target_channels)
  - AI Agent with visual content generation system prompt
- [x] 2.6.2 Implement prompt generation
  - Analyze content context and brand guidelines
  - Generate detailed DALL-E 3 prompt
- [x] 2.6.3 Implement channel-specific image generation
  - LinkedIn: 1200x627, Twitter: 1600x900, Facebook: 1200x630, Blog: 1200x800
  - Wire openai_image_generation utility
- [x] 2.6.4 Implement Google Drive saving
  - Wire save_to_google_drive utility
  - Use descriptive naming: {topic}_{channel}_{date}.png
- [x] 2.6.5 Define output format
  - images_generated: number
  - images: { [channel]: { file_id, file_url, dimensions } }
  - prompt_used, errors

### 2.7 Feedback Loop Infrastructure
- [x] 2.7.1 Create iteration guard logic in Manager workflow
  - Track iteration_count per task
  - Check user_iteration_override first, then team default (3)
  - Enforce hard cap at 10 iterations
- [x] 2.7.2 Implement Writer ↔ Reviewer feedback loop
  - If requires_more_revisions=true && iterations < max → Writer revises
  - If requires_more_revisions=false || iterations >= max → finalize
- [x] 2.7.3 Add post-approval pipeline
  - After content approved, invoke Image Generator
  - Then invoke Content Calendar Manager
  - Aggregate all outputs for Manager response
- [x] 2.7.4 Add timeout guard (default: 300 seconds)

## Phase 3: Orchestrator Integration

### 3.1 Update Orchestrator
- [x] 3.1.1 Refactor orchestrator system prompt
  - Focus on task analysis, classification, routing
  - Remove direct tool instructions
  - Add team descriptions and routing guidance
- [x] 3.1.2 Add Marketing Team Manager as toolWorkflow
  - Description: "Handles content creation, marketing briefs, blog posts"
  - Input mapping: task_prompt, user_context, etc.
- [x] 3.1.3 Update response aggregation
  - Parse team output (success, result, iterations)
  - Format for Slack display
  - Handle requires_approval from teams

### 3.2 Team Execution Logging
- [x] 3.2.1 Create migration: `018_team_execution_logs.sql`
  - team_execution_logs table
  - Indexes for execution_id, team_name
- [ ] 3.2.2 Add logging calls in team workflows
  - Log on team start
  - Log on team completion (with iterations, status)
  - Log on team error

### 3.3 Testing
- [ ] 3.3.1 Test task classification accuracy
  - Sample set of simple requests
  - Sample set of complex requests
  - Measure classification accuracy
- [ ] 3.3.2 Test Marketing Team end-to-end
  - "Write a blog post about X"
  - "Create a marketing brief for Y"
  - Validate feedback loop iterations
- [ ] 3.3.3 Test edge cases
  - Max iterations reached
  - Timeout scenarios
  - Team errors

## Phase 4: Shared Tool Layer Refactoring

### 4.1 Tool Standardization
- [ ] 4.1.1 Ensure all tools have consistent input schema
  - slack_user_id for credential resolution
  - action for operation selection
  - Standardized parameter names
- [ ] 4.1.2 Document tool availability matrix
  - Which tools are available to which agents
  - Tool capability descriptions for agent prompts

### 4.2 Tool Access from Teams
- [ ] 4.2.1 Wire tools to Marketing Team workers
  - Web Search → Brainstorm Worker
  - Google Docs → Writer Worker
- [ ] 4.2.2 Verify tool credential passthrough
  - User context flows from orchestrator → team → worker → tool

## Phase 5: Additional Teams

### 5.1 Communications Team (Future)
- [ ] 5.1.1 Create Communications Manager workflow
- [ ] 5.1.2 Create Email Specialist worker
- [ ] 5.1.3 Create Messaging Specialist worker
- [ ] 5.1.4 Create Tone Analyst worker
- [ ] 5.1.5 Wire team to orchestrator

### 5.2 Research Team (Future)
- [ ] 5.2.1 Create Research Manager workflow
- [ ] 5.2.2 Create Web Researcher worker
- [ ] 5.2.3 Create Summarizer worker
- [ ] 5.2.4 Create Fact Checker worker
- [ ] 5.2.5 Wire team to orchestrator

### 5.3 Cross-Team Collaboration (Future)
- [ ] 5.3.1 Implement handoff protocol in orchestrator
- [ ] 5.3.2 Test Research → Marketing handoff
- [ ] 5.3.3 Test multi-team sequential execution

## Phase 6: Documentation & Rollout

### 6.1 Documentation
- [ ] 6.1.1 Update project.md with new architecture
  - Three-tier hierarchy explanation
  - Workflow directory structure
  - Team naming conventions
- [ ] 6.1.2 Create team development guide
  - How to create a new team
  - How to add workers to a team
  - Feedback loop implementation guide
- [ ] 6.1.3 Update workflow IDs in project.md

### 6.2 Deployment
- [x] 6.2.1 Deploy Utility Worker (inactive)
  - Deployed as `yXnjcopPZfdrzMzs` (Worker | Utility Worker)
- [x] 6.2.2 Deploy Marketing Team workflows (inactive)
  - Marketing Manager: `WUNHfC0c2FRgIlye`
  - Content Brainstormer: `G0qNvT8YxYwH8XqV`
  - Content Writer: `U5C3B4S9SIyXNGtH`
  - Reviewer/Editor: `vZmSJnGeCeegKi8X`
  - Image Generator: `Z4pTCAwWwz153K3C`
  - Content Calendar Manager: `ezvCaPeNM8P7gEWj`
- [x] 6.2.3 Deploy updated orchestrator
  - Updated `KJpZBr3isT66Rzoa` with Utility Worker and Marketing Manager IDs
- [x] 6.2.4 Run database migration
  - 017_system_config.sql: Created system_config table with marketing configuration
  - 018_team_execution_logs.sql: Created team_execution_logs table with indexes
- [x] 6.2.5 Activate all workflows in sequence
  - All utility workflows activated
  - All marketing workers activated
  - Utility Worker activated
  - Marketing Manager activated
- [ ] 6.2.6 Monitor for 48 hours
