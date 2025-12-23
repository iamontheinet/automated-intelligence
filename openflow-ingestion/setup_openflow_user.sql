-- ============================================================================
-- Openflow Data Generator Setup for Automated Intelligence
-- Created: December 10, 2025
-- Purpose: Create service user, role, and privileges for Openflow-based
--          ingestion to complement existing Snowpipe Streaming
-- ============================================================================

USE ROLE snowflake_intelligence_admin;

-- ============================================================================
-- STEP 1: Create Service User
-- ============================================================================

CREATE USER IF NOT EXISTS openflow_kafka_user
  TYPE = SERVICE
  COMMENT = 'Service user for Openflow data generator - ingests to staging tables';

-- ============================================================================
-- STEP 2: Create Role for Openflow Ingestion
-- ============================================================================

CREATE ROLE IF NOT EXISTS openflow_kafka_role
  COMMENT = 'Role for Openflow ingestion to staging tables (orders/order_items)';

-- ============================================================================
-- STEP 3: Grant Database and Schema Privileges
-- ============================================================================

-- Grant database usage
GRANT USAGE ON DATABASE automated_intelligence TO ROLE openflow_kafka_role;

-- Grant schema usage  
GRANT USAGE ON SCHEMA automated_intelligence.staging TO ROLE openflow_kafka_role;

-- ============================================================================
-- STEP 4: Grant Table Privileges (Staging Tables Only)
-- ============================================================================

-- Grant INSERT on staging tables (Openflow writes here)
GRANT INSERT ON TABLE automated_intelligence.staging.orders_staging 
    TO ROLE openflow_kafka_role;

GRANT INSERT ON TABLE automated_intelligence.staging.order_items_staging 
    TO ROLE openflow_kafka_role;

-- Optional: Grant SELECT for validation queries
GRANT SELECT ON TABLE automated_intelligence.staging.orders_staging 
    TO ROLE openflow_kafka_role;

GRANT SELECT ON TABLE automated_intelligence.staging.order_items_staging 
    TO ROLE openflow_kafka_role;

-- ============================================================================
-- STEP 5: Grant Warehouse Privileges
-- ============================================================================

GRANT USAGE ON WAREHOUSE automated_intelligence_wh TO ROLE openflow_kafka_role;

-- Optional: Grant OPERATE to allow warehouse management
-- GRANT OPERATE ON WAREHOUSE automated_intelligence_wh TO ROLE openflow_kafka_role;

-- ============================================================================
-- STEP 6: Assign Role to User
-- ============================================================================

GRANT ROLE openflow_kafka_role TO USER openflow_kafka_user;

-- Set default role
ALTER USER openflow_kafka_user SET DEFAULT_ROLE = openflow_kafka_role;

-- ============================================================================
-- STEP 7: Configure Key-Pair Authentication
-- ============================================================================

-- IMPORTANT: You must generate RSA key pair externally using OpenSSL
-- See KEY_PAIR_SETUP.md for detailed instructions
-- 
-- Once you have the public key, run this command:
-- ALTER USER openflow_kafka_user SET RSA_PUBLIC_KEY = '<your_public_key_here>';
--
-- Example:
-- ALTER USER openflow_kafka_user SET RSA_PUBLIC_KEY = 'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...';

-- ============================================================================
-- STEP 8: Verification Queries
-- ============================================================================

-- Verify user was created
SHOW USERS LIKE 'openflow_kafka_user';

-- Verify role was created
SHOW ROLES LIKE 'openflow_kafka_role';

-- Check role grants
SHOW GRANTS TO ROLE openflow_kafka_role;

-- Check user's default role
SHOW GRANTS TO USER openflow_kafka_user;

-- Verify public key was set (after you configure it)
-- DESC USER openflow_kafka_user;

-- ============================================================================
-- STEP 9: Test Connection (After Key Configuration)
-- ============================================================================

-- Switch to the Openflow role to test permissions
USE ROLE openflow_kafka_role;
USE WAREHOUSE automated_intelligence_wh;
USE DATABASE automated_intelligence;
USE SCHEMA staging;

-- Test SELECT permission
SELECT COUNT(*) FROM orders_staging;
SELECT COUNT(*) FROM order_items_staging;

-- Test INSERT permission (insert a test record)
-- This will be done by Openflow, but you can test manually:
/*
INSERT INTO orders_staging VALUES (
  'test-uuid-' || UUID_STRING(),
  1,
  CURRENT_TIMESTAMP(),
  'pending',
  100.00,
  0.00,
  5.00
);
*/

