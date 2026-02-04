-- Alfred Migration 001: Create Schema
-- Creates the isolated alfred schema separate from n8n's public schema
-- Safe to run multiple times (idempotent)

-- Create isolated schema for Alfred
CREATE SCHEMA IF NOT EXISTS alfred;

-- Verify schema exists
SELECT schema_name
FROM information_schema.schemata
WHERE schema_name = 'alfred';
