-- ============================================================================
-- MERGE/UPDATE Procedures for Gen2 vs Gen1 Benchmarking
-- ============================================================================
-- These procedures implement the data transformation layer that moves data
-- from staging tables to raw (production) tables with deduplication and
-- enrichment. Designed to showcase Gen2 performance improvements.
-- ============================================================================

USE ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;
USE DATABASE AUTOMATED_INTELLIGENCE;
USE SCHEMA staging;

-- ============================================================================
-- PROCEDURE 1: MERGE Staging to Raw (with timing)
-- ============================================================================

CREATE OR REPLACE PROCEDURE merge_staging_to_raw(
    return_timing BOOLEAN DEFAULT TRUE
)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
DECLARE
    start_time TIMESTAMP_NTZ;
    end_time TIMESTAMP_NTZ;
    orders_merged INTEGER;
    order_items_merged INTEGER;
    orders_start TIMESTAMP_NTZ;
    orders_end TIMESTAMP_NTZ;
    items_start TIMESTAMP_NTZ;
    items_end TIMESTAMP_NTZ;
BEGIN
    start_time := CURRENT_TIMESTAMP();
    
    -- ========================================================================
    -- MERGE ORDERS (from staging to production)
    -- ========================================================================
    -- NOTE: We don't MERGE customers because:
    -- - Customers already exist in raw.customers
    -- - Orders reference existing customer_id values
    -- - Customer updates are handled separately (rare events)
    
    orders_start := CURRENT_TIMESTAMP();
    
    MERGE INTO raw.orders tgt
    USING (
        -- Deduplicate staging data (keep latest record per order_id)
        SELECT 
            order_id,
            customer_id,
            order_date,
            order_status,
            total_amount
        FROM (
            SELECT *,
                   ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY inserted_at DESC) as rn
            FROM staging.orders_staging
        )
        WHERE rn = 1
    ) src
    ON tgt.order_id = src.order_id
    WHEN MATCHED THEN UPDATE SET
        customer_id = src.customer_id,
        order_date = src.order_date,
        order_status = src.order_status,
        total_amount = src.total_amount
    WHEN NOT MATCHED THEN INSERT (
        order_id, customer_id, order_date, order_status, total_amount
    ) VALUES (
        src.order_id, src.customer_id, src.order_date, src.order_status,
        src.total_amount
    );
    
    orders_merged := SQLROWCOUNT;
    orders_end := CURRENT_TIMESTAMP();
    
    -- ========================================================================
    -- MERGE ORDER ITEMS
    -- ========================================================================
    items_start := CURRENT_TIMESTAMP();
    
    MERGE INTO raw.order_items tgt
    USING (
        -- Deduplicate staging data (keep latest record per order_item_id)
        SELECT 
            order_item_id,
            order_id,
            product_id,
            product_name,
            product_category,
            quantity,
            price as unit_price,
            line_total
        FROM (
            SELECT *,
                   ROW_NUMBER() OVER (PARTITION BY order_item_id ORDER BY inserted_at DESC) as rn
            FROM staging.order_items_staging
        )
        WHERE rn = 1
    ) src
    ON tgt.order_item_id = src.order_item_id
    WHEN MATCHED THEN UPDATE SET
        order_id = src.order_id,
        product_id = src.product_id,
        product_name = src.product_name,
        product_category = src.product_category,
        quantity = src.quantity,
        unit_price = src.unit_price,
        line_total = src.line_total
    WHEN NOT MATCHED THEN INSERT (
        order_item_id, order_id, product_id, product_name, product_category,
        quantity, unit_price, line_total
    ) VALUES (
        src.order_item_id, src.order_id, src.product_id, src.product_name,
        src.product_category, src.quantity, src.unit_price,
        src.line_total
    );
    
    order_items_merged := SQLROWCOUNT;
    items_end := CURRENT_TIMESTAMP();
    
    end_time := CURRENT_TIMESTAMP();
    
    -- Return timing results
    IF (return_timing) THEN
        RETURN OBJECT_CONSTRUCT(
            'total_duration_ms', DATEDIFF('millisecond', start_time, end_time),
            'orders', OBJECT_CONSTRUCT(
                'records_merged', orders_merged,
                'duration_ms', DATEDIFF('millisecond', orders_start, orders_end)
            ),
            'order_items', OBJECT_CONSTRUCT(
                'records_merged', order_items_merged,
                'duration_ms', DATEDIFF('millisecond', items_start, items_end)
            ),
            'start_time', start_time,
            'end_time', end_time
        );
    ELSE
        RETURN OBJECT_CONSTRUCT('status', 'success');
    END IF;
