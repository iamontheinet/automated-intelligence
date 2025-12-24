-- ============================================================================
-- Automated Intelligence - Complete Setup Script
-- 
-- Execution Order:
--   1. Setup database, schemas, and warehouse
--   2. Create raw tables (customers, orders, order_items)
--   3. Create stored procedures for data generation
--   4. Create dynamic tables (3-tier pipeline)
--
-- Run this entire script to set up the complete demo environment
-- ============================================================================

USE ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;

-- ============================================================================
-- STEP 1: Setup Database, Schemas, and Warehouse
-- ============================================================================

-- Create database
CREATE DATABASE IF NOT EXISTS automated_intelligence;

-- Create schemas
CREATE SCHEMA IF NOT EXISTS automated_intelligence.raw;
CREATE SCHEMA IF NOT EXISTS automated_intelligence.dynamic_tables;
CREATE SCHEMA IF NOT EXISTS automated_intelligence.semantic;

-- Create warehouse
CREATE WAREHOUSE IF NOT EXISTS automated_intelligence_wh
  WITH WAREHOUSE_SIZE = 'SMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Warehouse for automated intelligence dynamic tables demo';

-- Set context
USE DATABASE automated_intelligence;
USE SCHEMA raw;
USE WAREHOUSE automated_intelligence_wh;


-- ============================================================================
-- STEP 2: Create Raw Tables
-- ============================================================================

-- Create customers table
CREATE OR REPLACE TABLE customers (
    customer_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    phone VARCHAR(20),
    address VARCHAR(200),
    city VARCHAR(50),
    state VARCHAR(2),
    zip_code VARCHAR(10),
    registration_date DATE,
    customer_segment VARCHAR(20)
);

-- Create orders table
-- Note: order_id uses VARCHAR to support UUID from Snowpipe Streaming
CREATE OR REPLACE TABLE orders (
    order_id VARCHAR(36) PRIMARY KEY,
    customer_id INT,
    order_date TIMESTAMP,
    order_status VARCHAR(20),
    total_amount DECIMAL(10, 2),
    discount_percent DECIMAL(5, 2),
    shipping_cost DECIMAL(8, 2)
);

-- Create order_items table
-- Note: order_item_id and order_id use VARCHAR to support UUID from Snowpipe Streaming
CREATE OR REPLACE TABLE order_items (
    order_item_id VARCHAR(36) PRIMARY KEY,
    order_id VARCHAR(36),
    product_id INT,
    product_name VARCHAR(100),
    product_category VARCHAR(50),
    quantity INT,
    unit_price DECIMAL(10, 2),
    line_total DECIMAL(12, 2)
);

-- ============================================================================
-- STEP 3: Create Stored Procedures
-- ============================================================================

