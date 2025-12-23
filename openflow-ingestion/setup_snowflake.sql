-- ============================================================================
-- Openflow Kafka Connector - Snowflake Setup Script
-- ============================================================================
-- Purpose: Create all necessary Snowflake objects for Openflow data integration
-- Note: This setup is for FUTURE use cases alongside existing Snowpipe Streaming
-- Target: automated_intelligence database
-- Example use case: orders and order_items (or any future data sources)
-- ============================================================================

-- Required Roles:
-- - snowflake_intelligence_admin: Can handle most operations (users, roles, grants, databases)
-- - ACCOUNTADMIN: Only for External Access Integration (if snowflake_intelligence_admin cannot)

-- ============================================================================
-- Step 1: Create Service User for Openflow
-- ============================================================================

USE ROLE snowflake_intelligence_admin;

CREATE USER IF NOT EXISTS openflow_kafka_user
  TYPE = SERVICE
  COMMENT = 'Service user for Openflow Kafka connector ingestion';

-- ============================================================================
-- Step 2: Create Dedicated Role
-- ============================================================================

-- snowflake_intelligence_admin has CREATE ROLE privilege
CREATE ROLE IF NOT EXISTS openflow_kafka_role
  COMMENT = 'Role for Openflow Kafka data ingestion';

-- ============================================================================
-- Step 3: Grant Database and Schema Privileges
-- ============================================================================

-- Database access
GRANT USAGE ON DATABASE automated_intelligence TO ROLE openflow_kafka_role;

-- Schema access (raw schema for landing data)
GRANT USAGE ON SCHEMA automated_intelligence.raw TO ROLE openflow_kafka_role;
GRANT CREATE TABLE ON SCHEMA automated_intelligence.raw TO ROLE openflow_kafka_role;

-- If tables already exist, grant ownership
-- Uncomment these if you want Openflow to write to existing tables
-- GRANT OWNERSHIP ON TABLE automated_intelligence.raw.orders TO ROLE openflow_kafka_role;
-- GRANT OWNERSHIP ON TABLE automated_intelligence.raw.order_items TO ROLE openflow_kafka_role;

-- Warehouse access
GRANT USAGE ON WAREHOUSE automated_intelligence_wh TO ROLE openflow_kafka_role;

-- ============================================================================
-- Step 4: Assign Role to User
-- ============================================================================

GRANT ROLE openflow_kafka_role TO USER openflow_kafka_user;
ALTER USER openflow_kafka_user SET DEFAULT_ROLE = openflow_kafka_role;

-- ============================================================================
-- Step 5: Network Rules for SPCS Deployment (Kafka Access)
-- ============================================================================
-- Note: Replace kafka broker endpoints with your actual Kafka cluster

-- Try with snowflake_intelligence_admin first (has CREATE INTEGRATION privilege)
-- If this fails, use ACCOUNTADMIN

-- Create network rule for Kafka brokers
-- IMPORTANT: Update VALUE_LIST with your actual Kafka broker host:port pairs
CREATE OR REPLACE NETWORK RULE kafka_brokers_network_rule
  TYPE = HOST_PORT
  MODE = EGRESS
  VALUE_LIST = (
    'kafka-broker-1.example.com:9092',
    'kafka-broker-2.example.com:9092',
    'kafka-broker-3.example.com:9092'
  )
  COMMENT = 'Network rule allowing Openflow runtime to access Kafka brokers';

-- Create external access integration (snowflake_intelligence_admin has CREATE INTEGRATION)
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION kafka_external_access_integration
  ALLOWED_NETWORK_RULES = (kafka_brokers_network_rule)
  ENABLED = TRUE
  COMMENT = 'External access integration for Openflow Kafka connector';

-- Grant integration usage to Openflow role
GRANT USAGE ON INTEGRATION kafka_external_access_integration TO ROLE openflow_kafka_role;

-- ============================================================================
-- Step 6: Optional - Create Monitoring Views
-- ============================================================================

USE DATABASE automated_intelligence;
USE SCHEMA raw;

-- View to monitor ingestion freshness
CREATE OR REPLACE VIEW openflow_ingestion_status AS
SELECT 
  'orders' as table_name,
  COUNT(*) as total_records,
  MIN(order_date) as earliest_record,
  MAX(order_date) as latest_record,
  DATEDIFF('minute', MAX(order_date), CURRENT_TIMESTAMP()) as minutes_since_latest
FROM automated_intelligence.raw.orders

UNION ALL

SELECT 
  'order_items' as table_name,
  COUNT(*) as total_records,
  NULL as earliest_record,
  NULL as latest_record,
  NULL as minutes_since_latest
FROM automated_intelligence.raw.order_items;

GRANT SELECT ON VIEW openflow_ingestion_status TO ROLE openflow_kafka_role;

-- ============================================================================
-- Step 7: Verification Queries
-- ============================================================================

-- Verify user and role setup
SHOW USERS LIKE 'openflow_kafka_user';
SHOW GRANTS TO ROLE openflow_kafka_role;
SHOW GRANTS TO USER openflow_kafka_user;

-- Verify network rules (SPCS only)
SHOW NETWORK RULES LIKE 'kafka_brokers_network_rule';
SHOW INTEGRATIONS LIKE 'kafka_external_access_integration';

-- ============================================================================
-- NEXT STEPS
-- ============================================================================
/*
1. Generate RSA key pair for authentication (run in terminal):
   
   openssl genrsa -out openflow_rsa_key.pem 2048
   openssl rsa -in openflow_rsa_key.pem -pubout -out openflow_rsa_key.pub
   openssl pkcs8 -topk8 -inform PEM -in openflow_rsa_key.pem -outform PEM -nocrypt -out openflow_rsa_key.p8

2. Set public key for openflow_kafka_user:

   ALTER USER openflow_kafka_user SET RSA_PUBLIC_KEY = '<paste_public_key_content>';

3. Store private key in secrets manager (AWS Secrets Manager, Azure Key Vault, or HashiCorp Vault)

4. Create Openflow deployment in Snowsight:
   - Navigate to Admin → Openflow
   - Create Deployment (SPCS recommended)
   - Create Runtime

5. Install Kafka connector from gallery

6. Configure connector parameters using setup in PLAN.md

7. Enable controller services and start data flow
*/

-- ============================================================================
-- CLEANUP (if needed)
-- ============================================================================
/*
-- Uncomment to remove all Openflow resources

USE ROLE snowflake_intelligence_admin;

DROP INTEGRATION IF EXISTS kafka_external_access_integration;
DROP NETWORK RULE IF EXISTS kafka_brokers_network_rule;
DROP USER IF EXISTS openflow_kafka_user;
DROP ROLE IF EXISTS openflow_kafka_role;

USE DATABASE automated_intelligence;
DROP VIEW IF EXISTS raw.openflow_ingestion_status;
*/
