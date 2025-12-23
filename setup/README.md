# Core Setup Scripts

This directory contains **shared infrastructure** required by all demos.

## Purpose

These scripts set up the foundational components that are common across all demo components:
- Database and schemas
- Warehouse
- Core raw tables
- Data generation procedures
- Dynamic Tables pipeline

## Files

### Required for All Demos
- `setup.sql` - **Primary setup script** - Creates database, schemas, warehouse, raw tables, data generation procedures, Dynamic Tables, and semantic model stage

## Setup Instructions

### Minimal Setup (Required)

```bash
# This is the only required setup for basic demos
snow sql -f setup/setup.sql -c dash-builder-si
```

### Full Setup (with AI Features)

```bash
# Core setup (includes semantic model stage)
snow sql -f setup/setup.sql -c dash-builder-si
```

## What Gets Created

### Database Structure
```
automated_intelligence
├── raw                    # Source data tables
├── dynamic_tables         # Transformation pipeline
├── staging               # Gen2 warehouse staging
└── interactive           # High-concurrency serving
```

### Core Tables
- `raw.customers` - Customer master data
- `raw.orders` - Order transactions (**Note:** `order_id` is VARCHAR(36) for UUID compatibility with Snowpipe Streaming)
- `raw.order_items` - Order line items (**Note:** `order_item_id` and `order_id` are VARCHAR(36) for UUID)
- `raw.product_catalog` - Product information

### Dynamic Tables (3-Tier Pipeline)
- **Tier 1: Enrichment** - `enriched_orders`, `enriched_order_items`
- **Tier 2: Fact** - `fact_orders`
- **Tier 3: Aggregation** - `daily_business_metrics`, `product_performance_metrics`

### Data Generation
- `generate_orders(num_orders)` - Stored procedure to generate sample data with UUIDs

**Important:** This procedure generates UUIDs for `order_id` and `order_item_id` to match the format used by Snowpipe Streaming (both Java and Python implementations).

### AI Components (Optional)
- `semantic.order_analytics_agent` - Cortex Agent for natural language queries
- `raw.product_search_service` - Cortex Search for product discovery

## Component-Specific Setup

After running core setup, each demo may have additional setup requirements:

- **Demo 1 (Gen2 Warehouse)**: See `/gen2-warehouse/README.md`
- **Demo 3 (Interactive Tables)**: See `/interactive/README.md`
- **Demo 4 (Snowpipe Streaming)**: See component README files
- **Demo 5 (Security/RBAC)**: See `/security-and-governance/README.md`
- **Demo 6 (Streamlit)**: See `/streamlit-dashboard/README.md`

## Verification

After running setup, verify with:

```sql
-- Check database and schemas
SHOW DATABASES LIKE 'automated_intelligence';
SHOW SCHEMAS IN automated_intelligence;

-- Check tables
SHOW TABLES IN automated_intelligence.raw;
SHOW DYNAMIC TABLES IN automated_intelligence.dynamic_tables;

-- Generate sample data
CALL automated_intelligence.raw.generate_orders(1000);

-- Verify data
SELECT COUNT(*) FROM automated_intelligence.raw.orders;
SELECT COUNT(*) FROM automated_intelligence.raw.customers;
```

## Troubleshooting

If setup fails:
1. Ensure you have `SNOWFLAKE_INTELLIGENCE_ADMIN` role or equivalent privileges
2. Verify warehouse `automated_intelligence_wh` can be created/accessed
3. Check for naming conflicts with existing objects

## Additional Resources

- **Examples & Tutorials**: See `setup/examples/README.md` for:
  - AI functions demonstrations (sentiment, completion, extraction)
  - Dynamic Tables deep dive tutorial
  - Data quality testing scripts
  
- **Configuration & Maintenance**: See `setup/docs/README.md` for:
  - Dynamic Tables configuration reference
  - Troubleshooting guides
  - Maintenance scripts