-- Procedure: generate_orders
-- Purpose: Generate customers, orders, reviews, and support tickets for demo
-- Parameters: num_orders - Number of new orders to create
CREATE OR REPLACE PROCEDURE generate_orders(num_orders INT)
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    -- Get the next customer_id
    LET next_customer_id INT := (SELECT COALESCE(MAX(customer_id), 0) + 1 FROM customers);
    
    -- Insert new customers
    INSERT INTO customers
    SELECT
        :next_customer_id + ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS customer_id,
        CASE UNIFORM(1, 20, RANDOM())
            WHEN 1 THEN 'John' WHEN 2 THEN 'Sarah' WHEN 3 THEN 'Michael' WHEN 4 THEN 'Emily'
            WHEN 5 THEN 'David' WHEN 6 THEN 'Jessica' WHEN 7 THEN 'Chris' WHEN 8 THEN 'Ashley'
            WHEN 9 THEN 'Matt' WHEN 10 THEN 'Amanda' WHEN 11 THEN 'Ryan' WHEN 12 THEN 'Lauren'
            WHEN 13 THEN 'Kevin' WHEN 14 THEN 'Nicole' WHEN 15 THEN 'Brian' WHEN 16 THEN 'Rachel'
            WHEN 17 THEN 'Tyler' WHEN 18 THEN 'Megan' WHEN 19 THEN 'Josh' ELSE 'Katie'
        END AS first_name,
        CASE UNIFORM(1, 20, RANDOM())
            WHEN 1 THEN 'Smith' WHEN 2 THEN 'Johnson' WHEN 3 THEN 'Williams' WHEN 4 THEN 'Brown'
            WHEN 5 THEN 'Jones' WHEN 6 THEN 'Garcia' WHEN 7 THEN 'Miller' WHEN 8 THEN 'Davis'
            WHEN 9 THEN 'Rodriguez' WHEN 10 THEN 'Martinez' WHEN 11 THEN 'Hernandez' WHEN 12 THEN 'Lopez'
            WHEN 13 THEN 'Gonzalez' WHEN 14 THEN 'Wilson' WHEN 15 THEN 'Anderson' WHEN 16 THEN 'Thomas'
            WHEN 17 THEN 'Taylor' WHEN 18 THEN 'Moore' WHEN 19 THEN 'Jackson' ELSE 'Martin'
        END AS last_name,
        'customer' || (:next_customer_id + ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1) || '@email.com' AS email,
        '555-' || LPAD(UNIFORM(100, 999, RANDOM())::STRING, 3, '0') || '-' || LPAD(UNIFORM(1000, 9999, RANDOM())::STRING, 4, '0') AS phone,
        UNIFORM(100, 9999, RANDOM()) || ' ' || CASE UNIFORM(1, 10, RANDOM())
            WHEN 1 THEN 'Main St' WHEN 2 THEN 'Oak Ave' WHEN 3 THEN 'Maple Dr' 
            WHEN 4 THEN 'Cedar Ln' WHEN 5 THEN 'Pine Rd' WHEN 6 THEN 'Elm St'
            WHEN 7 THEN 'Washington Blvd' WHEN 8 THEN 'Lake View Dr' WHEN 9 THEN 'Mountain Way'
            ELSE 'Summit Trail'
        END AS address,
        CASE UNIFORM(1, 15, RANDOM())
            WHEN 1 THEN 'Denver' WHEN 2 THEN 'Salt Lake City' WHEN 3 THEN 'Boulder'
            WHEN 4 THEN 'Aspen' WHEN 5 THEN 'Park City' WHEN 6 THEN 'Jackson'
            WHEN 7 THEN 'Telluride' WHEN 8 THEN 'Steamboat Springs' WHEN 9 THEN 'Vail'
            WHEN 10 THEN 'Breckenridge' WHEN 11 THEN 'Mammoth Lakes' WHEN 12 THEN 'Tahoe City'
            WHEN 13 THEN 'Whistler' WHEN 14 THEN 'Banff' ELSE 'Portland'
        END AS city,
        CASE UNIFORM(1, 10, RANDOM())
            WHEN 1 THEN 'CO' WHEN 2 THEN 'UT' WHEN 3 THEN 'WY'
            WHEN 4 THEN 'CA' WHEN 5 THEN 'WA' WHEN 6 THEN 'OR'
            WHEN 7 THEN 'MT' WHEN 8 THEN 'ID' WHEN 9 THEN 'NV' ELSE 'BC'
        END AS state,
        LPAD(UNIFORM(10000, 99999, RANDOM())::STRING, 5, '0') AS zip_code,
        DATEADD(day, -UNIFORM(1, 1825, RANDOM()), CURRENT_DATE()) AS registration_date,
        CASE UNIFORM(1, 3, RANDOM())
            WHEN 1 THEN 'Premium'
            WHEN 2 THEN 'Standard'
            ELSE 'Basic'
        END AS customer_segment
    FROM TABLE(GENERATOR(ROWCOUNT => :num_orders));
    
    -- Insert new orders (one per customer) with UUID order_id
    INSERT INTO orders
    SELECT
        UUID_STRING() AS order_id,
        :next_customer_id + ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS customer_id,
        DATEADD(day, -UNIFORM(1, 365, RANDOM()), CURRENT_TIMESTAMP()) AS order_date,
        CASE UNIFORM(1, 5, RANDOM())
            WHEN 1 THEN 'Completed'
            WHEN 2 THEN 'Pending'
            WHEN 3 THEN 'Shipped'
            WHEN 4 THEN 'Cancelled'
            ELSE 'Processing'
        END AS order_status,
        ROUND(UNIFORM(10, 5000, RANDOM()), 2) AS total_amount,
        CASE WHEN UNIFORM(1, 10, RANDOM()) > 7 THEN UNIFORM(5, 25, RANDOM()) ELSE 0 END AS discount_percent,
        ROUND(UNIFORM(5, 50, RANDOM()), 2) AS shipping_cost
    FROM TABLE(GENERATOR(ROWCOUNT => :num_orders));
    
    -- Insert order items (1-10 items per new order) with UUID order_item_id
    INSERT INTO order_items
    WITH new_orders AS (
        -- Get the most recent orders (last num_orders)
        SELECT order_id, order_date
        FROM orders
        ORDER BY order_date DESC
        LIMIT :num_orders
    ),
    order_item_counts AS (
        SELECT
            order_id,
            UNIFORM(1, 10, RANDOM()) AS items_count
        FROM new_orders
    ),
    expanded_orders AS (
        SELECT
            o.order_id,
            ROW_NUMBER() OVER (PARTITION BY o.order_id ORDER BY RANDOM()) AS item_seq
        FROM order_item_counts o
        CROSS JOIN (
            SELECT SEQ4() AS item_num FROM TABLE(GENERATOR(ROWCOUNT => 10))
        ) numbers
        WHERE numbers.item_num < o.items_count
    ),
    product_mapping AS (
        SELECT 1 as product_num, 1001 as product_id, 'Powder Skis' as product_name, 'Skis' as product_category
        UNION ALL SELECT 2, 1002, 'All-Mountain Skis', 'Skis'
        UNION ALL SELECT 3, 1003, 'Freestyle Snowboard', 'Snowboards'
        UNION ALL SELECT 4, 1004, 'Freeride Snowboard', 'Snowboards'
        UNION ALL SELECT 5, 1005, 'Ski Boots', 'Boots'
        UNION ALL SELECT 6, 1006, 'Snowboard Boots', 'Boots'
        UNION ALL SELECT 7, 1007, 'Ski Poles', 'Accessories'
        UNION ALL SELECT 8, 1008, 'Ski Goggles', 'Accessories'
        UNION ALL SELECT 9, 1009, 'Snowboard Bindings', 'Accessories'
        UNION ALL SELECT 10, 1010, 'Ski Helmet', 'Accessories'
    )
    SELECT
        UUID_STRING() AS order_item_id,
        eo.order_id,
        pm.product_id,
        pm.product_name,
        pm.product_category,
        UNIFORM(1, 5, RANDOM()) AS quantity,
        ROUND(UNIFORM(10, 500, RANDOM()), 2) AS unit_price,
        ROUND(UNIFORM(1, 5, RANDOM()) * UNIFORM(10, 500, RANDOM()), 2) AS line_total
    FROM expanded_orders eo
    CROSS JOIN product_mapping pm
    WHERE pm.product_num = UNIFORM(1, 10, RANDOM());
    
    -- Insert product reviews (10% of customers leave reviews for products they actually purchased)
    INSERT INTO product_reviews (product_id, customer_id, review_date, rating, review_title, review_text, verified_purchase)
    SELECT
        oi.product_id,
        o.customer_id,
        DATEADD(day, UNIFORM(1, 30, RANDOM()), o.order_date) AS review_date,
        UNIFORM(3, 5, RANDOM()) AS rating,
        CASE UNIFORM(1, 10, RANDOM())
            WHEN 1 THEN 'Excellent quality and performance'
            WHEN 2 THEN 'Highly recommend this product'
            WHEN 3 THEN 'Great value for the price'
            WHEN 4 THEN 'Perfect for my needs'
            WHEN 5 THEN 'Outstanding product'
            WHEN 6 THEN 'Very satisfied with purchase'
            WHEN 7 THEN 'Good but has some limitations'
            WHEN 8 THEN 'Solid performance overall'
            WHEN 9 THEN 'Meets expectations'
            ELSE 'Decent product with minor issues'
        END AS review_title,
        'I recently purchased this product and have been using it extensively over the past few weeks. Overall, I am quite satisfied with my purchase. The build quality is solid and the materials feel premium. Performance has been consistent across various conditions. The product arrived well packaged and exactly as described on the website. Setup was straightforward and I was able to start using it immediately without any complications. The attention to detail in the design is evident and shows that the manufacturer cares about creating a quality product. I particularly appreciate how well it performs in challenging conditions. The ergonomics are well thought out and it feels comfortable during extended use. After several weeks of regular use, I have noticed no significant wear or degradation in performance. The product maintains its original quality and continues to meet my expectations. Customer service was responsive when I had questions before purchasing. Shipping was prompt and the item arrived within the estimated delivery window. The price point is reasonable considering the quality and features offered. I have recommended this product to friends who were looking for similar equipment. While no product is perfect, this one comes close to meeting all my needs. There are minor areas where improvements could be made, but they do not significantly impact the overall experience. The functionality is solid and reliable. I feel confident that this product will continue to perform well over time. For anyone considering this purchase, I would say it is worth the investment if it matches your specific requirements and use case. Do your research and make sure it aligns with what you are looking for, but if it does, you will likely be pleased with the purchase.' AS review_text,
        TRUE AS verified_purchase
    FROM orders o
    INNER JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_id >= :next_order_id
        AND o.order_status = 'Completed'
        AND UNIFORM(1, 10, RANDOM()) = 1;
    
    -- Insert support tickets (5% of customers create tickets)
    INSERT INTO support_tickets (customer_id, ticket_date, category, priority, subject, description, resolution, status)
    SELECT
        customer_id,
        DATEADD(day, UNIFORM(1, 60, RANDOM()), order_date) AS ticket_date,
        CASE UNIFORM(1, 5, RANDOM())
            WHEN 1 THEN 'Product Issue'
            WHEN 2 THEN 'Shipping'
            WHEN 3 THEN 'Returns'
            WHEN 4 THEN 'Product Question'
            ELSE 'Technical Support'
        END AS category,
        CASE UNIFORM(1, 3, RANDOM())
            WHEN 1 THEN 'High'
            WHEN 2 THEN 'Medium'
            ELSE 'Low'
        END AS priority,
        CASE UNIFORM(1, 10, RANDOM())
            WHEN 1 THEN 'Question about product compatibility'
            WHEN 2 THEN 'Order status inquiry'
            WHEN 3 THEN 'Return or exchange request'
            WHEN 4 THEN 'Product sizing question'
            WHEN 5 THEN 'Warranty information needed'
            WHEN 6 THEN 'Damaged item received'
            WHEN 7 THEN 'Missing parts or accessories'
            WHEN 8 THEN 'Installation instructions needed'
            WHEN 9 THEN 'Performance issue with product'
            ELSE 'General product question'
        END AS subject,
        'Hello, I am reaching out regarding my recent purchase and I hope you can help me with a question that has come up. I have been a customer for some time now and generally have positive experiences with your products and services. However, I have encountered a situation that requires some clarification or assistance. Let me provide some context and background information so you have a complete understanding of my inquiry. I placed my order several weeks ago and received it in good condition. The packaging was intact and everything appeared to be as expected based on the product description on your website. Initially, everything seemed fine and I was pleased with the purchase. However, after using the product for a period of time, I have noticed some things that I would like to discuss or get your expert opinion on. I want to make sure I am using the product correctly and getting the most out of my purchase. I have done some research online and read through the documentation that came with the product, but I still have some questions that I could not find clear answers to. I am hoping your customer support team can provide some guidance or recommendations based on your expertise and experience with this product line. I understand that every customer situation is unique and that you deal with a wide variety of questions and concerns. I appreciate your patience in working with me to resolve this matter. I value the quality of your products and would like to continue being a customer in the future. My hope is that we can work together to address this situation in a way that is satisfactory for everyone involved. Please let me know what additional information you might need from me to help address my concern. I am happy to provide photos, order numbers, or any other details that would be helpful. Thank you for taking the time to read this message and for your attention to customer satisfaction. I look forward to hearing back from you at your earliest convenience.' AS description,
        CASE UNIFORM(1, 3, RANDOM())
            WHEN 1 THEN 'Issue resolved with customer satisfaction'
            WHEN 2 THEN 'Provided detailed guidance and instructions'
            ELSE 'Offered replacement or refund as appropriate'
        END AS resolution,
        CASE UNIFORM(1, 3, RANDOM())
            WHEN 1 THEN 'Closed'
            WHEN 2 THEN 'Open'
            ELSE 'Pending'
        END AS status
    FROM orders
    WHERE order_id >= :next_order_id
        AND UNIFORM(1, 20, RANDOM()) = 1;
    
    RETURN 'Successfully generated ' || :num_orders || ' orders with customers, reviews, and support tickets';
