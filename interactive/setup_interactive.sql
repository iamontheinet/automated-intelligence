-- ============================================================================
-- ONE-COMMAND INTERACTIVE SETUP
-- ============================================================================
-- Run these commands to set up interactive tables and warehouse
-- ============================================================================

USE ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;

USE DATABASE automated_intelligence;

-- Create schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS interactive;
USE SCHEMA interactive;

-- Step 1: Create interactive tables (aggregated customer analytics)
CREATE OR REPLACE INTERACTIVE TABLE customer_order_analytics
  CLUSTER BY (customer_id)
AS
SELECT 
  c.customer_id,
  c.first_name,
  c.last_name,
  c.email,
  c.customer_segment,
  COUNT(DISTINCT o.order_id) as total_orders,
  SUM(o.total_amount) as total_spent,
  AVG(o.total_amount) as avg_order_value,
  MIN(o.order_date) as first_order_date,
  MAX(o.order_date) as last_order_date
FROM automated_intelligence.raw.customers c
INNER JOIN automated_intelligence.raw.orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.email, c.customer_segment;

CREATE OR REPLACE INTERACTIVE TABLE order_lookup
  CLUSTER BY (order_id)
AS
SELECT 
  o.order_id,
  o.customer_id,
  o.order_date,
  o.order_status,
  o.total_amount,
  c.first_name,
  c.last_name,
  c.email
FROM automated_intelligence.raw.orders o
INNER JOIN automated_intelligence.raw.customers c ON o.customer_id = c.customer_id;

-- Step 2: Create interactive warehouse
CREATE OR REPLACE INTERACTIVE WAREHOUSE automated_intelligence_interactive_wh
  TABLES (customer_order_analytics, order_lookup)
  WAREHOUSE_SIZE = 'XSMALL';

ALTER WAREHOUSE automated_intelligence_interactive_wh RESUME;

-- Done! Now run the demo queries from demo_interactive_performance.sql
