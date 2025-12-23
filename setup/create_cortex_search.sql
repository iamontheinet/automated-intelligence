-- ============================================================================
-- Create Cortex Search Service for Product Discovery
-- Purpose: Enable natural language search over product catalog
-- Use Case: Find products by description, features, or characteristics
-- Example: "beginner-friendly skis", "lightweight boots", "durable snowboards"
-- ============================================================================

USE ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;
USE SCHEMA automated_intelligence.raw;

-- Create Cortex Search Service on product descriptions
CREATE OR REPLACE CORTEX SEARCH SERVICE product_search_service
ON description
ATTRIBUTES product_id, product_name, product_category, price, stock_quantity
WAREHOUSE = automated_intelligence_wh
TARGET_LAG = '1 hour'
AS (
  SELECT 
    product_id,
    product_name,
    product_category,
    price,
    stock_quantity,
    description
  FROM automated_intelligence.raw.product_catalog
);

-- Grant access to the search service
GRANT USAGE ON CORTEX SEARCH SERVICE automated_intelligence.raw.product_search_service TO ROLE snowflake_intelligence_admin;

-- Verify search service created
SHOW CORTEX SEARCH SERVICES IN SCHEMA automated_intelligence.raw;

-- Test search service (optional)
/*
SELECT * FROM TABLE(
  automated_intelligence.raw.product_search_service!SEARCH(
    query => 'beginner-friendly skis',
    limit => 10
  )
);

SELECT * FROM TABLE(
  automated_intelligence.raw.product_search_service!SEARCH(
    query => 'lightweight boots for advanced skiers',
    limit => 10
  )
);

SELECT * FROM TABLE(
  automated_intelligence.raw.product_search_service!SEARCH(
    query => 'durable snowboards under $500',
    limit => 10
  )
);
*/