END;
$$;

-- Verify procedure created
SHOW PROCEDURES LIKE 'generate_orders';


-- ============================================================================
-- STEP 4: Create Dynamic Tables (3-Tier Pipeline)
-- ============================================================================

USE SCHEMA automated_intelligence.dynamic_tables;
USE WAREHOUSE automated_intelligence_wh;

-- Drop existing dynamic tables to avoid schema conflicts when updating
DROP DYNAMIC TABLE IF EXISTS product_performance_metrics;
DROP DYNAMIC TABLE IF EXISTS daily_business_metrics;
DROP DYNAMIC TABLE IF EXISTS fact_orders;
DROP DYNAMIC TABLE IF EXISTS enriched_order_items;
DROP DYNAMIC TABLE IF EXISTS enriched_orders;

-- ----------------------------------------------------------------------------
-- TIER 1: Enrichment Layer
-- Purpose: Add temporal dimensions and calculated fields to raw data
-- Target Lag: 12 hours (time-based scheduling)
-- Refresh Mode: INCREMENTAL
-- ----------------------------------------------------------------------------

-- Enriched Orders: Add temporal dimensions and financial calculations
-- TARGET_LAG = '1 minute' for near real-time analytics (matches Snowpipe Streaming latency)
CREATE OR REPLACE DYNAMIC TABLE enriched_orders
TARGET_LAG = '1 minute'
WAREHOUSE = automated_intelligence_wh
REFRESH_MODE = INCREMENTAL
AS
SELECT
    o.order_id,
    o.customer_id,
    o.order_date,
    o.order_status,
    
    -- Temporal dimensions
    DATE(o.order_date) AS order_date_only,
    YEAR(o.order_date) AS order_year,
    QUARTER(o.order_date) AS order_quarter,
    MONTH(o.order_date) AS order_month,
    DAYOFWEEK(o.order_date) AS order_day_of_week,
    DAYNAME(o.order_date) AS order_day_name,
    WEEK(o.order_date) AS order_week,
    
    -- Financial calculations
    o.total_amount,
    o.discount_percent,
    o.shipping_cost,
    ROUND(o.total_amount * (o.discount_percent / 100), 2) AS discount_amount,
    ROUND(o.total_amount - (o.total_amount * (o.discount_percent / 100)), 2) AS net_amount,
    ROUND(o.total_amount - (o.total_amount * (o.discount_percent / 100)) + o.shipping_cost, 2) AS final_amount,
    
    -- Discount flags
    CASE WHEN o.discount_percent > 0 THEN TRUE ELSE FALSE END AS has_discount,
    CASE 
        WHEN o.discount_percent = 0 THEN 'No Discount'
        WHEN o.discount_percent <= 10 THEN 'Low Discount'
        WHEN o.discount_percent <= 20 THEN 'Medium Discount'
        ELSE 'High Discount'
    END AS discount_tier,
    
    -- Order size
    CASE
        WHEN o.total_amount < 100 THEN 'Small'
        WHEN o.total_amount < 500 THEN 'Medium'
        WHEN o.total_amount < 2000 THEN 'Large'
        ELSE 'Extra Large'
    END AS order_size_category