-- Clean up test record if needed
-- DELETE FROM orders_staging WHERE order_id LIKE 'test-uuid-%';

-- ============================================================================
-- OPTIONAL: Create Monitoring View for Openflow Ingestion
-- ============================================================================

USE ROLE snowflake_intelligence_admin;

CREATE OR REPLACE VIEW automated_intelligence.staging.openflow_ingestion_stats AS
SELECT 
  'orders_staging' as table_name,
  COUNT(*) as total_records,
  MIN(order_date) as earliest_record,
  MAX(order_date) as latest_record,
  DATEDIFF('minute', MAX(order_date), CURRENT_TIMESTAMP()) as minutes_since_last_record
FROM automated_intelligence.staging.orders_staging
WHERE order_date >= DATEADD('day', -7, CURRENT_TIMESTAMP())
UNION ALL
SELECT 
  'order_items_staging',
  COUNT(*),
  NULL,
  NULL,
  NULL
FROM automated_intelligence.staging.order_items_staging oi
WHERE EXISTS (
  SELECT 1 FROM automated_intelligence.staging.orders_staging o
  WHERE o.order_id = oi.order_id
  AND o.order_date >= DATEADD('day', -7, CURRENT_TIMESTAMP())
);

-- Grant access to monitoring view
GRANT SELECT ON VIEW automated_intelligence.staging.openflow_ingestion_stats 
    TO ROLE openflow_kafka_role;

-- Test monitoring view
SELECT * FROM automated_intelligence.staging.openflow_ingestion_stats;

-- ============================================================================
-- STEP 10: Document Completion
-- ============================================================================

-- Record setup completion
COMMENT ON USER openflow_kafka_user IS 
  'Service user for Openflow data generator. Created: 2025-12-10. 
   Purpose: Generate and insert test data into staging.orders_staging and staging.order_items_staging.
   Authentication: RSA key-pair. 
   Role: openflow_kafka_role';

COMMENT ON ROLE openflow_kafka_role IS 
  'Role for Openflow ingestion. Created: 2025-12-10.
   Privileges: INSERT/SELECT on staging.orders_staging, staging.order_items_staging.
   Warehouse: automated_intelligence_wh.
   Purpose: Complement Snowpipe Streaming with Openflow-based data generator.';

-- ============================================================================
-- NOTES:
-- ============================================================================
-- 1. This setup DOES NOT conflict with existing Snowpipe Streaming
-- 2. Both Snowpipe Streaming and Openflow write to the SAME staging tables
-- 3. Existing MERGE procedures handle deduplication from both sources
-- 4. Openflow user has NO access to raw.orders or raw.order_items (security)
-- 5. Remember to generate and configure RSA key pair (see KEY_PAIR_SETUP.md)
-- 6. Use openflow_ingestion_stats view to monitor ingestion health
-- ============================================================================

-- ============================================================================
-- CLEANUP (IF NEEDED - DO NOT RUN IN PRODUCTION)
-- ============================================================================
/*
USE ROLE snowflake_intelligence_admin;

-- Drop monitoring view
DROP VIEW IF EXISTS automated_intelligence.staging.openflow_ingestion_stats;

-- Revoke grants
REVOKE USAGE ON WAREHOUSE automated_intelligence_wh FROM ROLE openflow_kafka_role;
REVOKE SELECT ON TABLE automated_intelligence.staging.order_items_staging FROM ROLE openflow_kafka_role;
REVOKE SELECT ON TABLE automated_intelligence.staging.orders_staging FROM ROLE openflow_kafka_role;
REVOKE INSERT ON TABLE automated_intelligence.staging.order_items_staging FROM ROLE openflow_kafka_role;
REVOKE INSERT ON TABLE automated_intelligence.staging.orders_staging FROM ROLE openflow_kafka_role;
REVOKE USAGE ON SCHEMA automated_intelligence.staging FROM ROLE openflow_kafka_role;
REVOKE USAGE ON DATABASE automated_intelligence FROM ROLE openflow_kafka_role;

-- Revoke role from user
REVOKE ROLE openflow_kafka_role FROM USER openflow_kafka_user;

-- Drop role and user
DROP ROLE IF EXISTS openflow_kafka_role;
DROP USER IF EXISTS openflow_kafka_user;
*/
