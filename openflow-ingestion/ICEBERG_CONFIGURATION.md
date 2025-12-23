# Iceberg Configuration Reference

## Verified AWS + S3 Setup

The following Iceberg configuration has been tested and validated by the user:

### External Volume
```sql
EXTERNAL_VOLUME = 'aws_s3_ext_volume_snowflake'
```

**Status**: ✅ Already created and working  
**Provider**: AWS S3  
**IAM Role**: Configured with appropriate trust relationship  

### Catalog
```sql
CATALOG = 'SNOWFLAKE'
```

**Type**: Snowflake-managed Iceberg catalog  
**Benefits**:
- Full DML support (INSERT, UPDATE, DELETE, MERGE)
- ACID transactions
- Time travel via snapshots
- Automatic metadata management

### Base Locations

#### Orders Table
```sql
BASE_LOCATION = 'ai/orders/'
```

**Full S3 Path**: `s3://<bucket>/ai/orders/`  
**Contains**: 
- Parquet data files
- Iceberg metadata files
- Manifest files

#### Order Items Table
```sql
BASE_LOCATION = 'ai/order_items/'
```

**Full S3 Path**: `s3://<bucket>/ai/order_items/`  
**Contains**: Same structure as orders table

---

## Table Configuration

### Orders Table
```sql
CREATE ICEBERG TABLE automated_intelligence.analytics_iceberg.orders
   EXTERNAL_VOLUME = 'aws_s3_ext_volume_snowflake'
   CATALOG = 'SNOWFLAKE'
   BASE_LOCATION = 'ai/orders/'
   TARGET_FILE_SIZE = '128MB'
   ENABLE_DATA_COMPACTION = TRUE
   (
      ORDER_ID STRING NOT NULL,
      CUSTOMER_ID NUMBER(38,0) NOT NULL,
      ORDER_DATE TIMESTAMP_NTZ NOT NULL,
      ORDER_STATUS STRING,
      TOTAL_AMOUNT NUMBER(10,2),
      DISCOUNT_PERCENT NUMBER(5,2),
      SHIPPING_COST NUMBER(8,2)
   );

-- Clustering for query performance
ALTER ICEBERG TABLE automated_intelligence.analytics_iceberg.orders
   CLUSTER BY (ORDER_DATE, CUSTOMER_ID);
```

**Note**: Iceberg tables require `STRING` instead of `VARCHAR(L)` for text columns.

### Order Items Table
```sql
CREATE ICEBERG TABLE automated_intelligence.analytics_iceberg.order_items
   EXTERNAL_VOLUME = 'aws_s3_ext_volume_snowflake'
   CATALOG = 'SNOWFLAKE'
   BASE_LOCATION = 'ai/order_items/'
   TARGET_FILE_SIZE = '128MB'
   ENABLE_DATA_COMPACTION = TRUE
   (
      ORDER_ITEM_ID STRING NOT NULL,
      ORDER_ID STRING NOT NULL,
      PRODUCT_ID NUMBER(38,0) NOT NULL,
      PRODUCT_NAME STRING,
      PRODUCT_CATEGORY STRING,
      QUANTITY NUMBER(38,0),
      UNIT_PRICE NUMBER(10,2),
      LINE_TOTAL NUMBER(12,2)
   );

-- Clustering for query performance  
ALTER ICEBERG TABLE automated_intelligence.analytics_iceberg.order_items
   CLUSTER BY (ORDER_ID, PRODUCT_ID);
```

---

## Validation Queries

### Check Table Properties
```sql
SELECT 
    table_name,
    table_type,
    is_iceberg,
    external_volume,
    base_location
FROM automated_intelligence.information_schema.tables
WHERE table_schema = 'ANALYTICS_ICEBERG';
```

### Check S3 Files
```sql
-- View data files created in S3
SELECT 
    table_name,
    file_path,
    file_size_bytes / (1024*1024) AS file_size_mb,
    record_count
FROM automated_intelligence.information_schema.iceberg_table_files
WHERE table_schema = 'ANALYTICS_ICEBERG'
ORDER BY table_name, file_path;
```

### Check Snapshots (Time Travel)
```sql
-- View table snapshots for time travel
SELECT 
    table_name,
    snapshot_id,
    committed_at,
    parent_id,
    operation
FROM automated_intelligence.information_schema.iceberg_table_snapshots
WHERE table_schema = 'ANALYTICS_ICEBERG'
ORDER BY table_name, committed_at DESC;
```

### Test Insert
```sql
-- Test inserting a record
INSERT INTO automated_intelligence.analytics_iceberg.orders 
VALUES (
    'test-order-001',
    12345,
    CURRENT_TIMESTAMP(),
    'Pending',
    99.99,
    10.0,
    5.99
);

-- Verify insert worked and file created in S3
SELECT COUNT(*) FROM automated_intelligence.analytics_iceberg.orders;

-- Check S3 file created
SELECT * FROM automated_intelligence.information_schema.iceberg_table_files
WHERE table_schema = 'ANALYTICS_ICEBERG' 
  AND table_name = 'ORDERS';
```

---

## Openflow Configuration

When configuring Openflow PutSnowflake processors, use:

**Database**: `AUTOMATED_INTELLIGENCE`  
**Schema**: `ANALYTICS_ICEBERG`  
**Tables**: `ORDERS`, `ORDER_ITEMS`  

The external volume and S3 configuration are transparent to Openflow - it just executes standard SQL INSERT statements, and Snowflake handles writing to S3.

---

## Performance Settings

**Target File Size**: 128MB
- Balances query performance vs file count
- Optimal for analytical queries

**Data Compaction**: ENABLED
- Automatically merges small files
- Reduces S3 API costs
- Improves query performance

**Clustering**: 
- Orders: `(ORDER_DATE, CUSTOMER_ID)`
- Order Items: `(ORDER_ID, PRODUCT_ID)`
- Speeds up filtered queries and joins

---

## Storage Architecture

```
S3 Bucket
└── ai/
    ├── orders/
    │   ├── data/
    │   │   ├── 00000-0-<uuid>.parquet
    │   │   └── 00001-0-<uuid>.parquet
    │   └── metadata/
    │       ├── v1.metadata.json
    │       ├── v2.metadata.json
    │       └── snap-<id>-1-<uuid>.avro
    └── order_items/
        ├── data/
        │   └── 00000-0-<uuid>.parquet
        └── metadata/
            └── v1.metadata.json
```

**Data Files**: Parquet format (columnar)  
**Metadata Files**: JSON and Avro (Iceberg table structure)  
**Manifest Files**: Track which data files belong to which snapshots  

---

## Cost Model

✅ **No Snowflake Storage Charges**: Data lives in your S3 bucket  
💰 **S3 Storage Cost**: Standard S3 pricing for your bucket  
💰 **Snowflake Compute Cost**: Only when querying/writing data  
💰 **S3 API Cost**: Minimal (LIST, GET operations during queries)  

**Example Cost Breakdown** (100GB data):
- S3 Storage: ~$2.30/month (standard)
- Snowflake Compute: Pay-per-query only
- **vs Native Tables**: Would cost ~$23/month in Snowflake storage

---

## Testing Checklist

- [x] External volume created
- [x] IAM trust relationship configured
- [x] Can create Iceberg tables
- [x] Can INSERT records
- [x] Can see metadata files in S3
- [x] Can see data files in S3
- [ ] Openflow writing to tables
- [ ] Time travel queries working
- [ ] Query from external tools (Spark/Trino)