FROM automated_intelligence.raw.orders o;

-- Enriched Order Items: Add price analysis and category flags
-- TARGET_LAG = '1 minute' for near real-time analytics (matches Snowpipe Streaming latency)
CREATE OR REPLACE DYNAMIC TABLE enriched_order_items
TARGET_LAG = '1 minute'
WAREHOUSE = automated_intelligence_wh
REFRESH_MODE = INCREMENTAL
AS
SELECT
    oi.order_item_id,
    oi.order_id,
    oi.product_id,
    oi.product_name,
    oi.product_category,
    oi.quantity,
    oi.unit_price,
    oi.line_total,
    
    -- Price analysis
    ROUND(oi.line_total / oi.quantity, 2) AS actual_unit_price,
    ROUND(oi.unit_price - (oi.line_total / oi.quantity), 2) AS unit_price_variance,
    
    -- Category flags
    CASE WHEN oi.product_category = 'Skis' THEN TRUE ELSE FALSE END AS is_skis,
    CASE WHEN oi.product_category = 'Snowboards' THEN TRUE ELSE FALSE END AS is_snowboards,
    
    -- Quantity tiers
    CASE
        WHEN oi.quantity = 1 THEN 'Single'
        WHEN oi.quantity <= 3 THEN 'Few'
        ELSE 'Bulk'
    END AS quantity_tier
