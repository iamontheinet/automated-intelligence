# Core Setup Scripts

This directory contains **shared infrastructure** required by all demos.

## Purpose

These scripts set up the foundational components that are common across all demo components:
- Database and schemas
- Warehouse
- Core raw tables
- Data generation procedures
- Dynamic Tables pipeline
- Cortex Search and Agent

## Files

### Required for All Demos
- `setup.sql` - **Primary setup script** - Creates database, schemas, warehouse, raw tables, data generation procedures, and Dynamic Tables

### Optional (AI/NL Query Features)
- `create_semantic_model_stage.sql` - Creates stage for semantic model YAML files
- `business_insights_semantic_model.yaml` - Semantic model definition for Cortex Analyst
- `create_agent.sql` - Creates Cortex Agent for natural language queries
- `create_cortex_search.sql` - Creates Cortex Search service for product discovery

## Setup Instructions

### Minimal Setup (Required)

```bash
# This is the only required setup for basic demos
snow sql -f setup/setup.sql -c dash-builder-si
```

### Full Setup (with AI Features)

```bash
# 1. Core setup
snow sql -f setup/setup.sql -c dash-builder-si

# 2. Cortex Search
snow sql -f setup/create_cortex_search.sql -c dash-builder-si

# 3. Semantic model and agent
snow sql -f setup/create_semantic_model_stage.sql -c dash-builder-si
snow stage copy setup/business_insights_semantic_model.yaml @automated_intelligence.raw.semantic_models/ --overwrite -c dash-builder-si
snow sql -f setup/create_agent.sql -c dash-builder-si
```

## What Gets Created

### Database Structure
```
automated_intelligence
├── raw                    # Source data tables
├── dynamic_tables         # Transformation pipeline
└── semantic              # AI/NL query layer
```

### Core Tables
- `raw.customers` - Customer master data
- `raw.orders` - Order transactions
- `raw.order_items` - Order line items
- `raw.product_catalog` - Product information

### Dynamic Tables (3-Tier Pipeline)
- **Tier 1: Enrichment** - `enriched_orders`, `enriched_order_items`
- **Tier 2: Fact** - `fact_orders`
- **Tier 3: Aggregation** - `daily_business_metrics`, `product_performance_metrics`

### Data Generation
- `generate_orders(num_orders)` - Stored procedure to generate sample data

### AI Components (Optional)
- `semantic.order_analytics_agent` - Cortex Agent for natural language queries
- `raw.product_search_service` - Cortex Search for product discovery

## Component-Specific Setup

After running core setup, each demo may have additional setup requirements:

- **Demo 1 (Gen2 Warehouse)**: See `/sql/README.md`
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

See `/docs` for additional troubleshooting guides.
