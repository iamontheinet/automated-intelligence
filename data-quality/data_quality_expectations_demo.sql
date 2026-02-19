-- ============================================================================
-- Data Quality Expectations Demo (Preview - 2025)
-- ============================================================================
-- Declarative data quality rules that run during DML operations.
-- Similar to dbt tests but enforced at the table level.
--
-- Note: Data Quality Expectations are in preview. Check documentation
-- for current availability and syntax.
-- ============================================================================

USE ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;
USE DATABASE AUTOMATED_INTELLIGENCE;
USE WAREHOUSE AUTOMATED_INTELLIGENCE_WH;

-- ============================================================================
-- PART 1: Data Metric Functions (DMF) - Available Now
-- ============================================================================

-- DMFs provide built-in and custom data quality checks
-- They can be scheduled to run periodically on tables

-- View available built-in DMFs
SHOW DATA METRIC FUNCTIONS IN ACCOUNT;

-- Example: Check for NULL values in a column
SELECT SNOWFLAKE.CORE.NULL_COUNT(
    SELECT customer_id FROM AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS
) AS null_customer_ids;

-- Example: Check for duplicate values
SELECT SNOWFLAKE.CORE.DUPLICATE_COUNT(
    SELECT order_id FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS
) AS duplicate_orders;

-- Example: Check freshness
SELECT SNOWFLAKE.CORE.FRESHNESS(
    SELECT order_date FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS
) AS data_freshness_hours;

-- ============================================================================
-- PART 2: Associate DMFs with Tables
-- ============================================================================

-- Attach a NULL check to the customers table
ALTER TABLE AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS
ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT
ON (customer_id)
SCHEDULE = '60 MINUTES';

-- Attach a duplicate check to orders
ALTER TABLE AUTOMATED_INTELLIGENCE.RAW.ORDERS
ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.DUPLICATE_COUNT
ON (order_id)
SCHEDULE = '60 MINUTES';

-- View DMFs attached to a table
SHOW DATA METRIC FUNCTIONS ON AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS;

-- ============================================================================
-- PART 3: Custom Data Metric Functions
-- ============================================================================

-- Create a custom DMF for business rules
CREATE OR REPLACE DATA METRIC FUNCTION AUTOMATED_INTELLIGENCE.RAW.check_order_total_positive(
    tbl TABLE(total_amount NUMBER)
)
RETURNS NUMBER
AS
$$
    SELECT COUNT(*) FROM tbl WHERE total_amount < 0
$$;

-- Attach custom DMF to orders table
ALTER TABLE AUTOMATED_INTELLIGENCE.RAW.ORDERS
ADD DATA METRIC FUNCTION AUTOMATED_INTELLIGENCE.RAW.check_order_total_positive
ON (total_amount)
SCHEDULE = '60 MINUTES';

-- ============================================================================
-- PART 4: Query DMF Results
-- ============================================================================

-- View DMF execution history
SELECT *
FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS
WHERE TABLE_NAME = 'ORDERS'
ORDER BY MEASUREMENT_TIME DESC
LIMIT 10;

-- Alternative: Account Usage view
SELECT *
FROM SNOWFLAKE.ACCOUNT_USAGE.DATA_QUALITY_MONITORING_USAGE
WHERE TABLE_NAME = 'ORDERS'
ORDER BY MEASUREMENT_TIME DESC
LIMIT 10;

-- ============================================================================
-- PART 5: Data Quality Alerts (Create monitoring table)
-- ============================================================================

-- Create a table to store data quality alerts
CREATE OR REPLACE TABLE AUTOMATED_INTELLIGENCE.RAW.DATA_QUALITY_ALERTS (
    alert_id INT AUTOINCREMENT,
    check_name VARCHAR,
    table_name VARCHAR,
    column_name VARCHAR,
    check_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    issue_count INT,
    severity VARCHAR,
    description VARCHAR
);

-- Insert alerts based on DMF results (manual process for now)
INSERT INTO AUTOMATED_INTELLIGENCE.RAW.DATA_QUALITY_ALERTS 
    (check_name, table_name, column_name, issue_count, severity, description)
SELECT 
    'NULL_CHECK', 
    'CUSTOMERS', 
    'CUSTOMER_ID', 
    SNOWFLAKE.CORE.NULL_COUNT(SELECT customer_id FROM AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS),
    CASE 
        WHEN SNOWFLAKE.CORE.NULL_COUNT(SELECT customer_id FROM AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS) > 0 
        THEN 'HIGH' ELSE 'OK' 
    END,
    'Primary key should not have NULL values';

-- ============================================================================
-- PART 6: Expectations on Dynamic Tables (Future)
-- ============================================================================

/*
-- Data Quality Expectations allow declarative rules on Dynamic Tables
-- (Preview feature - syntax may change)

CREATE OR REPLACE DYNAMIC TABLE orders_validated
TARGET_LAG = '1 hour'
WAREHOUSE = AUTOMATED_INTELLIGENCE_WH
WITH DATA QUALITY EXPECTATIONS (
    not_null(order_id),
    not_null(customer_id),
    positive(total_amount),
    in_range(discount_percent, 0, 100),
    unique(order_id),
    foreign_key(customer_id REFERENCES customers(customer_id))
)
AS
SELECT * FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS;

-- When expectations fail:
-- - Rows can be quarantined to a separate table
-- - Alerts can be generated
-- - Pipeline can continue or halt based on configuration
*/

-- ============================================================================
-- PART 7: Best Practices
-- ============================================================================

/*
DATA QUALITY STRATEGY:

1. TIER 1 - CRITICAL (Block on failure):
   - Primary keys: NOT NULL, UNIQUE
   - Foreign keys: REFERENCES
   - Required fields: NOT NULL

2. TIER 2 - IMPORTANT (Alert on failure):
   - Business rules: positive amounts, valid ranges
   - Freshness checks: data not stale
   - Completeness: expected row counts

3. TIER 3 - MONITORING (Log only):
   - Duplicate detection
   - Outlier detection
   - Distribution changes

IMPLEMENTATION:
- Use DMFs for scheduled batch checks
- Use column constraints for immediate enforcement
- Use Expectations for pipeline-level rules (when GA)
*/

-- ============================================================================
-- Demo Complete
-- ============================================================================
SELECT '✅ Data Quality Demo Complete!' AS status;
