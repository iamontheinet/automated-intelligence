# Snowpipe Streaming - Staging vs Production Configurations

This directory now contains **two configurations**:

## 🎯 **Configuration 1: Staging Target (NEW - For Gen2 Demo)**

**Files:**
- `config_staging.properties` - Points to staging schema
- `profile_staging.json` - Schema: `STAGING`

**Targets:**
- `staging.customers_staging`
- `staging.orders_staging`
- `staging.order_items_staging`

**Use Case:** Demonstrates production pipeline with Gen2 MERGE operations

**How to Run:**
```bash
# Use config_staging.properties
python src/automated_intelligence_streaming.py --config config_staging.properties
```

---

## 📦 **Configuration 2: Raw Target (ORIGINAL - Existing Demo)**

**Files:**
- `config.properties` - Points to raw schema
- `profile.json` - Schema: `RAW`

**Targets:**
- `raw.customers`
- `raw.orders`
- `raw.order_items`

**Use Case:** Direct ingestion (original implementation)

**How to Run:**
```bash
# Use config.properties
python src/automated_intelligence_streaming.py --config config.properties
```

---

## 🏭 **Production Pipeline Flow (Recommended)**

```
1. Snowpipe Streaming → staging.* (config_staging.properties)
   ↓
2. Gen2 MERGE → raw.* (stored procedures)
   ↓
3. Dynamic Tables → interactive.* 
   ↓
4. ML Models & Dashboard
```

## 🔧 **Setup Steps**

1. **Run SQL Setup Scripts:**
```sql
-- In Snowsight or SnowSQL
@sql/setup_staging_pipeline.sql
@sql/setup_merge_procedures.sql
```

2. **Stream to Staging:**
```bash
cd /Users/ddesai/Apps/Snova/automated-intelligence/snowpipe-streaming-python
python src/automated_intelligence_streaming.py --config config_staging.properties --num-orders 100000
```

3. **Run MERGE (Dashboard triggers this automatically):**
```sql
-- Gen2 benchmark
CALL staging.merge_staging_to_raw('automated_intelligence_gen2_wh');

-- Gen1 comparison
CALL staging.merge_staging_to_raw('automated_intelligence_wh');
```

---

## ✅ **Both Configurations Coexist**

- **No breaking changes** - original config still works
- **Isolated testing** - staging schema is separate
- **Production-ready** - shows real-world data engineering pattern
