-- ============================================================================
-- Openflow Data Generator Setup for Automated Intelligence
-- SIMPLIFIED VERSION - Uses Existing Infrastructure
-- Created: December 10, 2025
-- Purpose: Verify existing setup is ready for Openflow ingestion
-- ============================================================================

-- ============================================================================
-- NOTE: This project uses EXISTING infrastructure instead of creating new:
--  - User: dash (already exists with RSA key)
--  - Role: snowflake_intelligence_admin (already has all needed privileges)
--  - RSA Key: /automated-intelligence/snowpipe-streaming-java/rsa_key.p8
-- ============================================================================

USE ROLE snowflake_intelligence_admin;

-- ============================================================================
-- STEP 1: Verify User Exists
-- ============================================================================

SHOW USERS LIKE 'dash';

-- Expected: User 'dash' exists with TYPE = PERSON or SERVICE

-- ============================================================================
-- STEP 2: Verify RSA Key is Configured
-- ============================================================================

DESC USER dash;

-- Expected: RSA_PUBLIC_KEY field is populated
-- RSA_PUBLIC_KEY_FP: SHA256:uLX4NF5bIgDlUg7kBq7I4Z/r/eTtFOGkvATfXOC2TpY=
-- If key is missing, set it using the public key from snowpipe-streaming-java:
-- ALTER USER dash SET RSA_PUBLIC_KEY = '<key from rsa_key.pub>';

-- ============================================================================
-- STEP 3: Verify Role Has Database/Schema Access
-- ============================================================================

-- Test database access
SHOW GRANTS TO ROLE snowflake_intelligence_admin;

-- Verify can access automated_intelligence database
USE DATABASE automated_intelligence;
USE SCHEMA staging;

-- Expected: No errors

-- ============================================================================
-- STEP 4: Verify Table Access (SELECT and INSERT)
-- ============================================================================

-- Test SELECT on staging tables
SELECT COUNT(*) as current_count 
FROM automated_intelligence.staging.orders_staging;

SELECT COUNT(*) as current_count 
FROM automated_intelligence.staging.order_items_staging;

-- Test INSERT permission (insert a test record)
INSERT INTO automated_intelligence.staging.orders_staging VALUES (
  'test-openflow-' || UUID_STRING(),
  1,
  CURRENT_TIMESTAMP(),
  'pending',
  100.00,
  0.00,
  5.00
);

-- Verify test record appeared
SELECT * FROM automated_intelligence.staging.orders_staging 
WHERE order_id LIKE 'test-openflow-%';

-- Clean up test record
DELETE FROM automated_intelligence.staging.orders_staging 
WHERE order_id LIKE 'test-openflow-%';

-- Expected: All queries succeed

-- ============================================================================
-- STEP 5: Verify Warehouse Access
-- ============================================================================

USE WAREHOUSE automated_intelligence_wh;

-- Check warehouse size and status
SHOW WAREHOUSES LIKE 'automated_intelligence_wh';

-- Expected: Warehouse exists and can be used

-- ============================================================================
-- STEP 6: Verify Grants to User
-- ============================================================================

-- Check what roles are granted to dash user
SHOW GRANTS TO USER dash;

-- Expected: snowflake_intelligence_admin role is granted
-- If not, grant it:
-- GRANT ROLE snowflake_intelligence_admin TO USER dash;

-- ============================================================================
-- STEP 7: Create Monitoring View (Optional)
-- ============================================================================

CREATE OR REPLACE VIEW automated_intelligence.staging.openflow_ingestion_stats AS
SELECT 
  'orders_staging' as table_name,
  COUNT(*) as total_records,
  MIN(order_date) as earliest_record,
  MAX(order_date) as latest_record,
  DATEDIFF('minute', MAX(order_date), CURRENT_TIMESTAMP()) as minutes_since_last_record,
  ROUND(SUM(LENGTH(TO_JSON(*))), 2) as total_bytes
