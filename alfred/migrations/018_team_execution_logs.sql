-- Alfred Migration 018: Team Execution Logs Table
-- Creates team_execution_logs table for team execution observability
-- Safe to run multiple times (idempotent)

-- ============================================================================
-- TEAM_EXECUTION_LOGS TABLE
-- ============================================================================
-- Tracks all team manager invocations for debugging and analytics.
-- This table is the primary observability mechanism for the multi-agent
-- architecture, recording execution details, worker invocations, and outcomes.
--
-- WORKERS_INVOKED STRUCTURE:
-- [
--   {"worker": "writer", "invocations": 2},
--   {"worker": "researcher", "invocations": 1},
--   {"worker": "reviewer", "invocations": 3}
-- ]
--
-- FINAL_STATUS VALUES:
-- - 'completed': Task finished successfully
-- - 'max_iterations': Hit iteration limit without completion
-- - 'error': Execution failed with an error
-- - 'timeout': Execution timed out
-- ============================================================================

BEGIN;

-- Create the team_execution_logs table if it doesn't exist
CREATE TABLE IF NOT EXISTS alfred.team_execution_logs (
    -- Primary key
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Execution identification
    execution_id VARCHAR(255) NOT NULL,
    team_name VARCHAR(100) NOT NULL,
    manager_workflow_id VARCHAR(100),

    -- Task context
    task_summary TEXT,

    -- Timing
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,

    -- Iteration tracking
    total_iterations INTEGER DEFAULT 0,
    max_iterations_reached BOOLEAN DEFAULT FALSE,

    -- Worker invocation details
    workers_invoked JSONB,

    -- Outcome
    final_status VARCHAR(50),
    error_message TEXT,

    -- Audit timestamp
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for common queries
CREATE INDEX IF NOT EXISTS idx_team_logs_execution
    ON alfred.team_execution_logs(execution_id);

CREATE INDEX IF NOT EXISTS idx_team_logs_team
    ON alfred.team_execution_logs(team_name);

CREATE INDEX IF NOT EXISTS idx_team_logs_status
    ON alfred.team_execution_logs(final_status);

CREATE INDEX IF NOT EXISTS idx_team_logs_started
    ON alfred.team_execution_logs(started_at DESC);

-- Composite index for team-based time range queries
CREATE INDEX IF NOT EXISTS idx_team_logs_team_started
    ON alfred.team_execution_logs(team_name, started_at DESC);

-- Add table comment
COMMENT ON TABLE alfred.team_execution_logs IS
'Tracks team manager executions for observability and debugging in the multi-agent architecture.
Used to monitor team performance, debug failures, and analyze worker utilization patterns.

Query examples:
  - Recent failures: SELECT * FROM alfred.team_execution_logs WHERE final_status = ''error'' ORDER BY started_at DESC LIMIT 10;
  - Team performance: SELECT team_name, AVG(total_iterations), COUNT(*) FROM alfred.team_execution_logs GROUP BY team_name;
  - Max iterations analysis: SELECT * FROM alfred.team_execution_logs WHERE max_iterations_reached = TRUE;
';

-- Add column comments
COMMENT ON COLUMN alfred.team_execution_logs.execution_id IS 'Unique identifier for the n8n execution';
COMMENT ON COLUMN alfred.team_execution_logs.team_name IS 'Name of the team (e.g., marketing, research, support)';
COMMENT ON COLUMN alfred.team_execution_logs.manager_workflow_id IS 'n8n workflow ID of the team manager';
COMMENT ON COLUMN alfred.team_execution_logs.task_summary IS 'Human-readable summary of the task being executed';
COMMENT ON COLUMN alfred.team_execution_logs.started_at IS 'Timestamp when team execution began';
COMMENT ON COLUMN alfred.team_execution_logs.completed_at IS 'Timestamp when team execution finished (null if still running)';
COMMENT ON COLUMN alfred.team_execution_logs.total_iterations IS 'Number of iteration cycles completed by the team manager';
COMMENT ON COLUMN alfred.team_execution_logs.max_iterations_reached IS 'TRUE if execution stopped due to hitting the iteration limit';
COMMENT ON COLUMN alfred.team_execution_logs.workers_invoked IS 'JSON array of worker invocation counts: [{worker: "name", invocations: N}, ...]';
COMMENT ON COLUMN alfred.team_execution_logs.final_status IS 'Execution outcome: completed, max_iterations, error, timeout';
COMMENT ON COLUMN alfred.team_execution_logs.error_message IS 'Error details if final_status is error';

COMMIT;

-- Verify table structure
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'alfred'
  AND table_name = 'team_execution_logs'
ORDER BY ordinal_position;

-- Show indexes
SELECT
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'alfred'
  AND tablename = 'team_execution_logs';