FROM automated_intelligence.raw.order_items oi;

-- ----------------------------------------------------------------------------
-- TIER 2: Integration Layer
-- Purpose: Join enriched tables to create denormalized fact table
-- Target Lag: DOWNSTREAM (waits for Tier 1 to complete)
-- Refresh Mode: INCREMENTAL
-- ----------------------------------------------------------------------------

CREATE OR REPLACE DYNAMIC TABLE fact_orders
TARGET_LAG = DOWNSTREAM
WAREHOUSE = automated_intelligence_wh
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
FROM automated_intelligence.dynamic_tables.enriched_orders eo
INNER JOIN automated_intelligence.dynamic_tables.enriched_order_items eoi
    ON eo.order_id = eoi.order_id;

-- ----------------------------------------------------------------------------
-- TIER 3: Aggregation Layer
-- Purpose: Pre-compute business metrics for instant query performance
-- Target Lag: DOWNSTREAM (waits for Tier 2 to complete)
-- Refresh Mode: INCREMENTAL
-- ----------------------------------------------------------------------------

-- Daily Business Metrics: Daily aggregations of key business metrics
CREATE OR REPLACE DYNAMIC TABLE daily_business_metrics
TARGET_LAG = DOWNSTREAM
WAREHOUSE = automated_intelligence_wh
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
FROM automated_intelligence.dynamic_tables.fact_orders
GROUP BY 
    order_date_only,
    order_year,
    order_quarter,
    order_month,
    order_week,
    order_day_name;

