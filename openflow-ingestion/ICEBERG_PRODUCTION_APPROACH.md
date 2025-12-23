# Production Approach: Openflow → Staging → Iceberg

## Architecture

```
Openflow → PutSnowflake → staging.orders_staging (Native Table)
                              ↓
                      Snowflake TASK (every 1 min)
                              ↓
            INSERT INTO analytics_iceberg.orders (Iceberg Table)
```

## Why This Approach?

### ✅ Advantages
1. **No JDBC complexity** - Use native Snowflake connector
2. **Better performance** - Snowflake optimizes Iceberg writes
3. **Transactional** - TASK ensures consistency
4. **Easy monitoring** - Standard Snowflake observability
5. **Handles failures** - TASK retry mechanism
6. **Production-proven** - Recommended by Snowflake docs

### ❌ Direct JDBC to Iceberg Issues
1. **DNS/hostname resolution problems** (what we're hitting)
2. **Connection pool complexity**
3. **Limited error handling**
4. **No batch optimization**
5. **Hard to troubleshoot**

## Implementation

### Step 1: Create Staging Tables (Native Snowflake)

```sql
USE DATABASE automated_intelligence;
USE SCHEMA staging;

CREATE OR REPLACE TABLE orders_staging (
    order_id VARCHAR,
    customer_id VARCHAR,
    order_date TIMESTAMP_NTZ,
    total_amount NUMBER(10,2),
    status VARCHAR,
    _ingested_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE order_items_staging (
    order_item_id VARCHAR,
    order_id VARCHAR,
    product_id VARCHAR,
    quantity NUMBER,
    unit_price NUMBER(10,2),
    _ingested_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);
```

### Step 2: Openflow Flow (Use PutSnowflake - Native Connector)

**Current setup:**
- GenerateFlowFile → SplitJson → PutDatabaseRecord (JDBC) ❌

**New setup:**
- GenerateFlowFile → SplitJson → PutSnowflake (Native) ✅

**PutSnowflake Configuration:**
- Snowflake Connection Service: SnowflakeConnectionService_Native
- Database: AUTOMATED_INTELLIGENCE
- Schema: STAGING
- Table: orders_staging (or order_items_staging)
- Ingestion Method: SNOWPIPE_STREAMING or INSERT_SQL

### Step 3: Create TASK to Move Data to Iceberg

```sql
USE DATABASE automated_intelligence;
USE WAREHOUSE automated_intelligence_wh;

-- Task for orders
CREATE OR REPLACE TASK load_orders_to_iceberg
  WAREHOUSE = automated_intelligence_wh
  SCHEDULE = '1 MINUTE'
  WHEN SYSTEM$STREAM_HAS_DATA('orders_staging_stream')
AS
  INSERT INTO analytics_iceberg.orders
  SELECT 
    order_id,
    customer_id,
    order_date,
    total_amount,
    status
  FROM staging.orders_staging_stream
  WHERE METADATA$ACTION = 'INSERT';

-- Task for order_items
CREATE OR REPLACE TASK load_order_items_to_iceberg
  WAREHOUSE = automated_intelligence_wh
  SCHEDULE = '1 MINUTE'
  WHEN SYSTEM$STREAM_HAS_DATA('order_items_staging_stream')
AS
  INSERT INTO analytics_iceberg.order_items
  SELECT 
    order_item_id,
    order_id,
    product_id,
    quantity,
    unit_price
  FROM staging.order_items_staging_stream
  WHERE METADATA$ACTION = 'INSERT';

-- Start tasks
ALTER TASK load_orders_to_iceberg RESUME;
ALTER TASK load_order_items_to_iceberg RESUME;
```

### Step 4: Create Streams for Change Tracking

```sql
CREATE OR REPLACE STREAM orders_staging_stream
  ON TABLE staging.orders_staging;

CREATE OR REPLACE STREAM order_items_staging_stream
  ON TABLE staging.order_items_staging;
```

## Alternative: Use Dynamic Tables (Simpler)

Instead of TASKs + STREAMs, use Dynamic Tables (even simpler):

```sql
CREATE OR REPLACE DYNAMIC TABLE analytics_iceberg.orders
  TARGET_LAG = '1 minute'
  WAREHOUSE = automated_intelligence_wh
  AS
  SELECT 
    order_id,
    customer_id,
    order_date,
    total_amount,
    status
  FROM staging.orders_staging;
```

## Migration Plan

### Phase 1: Fix Current Openflow Setup
1. Delete DBCPConnectionPool service
2. Enable SnowflakeConnectionService_Native
3. Change PutDatabaseRecord → PutSnowflake processors
4. Point to staging.orders_staging / staging.order_items_staging

### Phase 2: Create Staging Tables
Run Step 1 SQL above

### Phase 3: Test Openflow → Staging
Verify data flows into staging tables

### Phase 4: Add Iceberg Layer
Choose either:
- Option A: TASKs + STREAMs (more control)
- Option B: Dynamic Tables (simpler)

### Phase 5: Validate
Query analytics_iceberg tables and verify data

## Monitoring

```sql
-- Check staging ingestion
SELECT COUNT(*), MAX(_ingested_at)
FROM staging.orders_staging;

-- Check Iceberg ingestion
SELECT COUNT(*), MAX(order_date)
FROM analytics_iceberg.orders;

-- Check TASK history
SELECT *
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE NAME = 'LOAD_ORDERS_TO_ICEBERG'
ORDER BY SCHEDULED_TIME DESC
LIMIT 10;

-- Check stream lag
SELECT SYSTEM$STREAM_HAS_DATA('orders_staging_stream');
```

## Cost Implications

- **Staging tables:** Minimal storage cost (short-lived data)
- **TASKs:** Warehouse compute only when running (1 min = ~$0.01-0.02/hour)
- **Iceberg tables:** No Snowflake storage cost (external)
- **Total:** Much cheaper than JDBC connection pool overhead

## Production Best Practices

1. **Set retention on staging tables:**
   ```sql
   ALTER TABLE staging.orders_staging 
   SET DATA_RETENTION_TIME_IN_DAYS = 1;
   ```

2. **Add error handling to TASKs:**
   ```sql
   -- Truncate staging after successful load
   CREATE OR REPLACE TASK cleanup_orders_staging
     WAREHOUSE = automated_intelligence_wh
     AFTER load_orders_to_iceberg
   AS
     DELETE FROM staging.orders_staging
     WHERE _ingested_at < DATEADD(hour, -1, CURRENT_TIMESTAMP());
   ```

3. **Monitor TASK failures:**
   ```sql
   ALTER TASK load_orders_to_iceberg 
   SET SUSPEND_TASK_AFTER_NUM_FAILURES = 3;
   ```

4. **Use MERGE for upserts** (if needed):
   ```sql
   MERGE INTO analytics_iceberg.orders t
   USING staging.orders_staging s
   ON t.order_id = s.order_id
   WHEN MATCHED THEN UPDATE SET ...
   WHEN NOT MATCHED THEN INSERT ...;
   ```

## Summary

**Current problematic approach:**
```
Openflow → PutDatabaseRecord (JDBC) → Iceberg (❌ DNS errors)
```

**Recommended production approach:**
```
Openflow → PutSnowflake (Native) → Staging → TASK → Iceberg (✅)
```

This is the **Snowflake-recommended pattern** for Iceberg ingestion with guaranteed reliability.