END;
$$;

-- ============================================================================
-- PROCEDURE 2: ENRICH Raw Data with UPDATE (with timing)
-- ============================================================================

CREATE OR REPLACE PROCEDURE enrich_raw_data(
    return_timing BOOLEAN DEFAULT TRUE
)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
DECLARE
    start_time TIMESTAMP_NTZ;
    end_time TIMESTAMP_NTZ;
    orders_updated INTEGER;
BEGIN
    start_time := CURRENT_TIMESTAMP();
    
    -- ========================================================================
    -- UPDATE: Apply discount adjustments for bulk orders
    -- ========================================================================
    -- This showcases UPDATE performance on Gen2 warehouses
    -- Apply additional discount for high-quantity orders
    UPDATE raw.orders
    SET discount_percent = CASE 
        WHEN total_amount >= 1000 THEN LEAST(discount_percent + 5.0, 50.0)
        WHEN total_amount >= 500 THEN LEAST(discount_percent + 2.5, 50.0)
        ELSE discount_percent
    END
    WHERE order_date >= DATEADD('day', -30, CURRENT_DATE())
      AND discount_percent < 50.0;
    
    orders_updated := SQLROWCOUNT;
    
    end_time := CURRENT_TIMESTAMP();
    
    -- Return timing results
    IF (return_timing) THEN
        RETURN OBJECT_CONSTRUCT(
            'orders_updated', orders_updated,
            'duration_ms', DATEDIFF('millisecond', start_time, end_time),
            'start_time', start_time,
            'end_time', end_time
        );
    ELSE
        RETURN OBJECT_CONSTRUCT('status', 'success');
    END IF;
END;
$$;

-- ============================================================================
-- PROCEDURE 3: Snapshot and Restore discount_percent for fair benchmarking
-- ============================================================================

-- Create regular table to store original discount values
CREATE TABLE IF NOT EXISTS staging.discount_snapshot (
    order_id INTEGER,
    discount_percent FLOAT
);

CREATE OR REPLACE PROCEDURE create_discount_snapshot()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    -- Clear any existing snapshot
    TRUNCATE TABLE staging.discount_snapshot;
    
    -- Store current discount_percent values for orders from last 30 days
    INSERT INTO staging.discount_snapshot
    SELECT order_id, discount_percent
    FROM raw.orders
    WHERE order_date >= DATEADD('day', -30, CURRENT_DATE());
    
    RETURN 'Discount snapshot created';
END;
$$;

CREATE OR REPLACE PROCEDURE restore_discount_snapshot()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    -- Restore discount_percent values from snapshot
    UPDATE raw.orders
    SET discount_percent = snapshot.discount_percent
    FROM staging.discount_snapshot snapshot
    WHERE raw.orders.order_id = snapshot.order_id;
    
    RETURN 'Discount values restored from snapshot';
END;
$$;

-- ============================================================================
-- PROCEDURE 4: Truncate Staging Tables (cleanup after successful MERGE)
-- ============================================================================

CREATE OR REPLACE PROCEDURE truncate_staging_tables()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    TRUNCATE TABLE staging.orders_staging;
    TRUNCATE TABLE staging.order_items_staging;
    
    RETURN 'Staging tables truncated successfully';
END;
$$;

-- ============================================================================
-- PROCEDURE 5: Get Staging Table Counts
-- ============================================================================

CREATE OR REPLACE PROCEDURE get_staging_counts()
RETURNS VARIANT
LANGUAGE SQL
AS
$$
DECLARE
    orders_count INTEGER;
    order_items_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO orders_count FROM staging.orders_staging;
    SELECT COUNT(*) INTO order_items_count FROM staging.order_items_staging;
    
    RETURN OBJECT_CONSTRUCT(
        'orders_staging', orders_count,
        'order_items_staging', order_items_count,
        'total_pending', orders_count + order_items_count
    );
END;
$$;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

SHOW PROCEDURES IN SCHEMA staging;

SELECT 
    'Procedures created successfully!' AS status,
    'merge_staging_to_raw - MERGE with deduplication' AS procedure1,
    'enrich_raw_data - UPDATE for business logic' AS procedure2,
    'truncate_staging_tables - Cleanup staging' AS procedure3,
    'get_staging_counts - Check pending records' AS procedure4;