-- Product Performance Metrics: Product category aggregations
CREATE OR REPLACE DYNAMIC TABLE product_performance_metrics
TARGET_LAG = DOWNSTREAM
WAREHOUSE = automated_intelligence_wh
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
FROM automated_intelligence.dynamic_tables.fact_orders
GROUP BY product_category;


-- ============================================================================
-- STEP 5: Setup Data Quality Monitoring with DMFs
-- ============================================================================

USE SCHEMA automated_intelligence.raw;

-- Set DMF schedule to trigger on data changes
ALTER TABLE orders SET DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES';
ALTER TABLE order_items SET DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES';

-- Add NULL_COUNT DMFs to orders table
ALTER TABLE orders ADD DATA METRIC FUNCTION 
  SNOWFLAKE.CORE.NULL_COUNT ON (order_id),
  SNOWFLAKE.CORE.NULL_COUNT ON (customer_id),
  SNOWFLAKE.CORE.NULL_COUNT ON (order_date),
  SNOWFLAKE.CORE.NULL_COUNT ON (total_amount);

-- Add NULL_COUNT DMFs to order_items table
ALTER TABLE order_items ADD DATA METRIC FUNCTION 
  SNOWFLAKE.CORE.NULL_COUNT ON (order_item_id),
  SNOWFLAKE.CORE.NULL_COUNT ON (order_id),
  SNOWFLAKE.CORE.NULL_COUNT ON (product_id),
  SNOWFLAKE.CORE.NULL_COUNT ON (quantity),
  SNOWFLAKE.CORE.NULL_COUNT ON (unit_price);

-- Create view for DMF results (wraps table functions)
-- Note: SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS view may not exist in all accounts
-- This custom view uses the table function approach which works universally
CREATE OR REPLACE VIEW vw_dq_monitoring_results AS
SELECT * FROM TABLE(
  SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS(
    REF_ENTITY_NAME => 'automated_intelligence.raw.orders',
    REF_ENTITY_DOMAIN => 'table'
  )
)
UNION ALL
SELECT * FROM TABLE(
  SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS(
    REF_ENTITY_NAME => 'automated_intelligence.raw.order_items',
    REF_ENTITY_DOMAIN => 'table'
  )
);

-- Create alert tracking table
CREATE TABLE IF NOT EXISTS data_quality_alerts (
  alert_time TIMESTAMP_NTZ,
  issue_summary VARCHAR,
  PRIMARY KEY (alert_time)
);

-- Create alert to monitor data quality issues
CREATE OR REPLACE ALERT data_quality_alert
  WAREHOUSE = automated_intelligence_wh
  SCHEDULE = '5 MINUTE'
  IF (EXISTS (
    SELECT 1
    FROM vw_dq_monitoring_results
    WHERE 
      table_database = 'AUTOMATED_INTELLIGENCE'
      AND table_schema = 'RAW'
      AND table_name IN ('ORDERS', 'ORDER_ITEMS')
      AND metric_name = 'NULL_COUNT'
      AND value::INT > 0
      AND measurement_time >= DATEADD('MINUTE', -10, CURRENT_TIMESTAMP())
  ))
  THEN
    INSERT INTO data_quality_alerts (alert_time, issue_summary)
    SELECT 
      CURRENT_TIMESTAMP(),
      'Data Quality Issue: NULL values detected - check vw_dq_monitoring_results for details';

-- Resume alert (start monitoring)
ALTER ALERT data_quality_alert RESUME;


-- ============================================================================
-- STEP 6: Create Unstructured Data Tables for AI/SQL Functions
-- ============================================================================

USE SCHEMA automated_intelligence.raw;
USE WAREHOUSE automated_intelligence_wh;

