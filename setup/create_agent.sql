-- ============================================================================
-- Create Cortex Agent for Natural Language Analytics
-- ============================================================================
-- This script creates a Cortex Agent with a semantic model for natural
-- language queries over business metrics and order analytics.
--
-- Prerequisites:
--   1. Semantic model stage created (create_semantic_model_stage.sql)
--   2. Semantic model YAML uploaded to stage
--   3. Cortex Search service created (create_cortex_search.sql)
-- ============================================================================

USE ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;
USE DATABASE automated_intelligence;
USE SCHEMA semantic;

-- Drop existing agent if it exists
DROP CORTEX AGENT IF EXISTS order_analytics_agent;

-- Create Cortex Agent with semantic model from stage
CREATE OR REPLACE CORTEX AGENT order_analytics_agent
    WAREHOUSE = automated_intelligence_wh
    SEMANTIC_MODEL = '@automated_intelligence.raw.semantic_models/business_insights_semantic_model.yaml'
    DESCRIPTION = 'Natural language analytics agent for order data, business metrics, and product discovery'
    COMMENT = 'Enables natural language queries over orders, customers, products, and business KPIs';

-- Grant usage to role
GRANT USAGE ON CORTEX AGENT automated_intelligence.semantic.order_analytics_agent 
    TO ROLE snowflake_intelligence_admin;

-- Verify agent creation
SHOW CORTEX AGENTS IN SCHEMA automated_intelligence.semantic;

-- Test agent (optional)
/*
-- Example queries to test the agent:

-- Query 1: Total revenue
SELECT automated_intelligence.semantic.order_analytics_agent!ASK(
    'What is the total revenue for 2024?'
) AS response;

-- Query 2: Top customers
SELECT automated_intelligence.semantic.order_analytics_agent!ASK(
    'Show me the top 10 customers by total spend'
) AS response;

-- Query 3: Product performance
SELECT automated_intelligence.semantic.order_analytics_agent!ASK(
    'Which product categories have the highest average order value?'
) AS response;

-- Query 4: Trends
SELECT automated_intelligence.semantic.order_analytics_agent!ASK(
    'Show me daily revenue trends for the past 30 days'
) AS response;
*/