FROM automated_intelligence.staging.orders_staging
WHERE order_date >= DATEADD('day', -7, CURRENT_TIMESTAMP())
UNION ALL
SELECT 
  'order_items_staging',
  COUNT(*),
  NULL,
  NULL,
  NULL,
  ROUND(SUM(LENGTH(TO_JSON(*))), 2)
FROM automated_intelligence.staging.order_items_staging oi
WHERE EXISTS (
  SELECT 1 FROM automated_intelligence.staging.orders_staging o
  WHERE o.order_id = oi.order_id
  AND o.order_date >= DATEADD('day', -7, CURRENT_TIMESTAMP())
);

-- Test monitoring view
SELECT * FROM automated_intelligence.staging.openflow_ingestion_stats;

-- ============================================================================
-- VERIFICATION SUMMARY
-- ============================================================================

-- Run this to verify everything is ready:
SELECT 
  'User' as check_type, 
  'dash' as value,
  CASE WHEN COUNT(*) > 0 THEN '✓ EXISTS' ELSE '✗ MISSING' END as status
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID(-10))) -- Adjust -10 to match SHOW USERS query
WHERE "name" = 'dash'
UNION ALL
SELECT 
  'Database Access',
  'automated_intelligence',
  CASE WHEN CURRENT_DATABASE() = 'AUTOMATED_INTELLIGENCE' THEN '✓ ACCESSIBLE' ELSE '✗ NO ACCESS' END
UNION ALL
SELECT 
  'Schema Access',
  'staging',
  CASE WHEN CURRENT_SCHEMA() = 'STAGING' THEN '✓ ACCESSIBLE' ELSE '✗ NO ACCESS' END
UNION ALL
SELECT 
  'Warehouse',
  'automated_intelligence_wh',
  CASE WHEN CURRENT_WAREHOUSE() = 'AUTOMATED_INTELLIGENCE_WH' THEN '✓ ACTIVE' ELSE '✗ NOT ACTIVE' END;

-- Expected: All checks show ✓

-- ============================================================================
-- OPENFLOW CONFIGURATION PARAMETERS
-- ============================================================================

-- Use these values when configuring the Openflow connector in NiFi UI:

/*
SNOWFLAKE CONNECTION:
  Destination Database: AUTOMATED_INTELLIGENCE
  Destination Schema: STAGING
  Snowflake Auth: KEY_PAIR
  Snowflake Account: sfsenorthamerica-gen_ai_hol
  Snowflake Username: dash
  Snowflake Private Key File: <upload rsa_key.p8 from snowpipe-streaming-java/>
  Snowflake Private Key Password: <leave blank if not encrypted>
  Snowflake Role: snowflake_intelligence_admin
  Snowflake Warehouse: automated_intelligence_wh

TARGET TABLES:
  Orders Table: orders_staging
  Order Items Table: order_items_staging

DATA GENERATION:
  Orders per Batch: 100
  Items per Order: 1-10 (random)
  Generation Frequency: Every 10 seconds
  Customer ID Range: 1-10000
  Product ID Range: 1-1000
*/

-- ============================================================================
-- NOTES:
-- ============================================================================
-- 1. No new user or role needed - using existing dash/snowflake_intelligence_admin
-- 2. RSA key already configured - just upload rsa_key.p8 file to Openflow
-- 3. All privileges already granted - snowflake_intelligence_admin has full access
-- 4. Both Snowpipe Streaming and Openflow write to SAME staging tables
-- 5. Existing MERGE procedures handle data from both sources
-- ============================================================================

-- ============================================================================
-- IF YOU NEED TO RESET (DO NOT RUN IN PRODUCTION)
-- ============================================================================
/*
-- Truncate staging tables to start fresh
TRUNCATE TABLE automated_intelligence.staging.orders_staging;
TRUNCATE TABLE automated_intelligence.staging.order_items_staging;

-- Drop monitoring view
DROP VIEW IF EXISTS automated_intelligence.staging.openflow_ingestion_stats;
*/
