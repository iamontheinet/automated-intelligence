-- Migration Script: Integer IDs to UUID (VARCHAR)
-- This script updates all tables to support UUID-based IDs instead of integer IDs

USE ROLE snowflake_intelligence_admin;
USE WAREHOUSE automated_intelligence_wh;
USE DATABASE automated_intelligence;

-- ============================================================================
-- STEP 1: Drop all dynamic tables (they depend on raw tables)
-- ============================================================================

DROP DYNAMIC TABLE IF EXISTS dynamic_tables.product_performance_metrics;
DROP DYNAMIC TABLE IF EXISTS dynamic_tables.daily_business_metrics;
DROP DYNAMIC TABLE IF EXISTS dynamic_tables.fact_orders;
DROP DYNAMIC TABLE IF EXISTS dynamic_tables.enriched_order_items;
DROP DYNAMIC TABLE IF EXISTS dynamic_tables.enriched_orders;

-- ============================================================================
-- STEP 2: Backup existing data from RAW tables
-- ============================================================================

CREATE OR REPLACE TABLE raw.orders_backup AS SELECT * FROM raw.orders;
CREATE OR REPLACE TABLE raw.order_items_backup AS SELECT * FROM raw.order_items;

-- ============================================================================
-- STEP 3: Recreate RAW tables with VARCHAR IDs
-- ============================================================================

CREATE OR REPLACE TABLE raw.orders (
    order_id VARCHAR(36) NOT NULL,
    customer_id NUMBER(38,0) NOT NULL,
    order_date TIMESTAMP_NTZ(9) NOT NULL,
    order_status VARCHAR(20),
    total_amount NUMBER(10,2),
    discount_percent NUMBER(5,2),
    shipping_cost NUMBER(8,2),
    PRIMARY KEY (order_id)
);

CREATE OR REPLACE TABLE raw.order_items (
    order_item_id VARCHAR(36) NOT NULL,
    order_id VARCHAR(36) NOT NULL,
    product_id NUMBER(38,0),
    product_name VARCHAR(100),
    product_category VARCHAR(50),
    quantity INT,
    unit_price NUMBER(10,2),
    line_total NUMBER(12,2),
    PRIMARY KEY (order_item_id),
    FOREIGN KEY (order_id) REFERENCES raw.orders(order_id)
);

-- ============================================================================
-- STEP 4: Recreate STAGING tables with VARCHAR IDs
-- ============================================================================

CREATE OR REPLACE TABLE staging.orders_staging (
    order_id VARCHAR(36),
    customer_id NUMBER(38,0),
    order_date TIMESTAMP_NTZ(9),
    order_status VARCHAR(20),
    total_amount FLOAT,
    discount_percent FLOAT,
    shipping_cost FLOAT
);

CREATE OR REPLACE TABLE staging.order_items_staging (
    order_item_id VARCHAR(36),
    order_id VARCHAR(36),
    product_id NUMBER(38,0),
    product_name VARCHAR(100),
    product_category VARCHAR(50),
    quantity INT,
    unit_price FLOAT,
    line_total FLOAT
);

-- ============================================================================
-- STEP 5: Recreate DYNAMIC TABLES with VARCHAR IDs
-- ============================================================================

-- Enriched Orders
CREATE OR REPLACE DYNAMIC TABLE dynamic_tables.enriched_orders
TARGET_LAG = '1 minute'
WAREHOUSE = automated_intelligence_wh
REFRESH_MODE = INCREMENTAL
AS
SELECT DISTINCT
    o.order_id,
    o.customer_id,
    o.order_date,
    o.order_status,
    o.total_amount,
    o.discount_percent,
    o.shipping_cost,
    DATE(o.order_date) as order_date_only,
    EXTRACT(YEAR FROM o.order_date) as order_year,
    EXTRACT(MONTH FROM o.order_date) as order_month,
    EXTRACT(DAY FROM o.order_date) as order_day,
    DAYOFWEEK(o.order_date) as day_of_week,
    CASE 
        WHEN DAYOFWEEK(o.order_date) IN (0, 6) THEN 'Weekend'
        ELSE 'Weekday'
    END as day_type,
    o.total_amount * (o.discount_percent / 100) as discount_amount,
    o.total_amount * (1 - o.discount_percent / 100) + o.shipping_cost as final_amount,
    CASE 
        WHEN o.total_amount >= 500 THEN 'Premium'
        WHEN o.total_amount >= 200 THEN 'Standard'
        ELSE 'Basic'
    END as order_tier
FROM automated_intelligence.raw.orders o;

-- Enriched Order Items
CREATE OR REPLACE DYNAMIC TABLE dynamic_tables.enriched_order_items
TARGET_LAG = '1 minute'
WAREHOUSE = automated_intelligence_wh
REFRESH_MODE = INCREMENTAL
AS
SELECT DISTINCT
    oi.order_item_id,
    oi.order_id,
    oi.product_id,
    oi.product_name,
    oi.product_category,
    oi.quantity,
    oi.unit_price,
    oi.line_total,
    CASE 
        WHEN oi.unit_price >= 300 THEN 'Premium'
        WHEN oi.unit_price >= 100 THEN 'Mid-Range'
        ELSE 'Budget'
    END as price_tier
FROM automated_intelligence.raw.order_items oi;

