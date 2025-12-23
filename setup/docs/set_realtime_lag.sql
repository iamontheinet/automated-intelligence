-- Set Dynamic Tables to Near Real-Time (1 minute lag)
-- For use cases requiring fast analytics on streaming data

USE ROLE snowflake_intelligence_admin;
USE DATABASE automated_intelligence;
USE SCHEMA dynamic_tables;

-- Base enrichment tables: Change from 12 hours to 1 minute for near real-time
-- These read from raw.orders and raw.order_items (populated via Snowpipe Streaming)
ALTER DYNAMIC TABLE enriched_orders SET TARGET_LAG = '1 minute';
ALTER DYNAMIC TABLE enriched_order_items SET TARGET_LAG = '1 minute';

-- Downstream tables remain DOWNSTREAM (will refresh immediately after base tables)
-- No changes needed - they already cascade efficiently

-- Verify the changes
SELECT 
    table_name,
    CASE 
        WHEN GET_DDL('TABLE', 'automated_intelligence.dynamic_tables.' || table_name) LIKE '%target_lag = DOWNSTREAM%' THEN 'DOWNSTREAM'
        WHEN GET_DDL('TABLE', 'automated_intelligence.dynamic_tables.' || table_name) LIKE '%target_lag = ''1 minute''%' THEN '1 minute'
        WHEN GET_DDL('TABLE', 'automated_intelligence.dynamic_tables.' || table_name) LIKE '%target_lag = ''12 hours''%' THEN '12 hours'
        ELSE 'OTHER'
    END as target_lag_setting
FROM automated_intelligence.information_schema.tables
WHERE table_schema = 'DYNAMIC_TABLES'
  AND table_type = 'BASE TABLE'
ORDER BY 
    CASE table_name
        WHEN 'ENRICHED_ORDERS' THEN 1
        WHEN 'ENRICHED_ORDER_ITEMS' THEN 2
        WHEN 'FACT_ORDERS' THEN 3
        WHEN 'DAILY_BUSINESS_METRICS' THEN 4
        WHEN 'PRODUCT_PERFORMANCE_METRICS' THEN 5
    END;
