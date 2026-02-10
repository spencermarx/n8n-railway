# alfred-shared-utilities Specification

## Purpose
Defines reusable utility workflows that multiple Specialist Workers can invoke. These utilities encapsulate common operations (Google Doc access, Sheets updates, image generation, file storage) to avoid code duplication and ensure consistent behavior across teams.

## ADDED Requirements

### Requirement: Shared Utility Design Principles
All Shared Utilities SHALL follow consistent design patterns.

#### Scenario: Input consistency
- **WHEN** a Shared Utility is invoked
- **THEN** it SHALL accept a standardized input schema including:
  - Required operation-specific parameters
  - slack_user_id for credential resolution
  - Optional parameters with sensible defaults

#### Scenario: Output consistency
- **WHEN** a Shared Utility completes
- **THEN** it SHALL return:
  - success: Boolean indicating operation success
  - Operation-specific result fields
  - error: String describing failure (if success=false)

#### Scenario: Error handling
- **WHEN** an error occurs during utility execution
- **THEN** the utility SHALL NOT throw unhandled exceptions
- **AND** the utility SHALL return success=false with descriptive error

### Requirement: DB Manager Utility
The DB Manager utility SHALL serve as the public interface for database operations.

#### Scenario: Configuration retrieval
- **WHEN** the utility is invoked with action "get_config"
- **THEN** it SHALL accept:
  - config_key (required): The configuration key to retrieve
- **AND** it SHALL return the value from `alfred.system_config`

#### Scenario: Configuration update
- **WHEN** the utility is invoked with action "set_config"
- **THEN** it SHALL accept:
  - config_key (required): The configuration key to update
  - config_value (required): The new value
- **AND** it SHALL update the value in `alfred.system_config`

#### Scenario: Execution logging
- **WHEN** the utility is invoked with action "log_execution"
- **THEN** it SHALL accept:
  - log_data (required): Object containing execution details
- **AND** it SHALL insert a record into `alfred.team_execution_logs`

#### Scenario: Pre-configured marketing keys
- **WHEN** the system is initialized
- **THEN** the following config keys SHALL be seeded:
  - `marketing.brand_guide_doc_id`: Wrkbelt Brand Guide Google Doc ID
  - `marketing.content_calendar_sheet_id`: Wrkbelt Content Calendar Google Sheet ID
  - `marketing.content_strategy_doc_id`: Content Strategy Google Doc ID
  - `marketing.image_storage_folder_id`: Google Drive folder for images

#### Scenario: Output format
- **WHEN** the utility completes successfully
- **THEN** it SHALL return:
  - success: true
  - value: The retrieved or updated value (for config operations)
  - error: null

### Requirement: Fetch Google Doc Utility
The Fetch Google Doc utility SHALL retrieve content from a Google Document.

#### Scenario: Input parameters
- **WHEN** the utility is invoked
- **THEN** it SHALL accept:
  - document_id (optional): The Google Doc ID
  - config_key (optional): A system_config key to resolve document_id from
  - document_name (optional): The document name for lookup
  - slack_user_id (required): For credential resolution

#### Scenario: Document resolution
- **WHEN** document_id is provided
- **THEN** the utility SHALL fetch directly by ID
- **WHEN** config_key is provided (e.g., "marketing.brand_guide_doc_id")
- **THEN** the utility SHALL use DB Manager to resolve the document_id
- **WHEN** only document_name is provided
- **THEN** the utility SHALL search for the document by name

#### Scenario: Output format
- **WHEN** the utility completes successfully
- **THEN** it SHALL return:
  - success: true
  - content: The full document text content
  - document_id: The resolved document ID
  - document_title: The document title

### Requirement: Write Google Doc Utility
The Write Google Doc utility SHALL create a new Google Document with specified content.

#### Scenario: Input parameters
- **WHEN** the utility is invoked
- **THEN** it SHALL accept:
  - title (required): The document title
  - content (required): The document body content
  - folder_id (optional): Target Google Drive folder ID
  - slack_user_id (required): For credential resolution