-- Fact Orders
CREATE OR REPLACE DYNAMIC TABLE dynamic_tables.fact_orders
TARGET_LAG = '12 hours'
WAREHOUSE = automated_intelligence_wh
REFRESH_MODE = INCREMENTAL
AS
SELECT
    o.order_id,
    o.customer_id,
    o.order_date,
    o.order_status,
    o.total_amount,
    o.discount_percent,
    o.shipping_cost,
    o.order_date_only,
    o.order_year,
    o.order_month,
    o.order_day,
    o.day_of_week,
    o.day_type,
    o.discount_amount,
    o.final_amount,
    o.order_tier,
    c.first_name,
    c.last_name,
    c.email,
    c.city,
    c.state,
    c.customer_segment,
    COUNT(DISTINCT oi.order_item_id) as item_count,
    SUM(oi.line_total) as items_subtotal
FROM automated_intelligence.dynamic_tables.enriched_orders o
LEFT JOIN automated_intelligence.raw.customers c ON o.customer_id = c.customer_id
LEFT JOIN automated_intelligence.dynamic_tables.enriched_order_items oi ON o.order_id = oi.order_id
GROUP BY 
    o.order_id, o.customer_id, o.order_date, o.order_status,
    o.total_amount, o.discount_percent, o.shipping_cost,
    o.order_date_only, o.order_year, o.order_month, o.order_day,
    o.day_of_week, o.day_type, o.discount_amount, o.final_amount, o.order_tier,
    c.first_name, c.last_name, c.email, c.city, c.state, c.customer_segment;

-- Daily Business Metrics
CREATE OR REPLACE DYNAMIC TABLE dynamic_tables.daily_business_metrics
TARGET_LAG = '12 hours'
WAREHOUSE = automated_intelligence_wh
REFRESH_MODE = INCREMENTAL
AS
SELECT
    order_date_only,
    order_year,
    order_month,
    order_day,
    day_of_week,
    day_type,
    COUNT(DISTINCT order_id) as total_orders,
    SUM(final_amount) as total_net_revenue,
    AVG(final_amount) as avg_order_value,
    SUM(discount_amount) as total_discounts,
    AVG(discount_percent) as avg_discount_percent,
    COUNT(DISTINCT CASE WHEN order_tier = 'Premium' THEN order_id END) as premium_orders,
    COUNT(DISTINCT CASE WHEN order_tier = 'Standard' THEN order_id END) as standard_orders,
    COUNT(DISTINCT CASE WHEN order_tier = 'Basic' THEN order_id END) as basic_orders,
    SUM(CASE WHEN order_tier = 'Premium' THEN final_amount ELSE 0 END) as premium_revenue,
    SUM(CASE WHEN order_tier = 'Standard' THEN final_amount ELSE 0 END) as standard_revenue,
    COUNT(DISTINCT CASE WHEN final_amount >= 1000 THEN order_id END) as large_orders,
    COUNT(DISTINCT CASE WHEN item_count > 5 THEN order_id END) as multi_item_orders
FROM automated_intelligence.dynamic_tables.fact_orders
GROUP BY 
    order_date_only, order_year, order_month, order_day,
    day_of_week, day_type;

-- Product Performance Metrics
CREATE OR REPLACE DYNAMIC TABLE dynamic_tables.product_performance_metrics
TARGET_LAG = '12 hours'
WAREHOUSE = automated_intelligence_wh
REFRESH_MODE = INCREMENTAL
AS
SELECT
    oi.product_category,
    oi.product_name,
    COUNT(DISTINCT oi.order_item_id) as total_items_sold,
    SUM(oi.quantity) as total_quantity_sold,
    SUM(oi.line_total) as total_revenue,
    AVG(oi.unit_price) as avg_unit_price,
    COUNT(DISTINCT oi.order_id) as unique_orders,
    COUNT(DISTINCT CASE WHEN oi.price_tier = 'Premium' THEN oi.order_item_id END) as premium_items,
    COUNT(DISTINCT CASE WHEN oi.price_tier = 'Mid-Range' THEN oi.order_item_id END) as midrange_items,
    COUNT(DISTINCT CASE WHEN oi.price_tier = 'Budget' THEN oi.order_item_id END) as budget_items
FROM automated_intelligence.dynamic_tables.enriched_order_items oi
GROUP BY oi.product_category, oi.product_name;

-- ============================================================================
-- STEP 6: Show migration results
-- ============================================================================

SELECT 'Migration complete! New schemas ready for UUID-based IDs' as status;

SELECT 
    'raw.orders' as table_name,
    COUNT(*) as row_count,
    'Backup available in raw.orders_backup' as note
FROM raw.orders
UNION ALL
SELECT 
    'raw.order_items' as table_name,
    COUNT(*) as row_count,
    'Backup available in raw.order_items_backup' as note
FROM raw.order_items
UNION ALL
SELECT 
    'dynamic_tables.enriched_orders' as table_name,
    COUNT(*) as row_count,
    'Ready for UUID data' as note
FROM dynamic_tables.enriched_orders
UNION ALL
SELECT 
    'dynamic_tables.daily_business_metrics' as table_name,
    COUNT(*) as row_count,
    'Ready for UUID data' as note
FROM dynamic_tables.daily_business_metrics;
