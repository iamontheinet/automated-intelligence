-- Truncate tables to start fresh with new ingestion data
-- Run this script before starting a new ingestion run

-- 1. Truncate RAW layer (source data from Snowpipe Streaming)
TRUNCATE TABLE AUTOMATED_INTELLIGENCE.RAW.ORDERS;
TRUNCATE TABLE AUTOMATED_INTELLIGENCE.RAW.ORDER_ITEMS;

-- 2. Drop and recreate downstream Dynamic Tables (to avoid time travel errors)
-- These depend on FACT_ORDERS and need fresh start after truncation
DROP DYNAMIC TABLE IF EXISTS AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES.DAILY_BUSINESS_METRICS;
DROP DYNAMIC TABLE IF EXISTS AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES.PRODUCT_PERFORMANCE_METRICS;
DROP DYNAMIC TABLE IF EXISTS AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES.FACT_ORDERS;

-- Recreate FACT_ORDERS (Tier 2)
CREATE OR REPLACE DYNAMIC TABLE AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES.FACT_ORDERS
TARGET_LAG = DOWNSTREAM
WAREHOUSE = AUTOMATED_INTELLIGENCE_WH
REFRESH_MODE = INCREMENTAL
AS
SELECT
    eo.order_id,
    eo.customer_id,
    eo.order_date,
    eo.order_date_only,
    eo.order_year,
    eo.order_quarter,
    eo.order_month,
    eo.order_day_of_week,
    eo.order_day_name,
    eo.order_week,
    eo.order_status,
    
    -- Order-level metrics
    eo.total_amount,
    eo.discount_percent,
    eo.discount_amount,
    eo.net_amount,
    eo.shipping_cost,
    eo.final_amount,
    eo.has_discount,
    eo.discount_tier,
    eo.order_size_category,
    
    -- Item-level details
    eoi.order_item_id,
    eoi.product_id,
    eoi.product_name,
    eoi.product_category,
    eoi.quantity,
    eoi.unit_price,
    eoi.line_total,
    eoi.actual_unit_price,
    eoi.unit_price_variance,
    eoi.is_skis,
    eoi.is_snowboards,
    eoi.quantity_tier,
    
    -- Calculated metrics
    COUNT(eoi.order_item_id) OVER (PARTITION BY eo.order_id) AS items_per_order,
    SUM(eoi.line_total) OVER (PARTITION BY eo.order_id) AS order_items_total
FROM AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES.ENRICHED_ORDERS eo
INNER JOIN AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES.ENRICHED_ORDER_ITEMS eoi
    ON eo.order_id = eoi.order_id;

-- Recreate DAILY_BUSINESS_METRICS (Tier 3)
CREATE OR REPLACE DYNAMIC TABLE AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES.DAILY_BUSINESS_METRICS
TARGET_LAG = DOWNSTREAM
WAREHOUSE = AUTOMATED_INTELLIGENCE_WH
REFRESH_MODE = INCREMENTAL
AS
SELECT
    order_date_only,
    order_year,
    order_quarter,
    order_month,
    order_week,
    order_day_name,
    
    -- Order metrics
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_id) AS unique_customers,
    AVG(items_per_order) AS avg_items_per_order,
    
    -- Revenue metrics
    SUM(total_amount) AS total_revenue,
    SUM(net_amount) AS total_net_revenue,
    SUM(discount_amount) AS total_discounts,
    SUM(shipping_cost) AS total_shipping,
    SUM(final_amount) AS total_final_revenue,
    AVG(final_amount) AS avg_order_value,
    
    -- Discount analysis
    COUNT(DISTINCT CASE WHEN has_discount THEN order_id END) AS orders_with_discount,
    ROUND(COUNT(DISTINCT CASE WHEN has_discount THEN order_id END)::DECIMAL / COUNT(DISTINCT order_id) * 100, 2) AS discount_penetration_pct,
    AVG(CASE WHEN has_discount THEN discount_percent END) AS avg_discount_percent,
    
    -- Order size distribution
    COUNT(DISTINCT CASE WHEN order_size_category = 'Small' THEN order_id END) AS small_orders,
    COUNT(DISTINCT CASE WHEN order_size_category = 'Medium' THEN order_id END) AS medium_orders,
    COUNT(DISTINCT CASE WHEN order_size_category = 'Large' THEN order_id END) AS large_orders,
    COUNT(DISTINCT CASE WHEN order_size_category = 'Extra Large' THEN order_id END) AS extra_large_orders
