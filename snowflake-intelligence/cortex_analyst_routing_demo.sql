-- ============================================================================
-- Cortex Analyst - Routing Mode Demo
-- ============================================================================
-- Routing mode enables Cortex Analyst to intelligently route questions
-- to the most appropriate semantic model when multiple models exist.
-- 
-- Available since December 2025.
-- ============================================================================

USE ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;
USE DATABASE AUTOMATED_INTELLIGENCE;
USE WAREHOUSE AUTOMATED_INTELLIGENCE_WH;

-- ============================================================================
-- PART 1: Understanding Routing Mode
-- ============================================================================

/*
ROUTING MODE OVERVIEW:

When multiple semantic models exist, users may not know which one to query.
Routing mode solves this by:

1. Analyzing the user's natural language question
2. Determining which semantic model is most relevant
3. Automatically routing to the correct model
4. Returning results from the appropriate source

USE CASES:
- Enterprise deployments with many semantic models
- Self-service analytics portals
- Chatbot integrations serving diverse user groups
*/

-- ============================================================================
-- PART 2: View Available Semantic Models
-- ============================================================================

-- List all semantic views in the account
SHOW SEMANTIC VIEWS IN DATABASE AUTOMATED_INTELLIGENCE;

-- Our models:
-- 1. BUSINESS_INSIGHTS_SEMANTIC_MODEL - Orders, customers, products
-- 2. ORDERS_ANALYTICS_SV - Focused order analytics

-- ============================================================================
-- PART 3: Configure Routing (Preview Feature)
-- ============================================================================

/*
-- Create a routing configuration
-- Note: Syntax may vary - check current documentation

CREATE OR REPLACE CORTEX ANALYST ROUTER my_analytics_router
WITH SEMANTIC_VIEWS = (
    'AUTOMATED_INTELLIGENCE.SEMANTIC.BUSINESS_INSIGHTS_SEMANTIC_MODEL',
    'AUTOMATED_INTELLIGENCE.SEMANTIC.ORDERS_ANALYTICS_SV'
)
DESCRIPTION = 'Routes questions to appropriate analytics model';

-- The router analyzes questions like:
-- "What is total revenue?" → Routes to BUSINESS_INSIGHTS_SEMANTIC_MODEL
-- "Show order counts by month" → Routes to ORDERS_ANALYTICS_SV
*/

-- ============================================================================
-- PART 4: Using Routing in Applications
-- ============================================================================

/*
-- Python example using routing mode

from snowflake.cortex import Analyst

# Create analyst with routing
analyst = Analyst(
    session=session,
    routing_mode=True,
    semantic_views=[
        'AUTOMATED_INTELLIGENCE.SEMANTIC.BUSINESS_INSIGHTS_SEMANTIC_MODEL',
        'AUTOMATED_INTELLIGENCE.SEMANTIC.ORDERS_ANALYTICS_SV'
    ]
)

# Ask question - routing happens automatically
response = analyst.ask("What is total revenue by customer segment?")

# Response includes:
# - Selected semantic model
# - Generated SQL
# - Results
# - Confidence score for routing decision
*/

-- ============================================================================
-- PART 5: Streamlit Integration with Routing
-- ============================================================================

/*
# Example Streamlit app with routing

import streamlit as st
from snowflake.cortex import Analyst

st.title("Analytics Assistant")

question = st.text_input("Ask a question about your business:")

if question:
    # Routing mode automatically selects the right model
    analyst = Analyst(session, routing_mode=True)
    response = analyst.ask(question)
    
    st.subheader("Answer")
    st.write(response.answer)
    
    st.subheader("Source Model")
    st.info(f"Routed to: {response.semantic_model}")
    
    st.subheader("Generated SQL")
    st.code(response.sql, language="sql")
*/

-- ============================================================================
-- PART 6: Best Practices for Multi-Model Routing
-- ============================================================================

/*
1. MODEL DESIGN:
   - Create focused, domain-specific semantic models
   - Use clear, descriptive model comments
   - Include comprehensive synonyms for routing accuracy

2. NAMING CONVENTIONS:
   - Use descriptive model names (e.g., sales_analytics, hr_metrics)
   - Add domain keywords in comments for routing hints

3. TESTING ROUTING:
   - Test with diverse question types
   - Verify routing accuracy before production
   - Monitor routing decisions in logs

4. FALLBACK HANDLING:
   - Configure default model for ambiguous questions
   - Provide user feedback when routing confidence is low
*/

-- ============================================================================
-- Demo Complete
-- ============================================================================
SELECT '✅ Cortex Analyst Routing Mode Demo Complete!' AS status;
