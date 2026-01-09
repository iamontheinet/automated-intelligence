-- Create Cortex Search Services for Postgres-synced data (Product Reviews & Support Tickets)
-- These services enable semantic search over OLTP data synced from Snowflake Postgres

USE ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;
USE DATABASE AUTOMATED_INTELLIGENCE;
USE WAREHOUSE AUTOMATED_INTELLIGENCE_WH;
USE SCHEMA SEMANTIC;

-- Cortex Search Service for Product Reviews
-- Enables natural language search over customer reviews synced from Postgres
CREATE OR REPLACE CORTEX SEARCH SERVICE product_reviews_search
    ON review_text
    ATTRIBUTES product_id, customer_id, rating, review_title, review_date
    WAREHOUSE = AUTOMATED_INTELLIGENCE_WH
    TARGET_LAG = '1 hour'
AS (
    SELECT 
        review_id,
        product_id,
        customer_id,
        review_date,
        rating,
        review_title,
        review_text
    FROM RAW.PRODUCT_REVIEWS
);

-- Cortex Search Service for Support Tickets
-- Enables natural language search over support tickets synced from Postgres
CREATE OR REPLACE CORTEX SEARCH SERVICE support_tickets_search
    ON description
    ATTRIBUTES customer_id, category, priority, subject, status, ticket_date
    WAREHOUSE = AUTOMATED_INTELLIGENCE_WH
    TARGET_LAG = '1 hour'
AS (
    SELECT 
        ticket_id,
        customer_id,
        ticket_date,
        category,
        priority,
        subject,
        description,
        resolution,
        status
    FROM RAW.SUPPORT_TICKETS
);

-- Verify creation
SHOW CORTEX SEARCH SERVICES IN SCHEMA SEMANTIC;
