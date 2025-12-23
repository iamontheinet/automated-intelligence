# Openflow → Iceberg Integration

## Status: ✅ 100% COMPLETE - Ready for Testing

This folder contains a complete implementation for ingesting data into **Apache Iceberg tables** using **Snowflake Openflow** (Apache NiFi). This creates a **hybrid architecture** where operational data flows through Snowpipe Streaming to native tables, while analytics data flows through Openflow to open-format Iceberg tables.

---

## Architecture

```
OPERATIONAL TIER (Real-time, Native Snowflake)
────────────────────────────────────────────────
Snowpipe Streaming SDK → staging → raw.orders (native)
[SUB-SECOND LATENCY, 100K+ rows/sec]

ANALYTICS TIER (Open Format, Multi-Tool Access)
────────────────────────────────────────────────
Openflow Data Generator → analytics_iceberg.orders (Iceberg)
    ↓
┌───┴────┬──────────┬──────────┐
Snowflake  Spark  Databricks  Trino
[OPEN FORMAT, NO SF STORAGE COST]
```

---

## Quick Start (5 minutes to test)

### Prerequisites ✅ COMPLETE
All setup steps completed! You have:
- ✅ External volume `aws_s3_ext_volume_snowflake` configured and tested
- ✅ Iceberg tables created in `automated_intelligence.analytics_iceberg`
- ✅ Openflow pipeline created with 6 processors + 3 controller services

### Test the Pipeline (5 min)

1. **Start the flow in Openflow UI:**
   ```
   https://of--sfsenorthamerica-gen-ai-hol.snowflakecomputing.app/dashing/nifi/?processGroupId=0a9f1d18-019b-1000-0000-000034cc7230
   ```
   - Right-click process group background → Start
   - OR manually start each processor (GenerateFlowFile → ExecuteScript → SplitJson → PutDatabaseRecord)

2. **Verify data is flowing:**
   ```sql
   SELECT COUNT(*) FROM automated_intelligence.analytics_iceberg.orders;
   SELECT COUNT(*) FROM automated_intelligence.analytics_iceberg.order_items;
   
   -- Should see new rows every 10 seconds
   ```

3. **Check S3 files created:**
   ```sql
   SELECT table_name, COUNT(*) AS file_count, 
          SUM(file_size_bytes)/(1024*1024) AS total_mb
   FROM automated_intelligence.information_schema.iceberg_table_files
   WHERE table_schema = 'ANALYTICS_ICEBERG'
   GROUP BY table_name;
   ```

---

## What Was Automated (for reference)

### 1. External Volume ✅ COMPLETE
External volume `aws_s3_ext_volume_snowflake` already configured and tested.  
See `01_external_volume_reference.sql` for reference.

### 2. Create Iceberg Tables ✅ COMPLETE
Executed: `02_create_iceberg_tables.sql`

Created:
- Schema: `automated_intelligence.analytics_iceberg`
- Table: `orders` → S3: `ai/orders/`
- Table: `order_items` → S3: `ai/order_items/`

### 3. Create Openflow Pipeline ✅ COMPLETE
Executed: `03_complete_openflow_flow.sh` + `04_add_putdatabaserecord.sh`

Created:
- **Processors:**
  - GenerateFlowFile (ID: 13a83a8c-019b-1000-0000-00007d4f39b6) - Triggers every 10 seconds
  - ExecuteScript (ID: 13a83e9c-019b-1000-ffff-ffffcc2cea4c) - Generates 100 orders + items as JSON
  - SplitJson (Orders) (ID: 13b30fc0-019b-1000-ffff-ffffb99bb7ec) - Splits orders array
  - SplitJson (Order Items) (ID: 13b311cc-019b-1000-0000-00004c223a2f) - Splits order_items array
  - PutDatabaseRecord (Orders) (ID: 13b313a1-019b-1000-0000-00001de9bb39) - Inserts to Iceberg
  - PutDatabaseRecord (Order Items) (ID: 13b316fb-019b-1000-0000-000079b848f8) - Inserts to Iceberg

- **Controller Services:**
  - SnowflakeConnectionPool (ID: 13b2ec3d-019b-1000-ffff-ffffe8649370) - JDBC connection
  - JsonTreeReader (ID: 13b30762-019b-1000-ffff-ffffea3bef7f) - Reads JSON records
  - JsonRecordSetWriter (ID: 13b2feb3-019b-1000-ffff-ffffcf8c30d9) - Writes JSON records

**Data Flow:**
```
GenerateFlowFile → ExecuteScript → SplitJson → PutDatabaseRecord → Iceberg Tables → S3
   (trigger)      (generate JSON)   (split)      (JDBC INSERT)      (Parquet files)
```

---

## Files

### Setup Scripts (completed, for reference)
1. `01_external_volume_reference.sql` - Reference for external volume ✅
2. `02_create_iceberg_tables.sql` - Creates Iceberg schema and tables ✅
3. `03_complete_openflow_flow.sh` - Creates Openflow data generator processors ✅
4. `04_add_putdatabaserecord.sh` - Creates SplitJson + PutDatabaseRecord processors ✅

### Documentation
- `ICEBERG_CONFIGURATION.md` - **Verified config** - External volume, base locations, validation queries
- `KEY_PAIR_SETUP.md` - RSA key authentication setup
- `CONFIGURATION_REFERENCE.md` - Processor configuration reference
- `ROLE_REQUIREMENTS.md` - Snowflake role requirements