-- Product catalog with descriptions for semantic search
CREATE TABLE IF NOT EXISTS product_catalog (
  product_id INT PRIMARY KEY,
  product_name VARCHAR(100),
  product_category VARCHAR(50),
  description TEXT,
  features TEXT,
  price DECIMAL(10,2),
  stock_quantity INT
);

-- Customer reviews for sentiment analysis and AI_AGG
CREATE TABLE IF NOT EXISTS product_reviews (
  review_id INT AUTOINCREMENT PRIMARY KEY,
  product_id INT,
  customer_id INT,
  review_date DATE,
  rating INT,
  review_title VARCHAR(200),
  review_text TEXT,
  verified_purchase BOOLEAN
);

-- Customer support tickets for AI_COMPLETE and classification
CREATE TABLE IF NOT EXISTS support_tickets (
  ticket_id INT AUTOINCREMENT PRIMARY KEY,
  customer_id INT,
  ticket_date TIMESTAMP_NTZ,
  category VARCHAR(50),
  priority VARCHAR(20),
  subject VARCHAR(200),
  description TEXT,
  resolution TEXT,
  status VARCHAR(20)
);

-- Insert sample product catalog data (use MERGE to prevent duplicates)
MERGE INTO product_catalog t
USING (
  SELECT * FROM (VALUES
  (1001, 'Powder Skis', 'Skis', 'Premium powder skis designed for deep snow conditions. Featuring a wide waist and rockered tip for effortless floating in backcountry powder.', 'Wide waist (115mm), Rockered tip and tail, Carbon fiber construction, Lightweight design', 799.99, 15),
  (1002, 'All-Mountain Skis', 'Skis', 'Versatile all-mountain skis perfect for any terrain. Handles groomed runs, powder, and moguls with equal confidence.', 'Medium waist (88mm), Progressive sidecut, Titanal reinforcement, Durable construction', 649.99, 25),
  (1003, 'Freestyle Snowboard', 'Snowboards', 'Twin-tip freestyle snowboard for park and pipe. Perfect for tricks, jumps, and jibbing with a soft, playful flex.', 'True twin shape, Soft flex rating, Sintered base, Pop-optimized core', 549.99, 20),
  (1004, 'Freeride Snowboard', 'Snowboards', 'Directional freeride snowboard for charging hard in variable conditions. Stiff and stable for high-speed descents.', 'Directional shape, Stiff flex, Carbon stringers, Powder-friendly nose', 699.99, 12),
  (1005, 'Ski Boots', 'Boots', 'High-performance alpine ski boots with customizable fit. Four-buckle design with walk mode for comfort and power transmission.', '130 flex rating, GripWalk soles, Heat-moldable liner, Walk mode', 449.99, 30),
  (1006, 'Snowboard Boots', 'Boots', 'Comfortable snowboard boots with Boa lacing system. Quick entry and perfect fit adjustment for all-day riding.', 'Boa lacing system, Medium flex, Heat-moldable liner, Vibram outsole', 349.99, 35),
  (1007, 'Ski Poles', 'Accessories', 'Lightweight aluminum ski poles with ergonomic grips. Adjustable length for different terrain and snow conditions.', 'Aluminum construction, Adjustable length (105-135cm), Powder baskets, Padded straps', 79.99, 50),
  (1008, 'Ski Goggles', 'Accessories', 'Anti-fog ski goggles with interchangeable lenses. Superior optics and peripheral vision for all weather conditions.', 'Anti-fog coating, UV protection, Interchangeable lenses, Helmet compatible', 149.99, 40),
  (1009, 'Snowboard Bindings', 'Accessories', 'Responsive snowboard bindings with tool-free adjustment. Lightweight and compatible with all mounting systems.', 'Tool-free adjustment, Canted footbeds, Universal disk, Highback rotation', 249.99, 28),
  (1010, 'Ski Helmet', 'Accessories', 'Safety-certified ski helmet with integrated audio system. Lightweight construction with adjustable ventilation.', 'MIPS protection, Audio-ready, Adjustable vents, Goggle clip, Multiple sizes', 179.99, 45)
  ) AS s(product_id, product_name, product_category, description, features, price, stock_quantity)
) s
ON t.product_id = s.product_id
WHEN MATCHED THEN
  UPDATE SET
    product_name = s.product_name,
    product_category = s.product_category,
    description = s.description,
    features = s.features,
    price = s.price,
    stock_quantity = s.stock_quantity
WHEN NOT MATCHED THEN
  INSERT (product_id, product_name, product_category, description, features, price, stock_quantity)
  VALUES (s.product_id, s.product_name, s.product_category, s.description, s.features, s.price, s.stock_quantity);

