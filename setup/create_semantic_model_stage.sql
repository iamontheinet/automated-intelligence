-- ============================================================================
-- Create Stage for Semantic Model Storage
-- ============================================================================
-- This script creates a stage to store semantic model YAML files used by
-- Cortex Analyst for natural language to SQL translation.
-- ============================================================================

USE ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;
USE DATABASE automated_intelligence;
USE SCHEMA raw;

-- Create stage for semantic model files
CREATE STAGE IF NOT EXISTS semantic_models
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for storing semantic model YAML files for Cortex Analyst';

-- Verify stage creation
SHOW STAGES LIKE 'semantic_models' IN automated_intelligence.raw;

-- List files in stage (will be empty initially)
LIST @automated_intelligence.raw.semantic_models;