#### Scenario: Document creation
- **WHEN** the utility is invoked with valid parameters
- **THEN** it SHALL create a new Google Document
- **AND** it SHALL apply the title and content

#### Scenario: Output format
- **WHEN** the utility completes successfully
- **THEN** it SHALL return:
  - success: true
  - document_id: The created document ID
  - document_url: The shareable document URL

### Requirement: Update Google Sheet Row Utility
The Update Google Sheet Row utility SHALL add or update rows in a Google Sheet.

#### Scenario: Input parameters
- **WHEN** the utility is invoked
- **THEN** it SHALL accept:
  - spreadsheet_id (required): The Google Sheet ID
  - sheet_name (required): The specific tab/sheet name
  - row_data (required): Object mapping column names to values
  - action (required): "append" or "update"
  - row_id (conditional): Required when action is "update"
  - slack_user_id (required): For credential resolution

#### Scenario: Append operation
- **WHEN** action is "append"
- **THEN** the utility SHALL add a new row at the end of the sheet
- **AND** the utility SHALL map row_data columns to sheet columns

#### Scenario: Update operation
- **WHEN** action is "update"
- **THEN** the utility SHALL locate the row by row_id
- **AND** the utility SHALL update the specified columns

#### Scenario: Output format
- **WHEN** the utility completes successfully
- **THEN** it SHALL return:
  - success: true
  - row_id: The row identifier (new or updated)
  - action_taken: "appended" or "updated"

### Requirement: OpenAI Image Generation Utility
The OpenAI Image Generation utility SHALL generate images using DALL-E 3.

#### Scenario: Input parameters
- **WHEN** the utility is invoked
- **THEN** it SHALL accept:
  - prompt (required): The image generation prompt
  - size (optional): "1024x1024" | "1792x1024" | "1024x1792" (default: "1024x1024")
  - quality (optional): "standard" | "hd" (default: "standard")
  - style (optional): "vivid" | "natural" (default: "vivid")
  - n (optional): Number of images 1-10 (default: 1)

#### Scenario: Image generation
- **WHEN** the utility is invoked with valid prompt
- **THEN** it SHALL call OpenAI DALL-E 3 API
- **AND** it SHALL return temporary image URLs

#### Scenario: Output format
- **WHEN** the utility completes successfully
- **THEN** it SHALL return:
  - success: true
  - images: Array of { url, revised_prompt }

#### Scenario: Rate limiting
- **WHEN** OpenAI rate limits are encountered
- **THEN** the utility SHALL return success=false with rate_limited error

### Requirement: Save to Google Drive Utility
The Save to Google Drive utility SHALL save files from URLs or base64 content to Google Drive.

#### Scenario: Input parameters
- **WHEN** the utility is invoked
- **THEN** it SHALL accept:
  - source_url (optional): URL to download file from
  - source_base64 (optional): Base64-encoded file content
  - file_name (required): Target file name
  - mime_type (required): MIME type (e.g., "image/png")
  - folder_id (optional): Target Google Drive folder ID
  - slack_user_id (required): For credential resolution

#### Scenario: URL source
- **WHEN** source_url is provided
- **THEN** the utility SHALL download the file from the URL
- **AND** the utility SHALL upload to Google Drive

#### Scenario: Base64 source
- **WHEN** source_base64 is provided
- **THEN** the utility SHALL decode the base64 content
- **AND** the utility SHALL upload to Google Drive

#### Scenario: Output format
- **WHEN** the utility completes successfully
- **THEN** it SHALL return:
  - success: true
  - file_id: The Google Drive file ID
  - file_url: The shareable Google Drive URL

### Requirement: Credential Resolution
All utilities requiring Google services SHALL resolve credentials via slack_user_id.

#### Scenario: Credential passthrough
- **WHEN** a utility is invoked with slack_user_id
- **THEN** the utility SHALL resolve the user's Google credentials
- **AND** the utility SHALL execute operations with those credentials

#### Scenario: Missing credentials
- **WHEN** credentials cannot be resolved for the slack_user_id
- **THEN** the utility SHALL return success=false
- **AND** the utility SHALL include "credentials_not_found" in error message
