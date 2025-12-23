-- ============================================================================
-- Staging Pipeline Setup for Gen2 Data Engineering Demo
-- ============================================================================
-- This script creates the staging layer infrastructure for a production-grade
-- data pipeline that showcases Gen2 warehouse performance improvements.
--
-- Pipeline Flow:
--   1. Snowpipe Streaming → staging.* (ingestion layer)
--   2. Gen2 MERGE/UPDATE → raw.* (transformation layer with benchmarking)
--   3. Existing downstream: Dynamic Tables → Interactive Tables → ML → Dashboard
-- ============================================================================

USE ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;
USE DATABASE AUTOMATED_INTELLIGENCE;
USE WAREHOUSE AUTOMATED_INTELLIGENCE_WH;

-- ============================================================================
-- 1. CREATE STAGING SCHEMA
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS staging
  COMMENT = 'Staging layer for Snowpipe Streaming ingestion before MERGE to raw tables';

USE SCHEMA staging;

-- ============================================================================
-- 2. CREATE STAGING TABLES (Same structure as raw, no constraints)
-- ============================================================================

-- NOTE: We don't create customers_staging because:
-- - Customers already exist in raw.customers (from registration)
-- - Snowpipe Streaming only streams ORDERS for existing customers
-- - Customer updates are rare and handled separately

-- Orders staging table
CREATE TABLE IF NOT EXISTS orders_staging (
    order_id INTEGER,
    customer_id INTEGER,
    order_date TIMESTAMP_NTZ,
    order_status STRING,
    total_amount FLOAT,
    payment_method STRING,
    shipping_address STRING,
    shipping_city STRING,
    shipping_state STRING,
    shipping_zip STRING,
    inserted_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Staging table for order data from Snowpipe Streaming - append-only, no PK constraint';

-- Order items staging table
CREATE TABLE IF NOT EXISTS order_items_staging (
    order_item_id INTEGER,
    order_id INTEGER,
    product_id INTEGER,
    product_name STRING,
    product_category STRING,
    quantity INTEGER,
    price FLOAT,
    discount_percent FLOAT,
    line_total FLOAT,
    inserted_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Staging table for order item data from Snowpipe Streaming - append-only, no PK constraint';

-- ============================================================================
-- 3. CREATE GEN2 WAREHOUSE
-- ============================================================================

CREATE WAREHOUSE IF NOT EXISTS automated_intelligence_gen2_wh
WITH 
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    RESOURCE_CONSTRAINT = 'STANDARD_GEN_2'
    COMMENT = 'Gen2 warehouse for data transformation with improved MERGE/UPDATE/DELETE performance';

-- ============================================================================
-- 4. PIPES FOR STAGING TABLES
-- ============================================================================

-- NOTE: As of Dec 11, 2025 release, Snowpipe Streaming uses DEFAULT PIPES
-- Default pipes are system-generated with naming convention: <TABLE_NAME>-STREAMING
-- No manual CREATE PIPE statements needed!
--
-- Default pipes for this setup:
--   - ORDERS_STAGING-STREAMING (targets staging.orders_staging)
--   - ORDER_ITEMS_STAGING-STREAMING (targets staging.order_items_staging)
--
-- These are automatically available when you reference them in the SDK client configuration.
-- See: https://docs.snowflake.com/en/release-notes/2025/other/2025-12-11-default-pipe

-- DEPRECATED: Manual pipe creation (pre-Dec 2025)
-- CREATE OR REPLACE PIPE orders_staging_pipe...
-- CREATE OR REPLACE PIPE order_items_staging_pipe...
-- These are NO LONGER NEEDED with the default pipe capability.

-- ============================================================================
-- 5. VERIFY SETUP
-- ============================================================================

SELECT 'Staging schema created' AS status;
SHOW TABLES IN SCHEMA staging;
SHOW WAREHOUSES LIKE 'automated_intelligence_gen2_wh';
SHOW PIPES IN SCHEMA staging;

SELECT 
    'Setup complete! Next steps:' AS message,
    '1. Update Snowpipe config to use staging pipes' AS step1,
    '2. Run setup_merge_procedures.sql to create MERGE/UPDATE procedures' AS step2,
    '3. Deploy new dashboard page to show pipeline' AS step3;
