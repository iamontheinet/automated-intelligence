# Dynamic Table TARGET_LAG Fix

## Issue
All dynamic tables were showing only **12 hours** target lag, but the downstream tables should have been using **DOWNSTREAM** to cascade updates efficiently.

## Root Cause
The dynamic tables were created/modified at some point with all tables having `TARGET_LAG = '12 hours'` instead of the optimized cascade pattern.

## Expected Configuration

### Base Layer (Read from raw.orders, raw.order_items)
- **enriched_orders**: `TARGET_LAG = '12 hours'` ✓
- **enriched_order_items**: `TARGET_LAG = '12 hours'` ✓

### Intermediate Layer (Read from enriched tables)
- **fact_orders**: `TARGET_LAG = DOWNSTREAM` (was incorrectly '12 hours')

### Reporting Layer (Read from fact_orders)
- **daily_business_metrics**: `TARGET_LAG = DOWNSTREAM` (was incorrectly '12 hours')
- **product_performance_metrics**: `TARGET_LAG = DOWNSTREAM` (was incorrectly '12 hours')

## What DOWNSTREAM Means

When a dynamic table uses `TARGET_LAG = DOWNSTREAM`:
- It refreshes **immediately after** its upstream dependencies finish refreshing
- No additional lag is introduced beyond the upstream table's lag
- Creates an efficient cascade: 
  - Raw data → enriched (12h lag) → fact (immediate) → metrics (immediate)
  - Total lag for end users = 12 hours (not 12h + 12h + 12h)

## Fix Applied

```sql
ALTER DYNAMIC TABLE automated_intelligence.dynamic_tables.fact_orders 
SET TARGET_LAG = DOWNSTREAM;

ALTER DYNAMIC TABLE automated_intelligence.dynamic_tables.daily_business_metrics 
SET TARGET_LAG = DOWNSTREAM;

ALTER DYNAMIC TABLE automated_intelligence.dynamic_tables.product_performance_metrics 
SET TARGET_LAG = DOWNSTREAM;
```

## Verification

All tables now have correct TARGET_LAG settings:

```
enriched_orders              → 12 hours    ✓
enriched_order_items         → 12 hours    ✓
fact_orders                  → DOWNSTREAM  ✓
daily_business_metrics       → DOWNSTREAM  ✓
product_performance_metrics  → DOWNSTREAM  ✓
```

## Benefits

1. **Faster propagation**: Changes flow through the pipeline faster
2. **Cost efficiency**: Downstream tables don't wait full 12 hours to refresh
3. **Data freshness**: Metrics update as soon as source data is available
4. **Consistent with design**: Matches the original setup.sql configuration

## Date Fixed
December 9, 2025
