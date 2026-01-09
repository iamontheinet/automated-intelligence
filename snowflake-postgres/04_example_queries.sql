-- ============================================================================
-- Example Queries: Using Postgres External Access
-- ============================================================================
-- Run these in Snowflake (Snowsight) to query your Postgres database
-- ============================================================================

-- ============================================================================
-- Context: Database, Schema, Role
-- ============================================================================
USE ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;
USE DATABASE AUTOMATED_INTELLIGENCE;
USE WAREHOUSE AUTOMATED_INTELLIGENCE_WH;
USE SCHEMA POSTGRES;

-- ============================================================================
-- Method 1: Using CALL query_postgres() - Returns VARIANT
-- ============================================================================

-- Get row counts
CALL query_postgres('SELECT COUNT(*) as cnt FROM customers');
CALL query_postgres('SELECT COUNT(*) as cnt FROM orders');
CALL query_postgres('SELECT COUNT(*) as cnt FROM order_items');

-- Get table summary
CALL query_postgres('
    SELECT 
        ''customers'' as table_name, COUNT(*) as row_count FROM customers
    UNION ALL
    SELECT ''orders'', COUNT(*) FROM orders
    UNION ALL
    SELECT ''order_items'', COUNT(*) FROM order_items
    UNION ALL
    SELECT ''product_catalog'', COUNT(*) FROM product_catalog
');

-- ============================================================================
-- Method 2: Using TABLE(pg_query()) - Returns Table
-- ============================================================================

-- Query customers as a table
SELECT result FROM TABLE(pg_query('SELECT * FROM customers LIMIT 10'));

-- Extract specific fields from results
SELECT 
    result:customer_id::INT as customer_id,
    result:first_name::STRING as first_name,
    result:last_name::STRING as last_name,
    result:email::STRING as email,
    result:customer_segment::STRING as segment
FROM TABLE(pg_query('SELECT * FROM customers LIMIT 10'));

-- Query orders with formatting
SELECT 
    result:order_id::STRING as order_id,
    result:customer_id::INT as customer_id,
    result:order_date::TIMESTAMP as order_date,
    result:order_status::STRING as status,
    result:total_amount::FLOAT as total_amount
FROM TABLE(pg_query('SELECT * FROM orders ORDER BY order_date DESC LIMIT 10'));

-- Query products
SELECT 
    result:product_id::INT as product_id,
    result:product_name::STRING as product_name,
    result:product_category::STRING as category,
    result:price::FLOAT as price
FROM TABLE(pg_query('SELECT * FROM product_catalog'));

-- ============================================================================
-- Method 3: Complex Queries with Joins (run in Postgres)
-- ============================================================================

-- Top customers by order count
SELECT result FROM TABLE(pg_query('
    SELECT 
        c.customer_id,
        c.first_name || '' '' || c.last_name as customer_name,
        c.customer_segment,
        COUNT(o.order_id) as order_count,
        SUM(o.total_amount) as total_spent
    FROM customers c
    LEFT JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id, c.first_name, c.last_name, c.customer_segment
    ORDER BY total_spent DESC NULLS LAST
    LIMIT 10
'));

-- Orders with items summary
SELECT result FROM TABLE(pg_query('
    SELECT 
        o.order_id,
        o.order_date,
        o.order_status,
        COUNT(oi.order_item_id) as item_count,
        SUM(oi.line_total) as items_total,
        o.total_amount as order_total
    FROM orders o
    LEFT JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY o.order_id, o.order_date, o.order_status, o.total_amount
    ORDER BY o.order_date DESC
    LIMIT 10
'));

-- Product sales summary
SELECT result FROM TABLE(pg_query('
    SELECT 
        product_category,
        COUNT(DISTINCT product_id) as products,
        SUM(quantity) as units_sold,
        SUM(line_total) as revenue
    FROM order_items
    GROUP BY product_category
    ORDER BY revenue DESC
'));
