-- ================================================================
-- AI OBSERVABILITY - PRIVILEGE SETUP
-- ================================================================
-- Run this script as ACCOUNTADMIN to grant required privileges
-- for AI Observability evaluation framework
-- ================================================================

USE ROLE ACCOUNTADMIN;

-- Grant Cortex User database role for LLM access
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER 
    TO ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;

-- Grant AI Observability application role for event table access
GRANT APPLICATION ROLE SNOWFLAKE.AI_OBSERVABILITY_EVENTS_LOOKUP 
    TO ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;

-- Grant privilege to create EXTERNAL AGENT objects
GRANT CREATE EXTERNAL AGENT ON SCHEMA AUTOMATED_INTELLIGENCE.RAW 
    TO ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;

-- Grant task privileges for evaluation runs
GRANT CREATE TASK ON SCHEMA AUTOMATED_INTELLIGENCE.RAW 
    TO ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;

GRANT EXECUTE TASK ON ACCOUNT 
    TO ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;

-- Grant usage on warehouse for evaluation
GRANT USAGE ON WAREHOUSE AUTOMATED_INTELLIGENCE_WH 
    TO ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;

-- Grant access to dynamic tables for context retrieval
GRANT SELECT ON ALL TABLES IN SCHEMA AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES 
    TO ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;

-- Grant future privileges for new tables
GRANT SELECT ON FUTURE TABLES IN SCHEMA AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES 
    TO ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;

SELECT 'AI Observability privileges granted successfully!' as STATUS;

-- ================================================================
-- VERIFICATION QUERIES
-- ================================================================

-- Check granted roles
SHOW GRANTS TO ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;

-- Verify CORTEX_USER role
SELECT 'CORTEX_USER role granted' as CHECK_RESULT
WHERE EXISTS (
    SELECT 1 FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
    WHERE "granted_to" = 'ROLE' 
    AND "grantee_name" = 'SNOWFLAKE_INTELLIGENCE_ADMIN'
    AND "name" = 'CORTEX_USER'
);

-- View AI Observability event table structure
DESC TABLE SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS;
