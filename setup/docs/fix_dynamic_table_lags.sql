-- Fix Dynamic Table TARGET_LAG settings
-- Change downstream tables from '12 hours' to DOWNSTREAM

USE ROLE snowflake_intelligence_admin;
USE DATABASE automated_intelligence;
USE SCHEMA dynamic_tables;

-- Base tables stay at 12 hours (correct)
-- These read from raw.orders and raw.order_items
ALTER DYNAMIC TABLE enriched_orders SET TARGET_LAG = '12 hours';
ALTER DYNAMIC TABLE enriched_order_items SET TARGET_LAG = '12 hours';

-- Downstream tables should use DOWNSTREAM (they depend on enriched tables)
ALTER DYNAMIC TABLE fact_orders SET TARGET_LAG = DOWNSTREAM;
ALTER DYNAMIC TABLE daily_business_metrics SET TARGET_LAG = DOWNSTREAM;
ALTER DYNAMIC TABLE product_performance_metrics SET TARGET_LAG = DOWNSTREAM;

-- Verify the changes
SELECT 
    table_name,
    CASE 
        WHEN GET_DDL('TABLE', 'automated_intelligence.dynamic_tables.' || table_name) LIKE '%target_lag = DOWNSTREAM%' THEN 'DOWNSTREAM'
        WHEN GET_DDL('TABLE', 'automated_intelligence.dynamic_tables.' || table_name) LIKE '%target_lag = ''1 minute''%' THEN '1 minute'
        WHEN GET_DDL('TABLE', 'automated_intelligence.dynamic_tables.' || table_name) LIKE '%target_lag = ''12 hours''%' THEN '12 hours'
        ELSE 'OTHER'
    END as target_lag
FROM automated_intelligence.information_schema.tables
WHERE table_schema = 'DYNAMIC_TABLES'
  AND table_type = 'BASE TABLE'
ORDER BY table_name;
