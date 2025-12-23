-- ============================================================================
-- Create Iceberg Schema and Tables for Analytics
-- ============================================================================
-- External volume: aws_s3_ext_volume_snowflake (pre-configured)
-- Base locations: ai/orders/, ai/order_items/
-- ============================================================================

USE ROLE snowflake_intelligence_admin;
USE WAREHOUSE automated_intelligence_wh;

-- ============================================================================
-- Step 1: Create analytics_iceberg schema
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS automated_intelligence.analytics_iceberg
   COMMENT = 'Analytics data in Iceberg format, ingested via Openflow';

USE SCHEMA automated_intelligence.analytics_iceberg;

-- ============================================================================
-- Step 2: Create Iceberg table for orders
-- ============================================================================

CREATE OR REPLACE ICEBERG TABLE automated_intelligence.analytics_iceberg.orders
   EXTERNAL_VOLUME = 'aws_s3_ext_volume_snowflake'
   CATALOG = 'SNOWFLAKE'
   BASE_LOCATION = 'ai/orders/'
   TARGET_FILE_SIZE = '128MB'
   ENABLE_DATA_COMPACTION = TRUE
   (
      ORDER_ID STRING NOT NULL,
      CUSTOMER_ID NUMBER(38,0) NOT NULL,
      ORDER_DATE TIMESTAMP_NTZ NOT NULL,
      ORDER_STATUS STRING,
      TOTAL_AMOUNT NUMBER(10,2),
      DISCOUNT_PERCENT NUMBER(5,2),
      SHIPPING_COST NUMBER(8,2)
   )
   COMMENT = 'Orders data in Iceberg format - ingested via Openflow';

-- Add clustering for query performance
ALTER ICEBERG TABLE automated_intelligence.analytics_iceberg.orders
   CLUSTER BY (ORDER_DATE, CUSTOMER_ID);

-- ============================================================================
-- Step 3: Create Iceberg table for order_items
-- ============================================================================

CREATE OR REPLACE ICEBERG TABLE automated_intelligence.analytics_iceberg.order_items
   EXTERNAL_VOLUME = 'aws_s3_ext_volume_snowflake'
   CATALOG = 'SNOWFLAKE'
   BASE_LOCATION = 'ai/order_items/'
   TARGET_FILE_SIZE = '128MB'
   ENABLE_DATA_COMPACTION = TRUE
   (
      ORDER_ITEM_ID STRING NOT NULL,
      ORDER_ID STRING NOT NULL,
      PRODUCT_ID NUMBER(38,0) NOT NULL,
      PRODUCT_NAME STRING,
      PRODUCT_CATEGORY STRING,
      QUANTITY NUMBER(38,0),
      UNIT_PRICE NUMBER(10,2),
      LINE_TOTAL NUMBER(12,2)
   )
   COMMENT = 'Order items data in Iceberg format - ingested via Openflow';

-- Add clustering for query performance
ALTER ICEBERG TABLE automated_intelligence.analytics_iceberg.order_items
   CLUSTER BY (ORDER_ID, PRODUCT_ID);

-- ============================================================================
-- Step 4: Verify tables created
-- ============================================================================

SHOW ICEBERG TABLES IN SCHEMA automated_intelligence.analytics_iceberg;

-- Check table properties
SELECT 
    table_name,
    table_type,
    is_iceberg
FROM automated_intelligence.information_schema.tables
WHERE table_schema = 'ANALYTICS_ICEBERG';

-- ============================================================================
-- Step 5: Create monitoring view
-- ============================================================================

CREATE OR REPLACE VIEW automated_intelligence.analytics_iceberg.ingestion_stats AS
SELECT 
    'orders' as table_name,
    COUNT(*) as total_records,
    MIN(order_date) as earliest_record,
    MAX(order_date) as latest_record,
    DATEDIFF('minute', MAX(order_date), CURRENT_TIMESTAMP()) as minutes_since_last_record
FROM automated_intelligence.analytics_iceberg.orders
UNION ALL
SELECT 
    'order_items',
    COUNT(*),
    NULL,
    NULL,
    NULL
FROM automated_intelligence.analytics_iceberg.order_items;

-- ============================================================================
-- Step 6: Grant permissions for Openflow ingestion
-- ============================================================================

-- Ensure snowflake_intelligence_admin has INSERT on Iceberg tables
GRANT INSERT ON TABLE automated_intelligence.analytics_iceberg.orders 
   TO ROLE snowflake_intelligence_admin;
GRANT INSERT ON TABLE automated_intelligence.analytics_iceberg.order_items 
   TO ROLE snowflake_intelligence_admin;

-- Grant SELECT for monitoring
GRANT SELECT ON TABLE automated_intelligence.analytics_iceberg.orders 
   TO ROLE snowflake_intelligence_admin;
GRANT SELECT ON TABLE automated_intelligence.analytics_iceberg.order_items 
   TO ROLE snowflake_intelligence_admin;

-- ============================================================================
-- Verification Complete
-- ============================================================================

SELECT 'Iceberg tables created successfully!' as status;