FROM AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES.FACT_ORDERS
GROUP BY 
    order_date_only,
    order_year,
    order_quarter,
    order_month,
    order_week,
    order_day_name;

-- Recreate PRODUCT_PERFORMANCE_METRICS (Tier 3)
CREATE OR REPLACE DYNAMIC TABLE AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES.PRODUCT_PERFORMANCE_METRICS
TARGET_LAG = DOWNSTREAM
WAREHOUSE = AUTOMATED_INTELLIGENCE_WH
REFRESH_MODE = INCREMENTAL
AS
SELECT
    product_category,
    
    -- Sales metrics
    COUNT(DISTINCT order_id) AS orders_count,
    COUNT(order_item_id) AS items_sold,
    SUM(quantity) AS total_quantity_sold,
    SUM(line_total) AS total_revenue,
    
    -- Averages
    AVG(unit_price) AS avg_unit_price,
    AVG(quantity) AS avg_quantity_per_order,
    AVG(line_total) AS avg_line_total,
    
    -- Price analysis
    MIN(unit_price) AS min_unit_price,
    MAX(unit_price) AS max_unit_price,
    
    -- Category flags
    SUM(CASE WHEN is_skis THEN 1 ELSE 0 END) AS ski_items,
    SUM(CASE WHEN is_snowboards THEN 1 ELSE 0 END) AS snowboard_items,
    
    -- Quantity distribution
    COUNT(CASE WHEN quantity_tier = 'Single' THEN 1 END) AS single_item_orders,
    COUNT(CASE WHEN quantity_tier = 'Few' THEN 1 END) AS few_item_orders,
    COUNT(CASE WHEN quantity_tier = 'Bulk' THEN 1 END) AS bulk_orders
FROM AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES.FACT_ORDERS
GROUP BY product_category;

-- 3. Refresh first-tier Dynamic Tables to process new data
ALTER DYNAMIC TABLE AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES.ENRICHED_ORDERS REFRESH;
ALTER DYNAMIC TABLE AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES.ENRICHED_ORDER_ITEMS REFRESH;

-- 4. Recreate INTERACTIVE layer (can't truncate interactive tables)
DROP TABLE IF EXISTS AUTOMATED_INTELLIGENCE.INTERACTIVE.CUSTOMER_ORDER_ANALYTICS;
DROP TABLE IF EXISTS AUTOMATED_INTELLIGENCE.INTERACTIVE.ORDER_LOOKUP;

-- 4. Recreate INTERACTIVE layer (can't truncate interactive tables)
DROP TABLE IF EXISTS AUTOMATED_INTELLIGENCE.INTERACTIVE.CUSTOMER_ORDER_ANALYTICS;
DROP TABLE IF EXISTS AUTOMATED_INTELLIGENCE.INTERACTIVE.ORDER_LOOKUP;

-- Recreate CUSTOMER_ORDER_ANALYTICS (only show customers with orders)
CREATE OR REPLACE INTERACTIVE TABLE AUTOMATED_INTELLIGENCE.INTERACTIVE.CUSTOMER_ORDER_ANALYTICS
CLUSTER BY (customer_id)
AS
SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    c.customer_segment,
    COUNT(DISTINCT o.order_id) as total_orders,
    SUM(o.total_amount) as total_spent,
    AVG(o.total_amount) as avg_order_value,
    MAX(o.order_date) as last_order_date
FROM AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS c
INNER JOIN AUTOMATED_INTELLIGENCE.RAW.ORDERS o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.email, c.customer_segment;

-- Recreate ORDER_LOOKUP
CREATE OR REPLACE INTERACTIVE TABLE AUTOMATED_INTELLIGENCE.INTERACTIVE.ORDER_LOOKUP
CLUSTER BY (order_id)
AS
SELECT 
    o.order_id,
    o.customer_id,
    o.order_date,
    o.order_status,
    o.total_amount,
    c.first_name,
    c.last_name,
    c.email
FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS o
JOIN AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS c ON o.customer_id = c.customer_id;

-- Note: Downstream Dynamic Tables (FACT_ORDERS, DAILY_BUSINESS_METRICS, PRODUCT_PERFORMANCE_METRICS)
-- will automatically refresh once ENRICHED_ORDERS and ENRICHED_ORDER_ITEMS have fresh data

-- Note: CUSTOMERS table is NOT truncated as it contains reference data
-- that orders will link to via CUSTOMER_ID

SELECT 'Tables reset successfully. Dynamic Tables and Interactive tables recreated. Ready for new ingestion.' AS status;
