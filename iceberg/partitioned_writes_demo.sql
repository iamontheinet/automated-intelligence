-- ============================================================================
-- Iceberg Tables - Partitioned Writes Demo
-- ============================================================================
-- Snowflake manages Iceberg tables with automatic partitioning and
-- optimized writes. Available since 2025.
--
-- Key Features:
-- - Automatic partition pruning
-- - CLUSTER BY for write optimization
-- - Native Snowflake management with open format interoperability
-- ============================================================================

USE ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;
USE DATABASE AUTOMATED_INTELLIGENCE;
USE WAREHOUSE AUTOMATED_INTELLIGENCE_WH;

-- ============================================================================
-- PART 1: Create Iceberg Table with Partitioning
-- ============================================================================

-- Create schema for Iceberg tables
CREATE SCHEMA IF NOT EXISTS AUTOMATED_INTELLIGENCE.ICEBERG;

-- Create Iceberg table with date partitioning
-- Note: Requires external volume and catalog integration for external Iceberg
-- This example shows managed Iceberg table (Snowflake-managed)
CREATE OR REPLACE ICEBERG TABLE AUTOMATED_INTELLIGENCE.ICEBERG.ORDERS_PARTITIONED
    CLUSTER BY (order_year, order_month)
    CATALOG = 'SNOWFLAKE'
    EXTERNAL_VOLUME = 'my_iceberg_volume'  -- Replace with actual volume
    BASE_LOCATION = 'orders_partitioned/'
AS
SELECT 
    order_id,
    customer_id,
    order_date,
    YEAR(order_date) AS order_year,
    MONTH(order_date) AS order_month,
    total_amount,
    order_status
FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS
LIMIT 1000;

-- Alternative: Managed Iceberg Table (Snowflake handles storage)
CREATE OR REPLACE ICEBERG TABLE AUTOMATED_INTELLIGENCE.ICEBERG.ORDERS_MANAGED
    CATALOG = 'SNOWFLAKE'
    CLUSTER BY (YEAR(order_date), MONTH(order_date))
AS
SELECT 
    order_id,
    customer_id,
    order_date,
    total_amount,
    order_status
FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS
LIMIT 1000;

-- ============================================================================
-- PART 2: Verify Partitioning
-- ============================================================================

-- Check table properties
DESCRIBE TABLE AUTOMATED_INTELLIGENCE.ICEBERG.ORDERS_PARTITIONED;

-- View Iceberg metadata
SHOW ICEBERG TABLES IN SCHEMA AUTOMATED_INTELLIGENCE.ICEBERG;

-- Check clustering information
SELECT SYSTEM$CLUSTERING_INFORMATION(
    'AUTOMATED_INTELLIGENCE.ICEBERG.ORDERS_PARTITIONED',
    '(order_year, order_month)'
);

-- ============================================================================
-- PART 3: Partitioned Insert (Optimized Writes)
-- ============================================================================

-- Insert new data - Snowflake optimizes writes based on CLUSTER BY
INSERT INTO AUTOMATED_INTELLIGENCE.ICEBERG.ORDERS_PARTITIONED
SELECT 
    order_id,
    customer_id,
    order_date,
    YEAR(order_date) AS order_year,
    MONTH(order_date) AS order_month,
    total_amount,
    order_status
FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS
WHERE order_date >= '2025-01-01'
LIMIT 500;

-- ============================================================================
-- PART 4: Query with Partition Pruning
-- ============================================================================

-- This query benefits from partition pruning
-- Only scans partitions for Jan 2025
SELECT 
    order_year,
    order_month,
    COUNT(*) AS order_count,
    SUM(total_amount) AS revenue
FROM AUTOMATED_INTELLIGENCE.ICEBERG.ORDERS_PARTITIONED
WHERE order_year = 2025 AND order_month = 1
GROUP BY order_year, order_month;

-- Check query profile to verify partition pruning
-- Look for "Partitions scanned" vs "Partitions total"

-- ============================================================================
-- PART 5: Convert Existing Table to Iceberg
-- ============================================================================

-- Option 1: CREATE TABLE AS SELECT
CREATE OR REPLACE ICEBERG TABLE AUTOMATED_INTELLIGENCE.ICEBERG.CUSTOMERS_ICEBERG
    CATALOG = 'SNOWFLAKE'
    CLUSTER BY (customer_segment, state)
AS
SELECT * FROM AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS;

-- Option 2: ALTER TABLE (convert in place)
-- ALTER TABLE my_table CONVERT TO ICEBERG
-- Note: Check documentation for current support

-- ============================================================================
-- PART 6: Time Travel with Iceberg
-- ============================================================================

-- Iceberg tables support time travel via snapshots
SELECT * FROM AUTOMATED_INTELLIGENCE.ICEBERG.ORDERS_PARTITIONED
AT (TIMESTAMP => '2025-02-01 12:00:00'::TIMESTAMP);

-- View snapshot history
SELECT * FROM TABLE(AUTOMATED_INTELLIGENCE.INFORMATION_SCHEMA.ICEBERG_TABLE_SNAPSHOT_HISTORY(
    TABLE_NAME => 'ORDERS_PARTITIONED'
))
ORDER BY COMMITTED_AT DESC
LIMIT 10;

-- ============================================================================
-- PART 7: Best Practices for Partitioned Iceberg Tables
-- ============================================================================

/*
1. PARTITION SELECTION:
   - Choose columns with low cardinality (date parts, categories)
   - Avoid high-cardinality columns (IDs, timestamps)
   - 1000-10000 partitions is typical sweet spot

2. CLUSTER BY STRATEGIES:
   - Time-series data: CLUSTER BY (YEAR(date), MONTH(date))
   - Geographic data: CLUSTER BY (region, country)
   - Multi-tenant: CLUSTER BY (tenant_id, date)

3. WRITE OPTIMIZATION:
   - Insert data in partition order when possible
   - Use larger batches (avoid many small inserts)
   - Let Snowflake auto-compact micro-partitions

4. QUERY OPTIMIZATION:
   - Always filter on partition columns first
   - Use explicit predicates (WHERE year = 2025, not WHERE YEAR(date) = 2025)
   - Check query profile for partition pruning

5. INTEROPERABILITY:
   - Use external volumes for cross-engine access
   - Iceberg format enables Spark/Presto/Trino queries
   - Snowflake manages compaction and optimization
*/

-- ============================================================================
-- PART 8: External Iceberg Table (Read from Existing Iceberg)
-- ============================================================================

-- Read existing Iceberg table from external storage
/*
CREATE OR REPLACE ICEBERG TABLE AUTOMATED_INTELLIGENCE.ICEBERG.EXTERNAL_ORDERS
    EXTERNAL_VOLUME = 'my_s3_volume'
    CATALOG = 'SNOWFLAKE'
    BASE_LOCATION = 's3://my-bucket/iceberg/orders/'
    METADATA_FILE_PATH = 'metadata/v1.metadata.json';
*/

-- ============================================================================
-- Demo Complete
-- ============================================================================
SELECT '✅ Iceberg Partitioned Writes Demo Complete!' AS status;
