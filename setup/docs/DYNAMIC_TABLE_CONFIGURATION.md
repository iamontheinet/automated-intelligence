# Dynamic Table Configuration - Near Real-Time Analytics

## Current Configuration

### Layer 1: Base Enrichment (1 minute lag)
- **enriched_orders**: `TARGET_LAG = '1 minute'` ✓
- **enriched_order_items**: `TARGET_LAG = '1 minute'` ✓

These tables read from `raw.orders` and `raw.order_items` which are populated via **Snowpipe Streaming** for sub-second ingestion.

### Layer 2: Fact Tables (Downstream)
- **fact_orders**: `TARGET_LAG = DOWNSTREAM` ✓

Combines enriched orders and order items. Refreshes immediately after Layer 1 completes.

### Layer 3: Analytics/Metrics (Downstream)
- **daily_business_metrics**: `TARGET_LAG = DOWNSTREAM` ✓
- **product_performance_metrics**: `TARGET_LAG = DOWNSTREAM` ✓

Aggregate metrics refreshed immediately after fact tables update.

## Data Freshness Flow

```
Snowpipe Streaming (sub-second)
    ↓
raw.orders, raw.order_items
    ↓ (1 minute lag)
enriched_orders, enriched_order_items
    ↓ (DOWNSTREAM = immediate)
fact_orders
    ↓ (DOWNSTREAM = immediate)
daily_business_metrics, product_performance_metrics
```

**Total end-to-end latency: ~1-2 minutes from ingestion to analytics**

This configuration is optimized for real-time demo scenarios, showcasing how quickly data flows through the entire pipeline.

## What This Enables

### Near Real-Time Analytics
- Dashboard updates within 1-2 minutes of data arrival
- Ideal for operational monitoring and live business intelligence
- Stream data in → See insights in under 2 minutes

### Efficient Resource Usage
- Only base tables (Layer 1) actively poll raw data every minute
- Downstream tables cascade automatically (no redundant polling)
- Warehouse spins up once per minute (not per table)

## Verification

### Default Configuration (1 Minute)
This configuration is **automatically applied** when you run `setup/setup.sql`. No additional scripts needed!

### Verify Configuration
```bash
for table in enriched_orders enriched_order_items fact_orders daily_business_metrics product_performance_metrics; do
  echo "=== $table ==="
  snow sql -c dash-builder-si --role snowflake_intelligence_admin -q \
    "SELECT GET_DDL('TABLE', 'automated_intelligence.dynamic_tables.$table');" | grep target_lag
done
```

Expected output:
```
=== enriched_orders ===
target_lag = '1 minute'

=== enriched_order_items ===
target_lag = '1 minute'

=== fact_orders ===
target_lag = 'DOWNSTREAM'

=== daily_business_metrics ===
target_lag = 'DOWNSTREAM'

=== product_performance_metrics ===
target_lag = 'DOWNSTREAM'
```

## Alternative Configurations

### Batch Processing (12 hours)

If you prefer lower costs over freshness, change base tables to 12 hours:

```sql
ALTER DYNAMIC TABLE enriched_orders SET TARGET_LAG = '12 hours';
ALTER DYNAMIC TABLE enriched_order_items SET TARGET_LAG = '12 hours';
-- Downstream tables automatically adjust (DOWNSTREAM)
```

## Cost Considerations

### 1-Minute Configuration (Current)
- Warehouse active ~1 minute per refresh
- 60 refreshes/hour × 24 hours = 1,440 refreshes/day
- Best for: Live dashboards, operational analytics, real-time monitoring

### 12-Hour Configuration
- Warehouse active ~1 minute per refresh
- 2 refreshes/day (every 12 hours)
- Best for: Daily reporting, cost optimization, batch analytics

**Cost difference**: ~720x more warehouse credits with 1-minute lag
**Value**: Near real-time insights vs. daily batch updates

## When to Use Each Configuration

| Use Case | Recommended Lag |
|----------|----------------|
| Live operational dashboard | 1 minute |
| Real-time fraud detection | 1 minute |
| Customer service agent tools | 1 minute |
| Executive daily reports | 12 hours |
| Weekly business reviews | 12 hours |
| Monthly trend analysis | 12 hours |

## History

- **Initial setup**: 12-hour lag (batch processing)
- **December 23, 2024**: Changed to 1-minute lag as DEFAULT in setup.sql
- **Reason**: Enable live dashboards and real-time analytics out-of-the-box