-- Product reviews and support tickets are generated dynamically by the generate_orders() stored procedure
-- No static inserts needed here

-- ============================================================================
-- STEP 7: Create Cortex Search Service for Product Catalog
-- ============================================================================

-- Enable change tracking on product catalog for Cortex Search
ALTER TABLE product_catalog SET CHANGE_TRACKING = TRUE;

-- Create Cortex Search Service for semantic search over product descriptions
CREATE OR REPLACE CORTEX SEARCH SERVICE product_search_service
  ON description
  ATTRIBUTES product_name, product_category, features, price
  WAREHOUSE = automated_intelligence_wh
  TARGET_LAG = '1 hour'
  AS (
    SELECT
      product_id,
      product_name,
      product_category,
      description,
      features,
      price,
      stock_quantity
    FROM product_catalog
  );

-- Verify Cortex Search Service
SHOW CORTEX SEARCH SERVICES IN SCHEMA automated_intelligence.raw;


-- ============================================================================
-- Setup Complete!
-- 
-- Next Steps:
--   1. Load initial data using generate_initial_data.sql
--   2. Run demos using dynamic_tables_demo.ipynb (recommended) or SQL scripts
--   3. See README.md for demo options and instructions
--
-- Data Quality Monitoring:
--   - DMFs monitor orders and order_items tables for NULL values
--   - Alert checks every 5 minutes and logs issues to data_quality_alerts table
--   - DMFs trigger automatically on INSERT, UPDATE, DELETE operations
-- ============================================================================

TRUNCATE TABLE IF EXISTS automated_intelligence.raw.customers;
TRUNCATE TABLE IF EXISTS automated_intelligence.raw.orders;
TRUNCATE TABLE IF EXISTS automated_intelligence.raw.order_items;
TRUNCATE TABLE IF EXISTS automated_intelligence.raw.data_quality_alerts;

ALTER DYNAMIC TABLE automated_intelligence.dynamic_tables.enriched_orders REFRESH;
ALTER DYNAMIC TABLE automated_intelligence.dynamic_tables.enriched_order_items REFRESH;
ALTER DYNAMIC TABLE automated_intelligence.dynamic_tables.fact_orders REFRESH;
ALTER DYNAMIC TABLE automated_intelligence.dynamic_tables.daily_business_metrics REFRESH;
ALTER DYNAMIC TABLE automated_intelligence.dynamic_tables.product_performance_metrics REFRESH;

SELECT 'Raw Tables' AS category, 'customers' AS table_name, COUNT(*) AS row_count 
FROM automated_intelligence.raw.customers
UNION ALL
SELECT 'Raw Tables', 'orders', COUNT(*) 
FROM automated_intelligence.raw.orders
UNION ALL
SELECT 'Raw Tables', 'order_items', COUNT(*) 
FROM automated_intelligence.raw.order_items
UNION ALL
SELECT 'Raw Tables', 'data_quality_alerts', COUNT(*) 
FROM automated_intelligence.raw.data_quality_alerts
UNION ALL
SELECT 'Dynamic Tables', 'enriched_orders', COUNT(*) 
FROM automated_intelligence.dynamic_tables.enriched_orders
UNION ALL
SELECT 'Dynamic Tables', 'enriched_order_items', COUNT(*) 
FROM automated_intelligence.dynamic_tables.enriched_order_items
UNION ALL
SELECT 'Dynamic Tables', 'fact_orders', COUNT(*) 
FROM automated_intelligence.dynamic_tables.fact_orders
UNION ALL
SELECT 'Dynamic Tables', 'daily_business_metrics', COUNT(*) 
FROM automated_intelligence.dynamic_tables.daily_business_metrics
UNION ALL
SELECT 'Dynamic Tables', 'product_performance_metrics', COUNT(*) 
FROM automated_intelligence.dynamic_tables.product_performance_metrics
ORDER BY category, table_name;

-- ============================================================================
-- Create Stage for Semantic Model Storage
-- ============================================================================
-- This stage stores semantic model YAML files used by Cortex Analyst
-- for natural language to SQL translation.

CREATE STAGE IF NOT EXISTS automated_intelligence.raw.semantic_models
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for storing semantic model YAML files for Cortex Analyst';

SHOW STAGES LIKE 'semantic_models' IN automated_intelligence.raw;

-- Insert new orders
SET NEW_ORDERS = 10000;
CALL automated_intelligence.raw.generate_orders($NEW_ORDERS);