---

## Demo Scenarios

### Compare Native vs Iceberg
```sql
SELECT 'Native (Snowpipe)' AS source, COUNT(*) FROM automated_intelligence.raw.orders
UNION ALL
SELECT 'Iceberg (Openflow)', COUNT(*) FROM automated_intelligence.analytics_iceberg.orders;
```

### Time Travel
```sql
SELECT COUNT(*) FROM automated_intelligence.analytics_iceberg.orders
AT(TIMESTAMP => DATEADD('hour', -1, CURRENT_TIMESTAMP()));
```

### Storage Cost
```sql
SELECT 
    table_name,
    CASE WHEN is_iceberg = 'YES' THEN 'Iceberg (No SF Cost)' 
         ELSE 'Native (SF Billed)' END AS storage_type,
    active_bytes / (1024*1024*1024) AS active_gb
FROM automated_intelligence.information_schema.table_storage_metrics
WHERE table_schema IN ('RAW', 'ANALYTICS_ICEBERG');
```

---

## Monitoring

```sql
-- Check Iceberg tables
SHOW ICEBERG TABLES IN automated_intelligence.analytics_iceberg;

-- View snapshots (time travel)
SELECT * FROM automated_intelligence.information_schema.iceberg_table_snapshots
WHERE table_schema = 'ANALYTICS_ICEBERG'
ORDER BY committed_at DESC;

-- Check file metrics
SELECT 
    table_name,
    COUNT(*) AS file_count,
    SUM(file_size_bytes) / (1024*1024*1024) AS total_gb
FROM automated_intelligence.information_schema.iceberg_table_files
WHERE table_schema = 'ANALYTICS_ICEBERG'
GROUP BY table_name;

-- Openflow logs
SELECT TIMESTAMP, VALUE
FROM OPENFLOW.TELEMETRY.EVENTS
WHERE TIMESTAMP >= DATEADD(minute, -10, CURRENT_TIMESTAMP())
  AND RESOURCE_ATTRIBUTES:"k8s.namespace.name"::STRING = 'runtime-dashing'
ORDER BY TIMESTAMP DESC;
```

---

## Troubleshooting

### External Volume Issues
```sql
DESC EXTERNAL VOLUME automated_intelligence_iceberg_volume;
-- Verify IAM trust relationship includes external ID and user ARN from output
```

### Iceberg Table Issues
```sql
-- Check permissions
SHOW GRANTS ON TABLE automated_intelligence.analytics_iceberg.orders;

-- Grant if needed
GRANT INSERT ON TABLE automated_intelligence.analytics_iceberg.orders 
TO ROLE snowflake_intelligence_admin;
```

### No Data Appearing
1. Check Openflow bulletins in NiFi UI (right panel)
2. Verify PutSnowflake processor configuration
3. Check warehouse is running

---

## Performance Comparison

| Factor | Snowpipe Streaming | Openflow → Iceberg |
|--------|-------------------|-------------------|
| Throughput | 100K+ rows/sec ✅ | 10K-50K rows/sec |
| Latency | Sub-second ✅ | 1-10 seconds |
| Storage Cost | Snowflake billed | External (S3) ✅ |
| Interoperability | Snowflake only | Multi-tool ✅ |
| Development | Code (Java/Python) | Visual UI ✅ |
| Use Case | Operational ✅ | Analytics ✅ |

---

## Connection Details

### Snowflake
- **Connection**: `dash-builder-si`
- **Account**: `sfsenorthamerica-gen_ai_hol`
- **Role**: `snowflake_intelligence_admin`
- **Warehouse**: `automated_intelligence_wh`
- **Database**: `AUTOMATED_INTELLIGENCE`
- **Schema**: `ANALYTICS_ICEBERG`

### Iceberg Configuration (Verified)
- **External Volume**: `aws_s3_ext_volume_snowflake`
- **Catalog**: `SNOWFLAKE`
- **Base Location (Orders)**: `ai/orders/`
- **Base Location (Order Items)**: `ai/order_items/`

### Openflow
- **Runtime**: `https://of--sfsenorthamerica-gen-ai-hol.snowflakecomputing.app/dashing`
- **Process Group**: `0a9f1d18-019b-1000-0000-000034cc7230`
- **Parameter Context**: `0a9f168b-019b-1000-0000-00002778ece2`
- **RSA Key Asset**: `48a1600a-ba09-304b-8103-2a7d7e8635ae`

---

## Success Criteria

✅ Iceberg tables exist in `analytics_iceberg` schema  
✅ Openflow flow created with 6 processors + 3 controller services  
⏳ **Next:** Start flow and verify data appears in Iceberg tables  
⏳ **Next:** Verify time travel works (query past snapshots)  
⏳ **Next:** Validate S3 Parquet files are created

---

## Next Steps

**Immediate (5 min):**
1. Start Openflow processors in UI
2. Monitor flow (check for bulletins/errors)
3. Query Iceberg tables to verify data

**Optional Enhancements:**
- Add monitoring dashboard
- Set up alerts for flow failures
- Connect external tools (Spark/Trino) to S3 Iceberg tables
- Add to Streamlit dashboard
