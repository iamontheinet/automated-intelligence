# Live Demo Script - Automated Intelligence Platform

## Overview
This comprehensive demo showcases Snowflake's complete Automated Intelligence platform through four interconnected demos that demonstrate an end-to-end data pipeline:

1. **Dynamic Tables Pipeline**: Zero-maintenance incremental transformations
2. **Interactive Tables & Warehouses**: High-concurrency serving layer (<100ms queries)
3. **Snowpipe Streaming**: Billion-scale real-time ingestion (Python + Java)
4. **Security & Governance**: Row-based access control with AI agents

### Platform Flow
```
Snowpipe Streaming → Dynamic Tables → Interactive Tables → Row Access Policies
   (Ingestion)      (Transformation)     (Serving)         (Governance)
```

Each demo builds on shared infrastructure and can be run sequentially or independently after one-time setup.

---

## 🚀 One-Time Setup (Do This Once at the Beginning)

Run these setup scripts **in order** to prepare all demo components:

```bash
# 1. Base setup (database, tables, dynamic tables)
snow sql -f setup.sql -c dash-builder-si

# 2. Interactive tables setup
snow sql -f interactive/setup_interactive.sql -c dash-builder-si

# 3. Security setup (RBAC)
snow sql -f security-and-governance/setup_west_coast_manager.sql -c dash-builder-si

# 4. Snowpipe streaming setup
snow sql -f snowpipe-streaming-java/setup_pipes.sql -c dash-builder-si

# 5. Python virtual environment for interactive demos
cd interactive
python3 -m venv venv
source venv/bin/activate
pip install snowflake-connector-python
cd ..

# 6. (Optional) DBT analytical layer
cd dbt-analytics
pip install dbt-snowflake
dbt deps && dbt build
cd ..
```

**Note:** Snowpipe Streaming requires additional setup:
- RSA key generation (PEM format)
- profile.json configuration with credentials
- For Java: Maven build (`mvn clean install`)
- For Python: pip install requirements (`pip install -r requirements.txt`)
- See respective README files for details

**After setup, all demos are ready to run in any order!**

### 🔄 Resetting Data Between Demo Runs

If you need to start fresh with new ingestion data:

```bash
# Truncate orders and downstream tables (keeps CUSTOMERS reference data)
snow sql -f truncate_tables.sql -c dash-builder-si
```

This truncates:
- `RAW.ORDERS` and `RAW.ORDER_ITEMS` (source data)
- `INTERACTIVE.CUSTOMER_ORDER_ANALYTICS` and `INTERACTIVE.ORDER_LOOKUP` (downstream)
- Dynamic Tables will auto-refresh with new data

---

## 📋 Demo Selection Guide

Choose demos based on your audience:

| Demo | Duration | Best For | Key Takeaway |
|------|----------|----------|--------------|
| **1. Dynamic Tables** | 15-20 min | Data Engineers, Architects | Zero-maintenance pipelines with incremental refresh |
| **2. Interactive Tables** | 10-15 min | App Developers, Performance Engineers | Sub-100ms queries under high concurrency |
| **3. Snowpipe Streaming** | 10-15 min | Real-time Engineers | Billion-scale ingestion (Python or Java) |
| **4. Security & Governance** | 10-15 min | Security Teams, Compliance | Transparent row-level security with AI |
| **Full Suite** | 45-60 min | Executive Demos, All-Hands | Complete platform capabilities end-to-end |

---

# DEMO 1: Dynamic Tables Pipeline

## Overview
Showcases Snowflake Dynamic Tables with incremental refresh, automatic dependency management, and real-time data propagation through a 3-tier pipeline.

---

## Pre-Demo Review (Optional - Show Current State)

### Step 1: Show the Current Database Structure
```sql
-- Show all schemas in the database
SHOW SCHEMAS IN DATABASE automated_intelligence;
```

**What to say**: 
> "We have a clean structure with two main schemas: RAW for our source data, and DYNAMIC_TABLES for our entire pipeline."

### Step 2: Show Existing Dynamic Tables
```sql
-- Display all dynamic tables with key metadata
SHOW DYNAMIC TABLES IN DATABASE automated_intelligence;
```

**What to say**: 
> "Here are our 5 dynamic tables organized in 3 tiers:
> - Tier 1: enriched_orders and enriched_order_items (12-hour target lag)
> - Tier 2: fact_orders (DOWNSTREAM lag - waits for dependencies)
> - Tier 3: daily_business_metrics and product_performance_metrics (DOWNSTREAM lag)
> 
> Notice the 'refresh_mode' column shows INCREMENTAL for all tables - this means they only process changes, not the entire dataset."

### Step 3: Show Current Data Volumes
```sql
-- Check current row counts across all tables
SELECT 'RAW: customers' AS layer_table, COUNT(*) AS row_count 
FROM automated_intelligence.raw.customers
UNION ALL
SELECT 'RAW: orders', COUNT(*) 
FROM automated_intelligence.raw.orders
UNION ALL
SELECT 'RAW: order_items', COUNT(*) 
FROM automated_intelligence.raw.order_items
UNION ALL
SELECT 'TIER 1: enriched_orders', COUNT(*) 
FROM automated_intelligence.dynamic_tables.enriched_orders
UNION ALL
SELECT 'TIER 2: fact_orders', COUNT(*) 
FROM automated_intelligence.dynamic_tables.fact_orders
UNION ALL
SELECT 'TIER 3: daily_metrics', COUNT(*) 
FROM automated_intelligence.dynamic_tables.daily_business_metrics;
```

**What to say**: 
> "Currently, we have 50,100 orders and 300,100 order items in our raw tables. The dynamic tables are all synchronized with this data."

---

## Main Demo - Demonstrating Incremental Refresh

### Step 4: Query Current Refresh History (Baseline)
```sql
-- Check the most recent refresh operations
SELECT 
    name,
    refresh_action,
    refresh_trigger,
    state,
    data_timestamp,
    query_id
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(
    NAME_PREFIX => 'AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES'
))
ORDER BY data_timestamp DESC
LIMIT 20;
```

**What to say**: 
> "Let's look at the refresh history. The 'refresh_action' column shows whether each refresh was INCREMENTAL or FULL. Since these tables were just created, you'll see the initial refresh operations here. Now let's see incremental refresh in action."

### Step 5: Capture Current Daily Metrics (Before Insert)
```sql
-- Show current daily metrics to compare after
SELECT 
    order_date_only,
    total_orders,
    unique_customers,
    total_revenue,
    total_final_revenue,
    avg_order_value
FROM automated_intelligence.dynamic_tables.daily_business_metrics
ORDER BY order_date_only DESC
LIMIT 5;
```

**What to say**: 
> "Here's our current daily business metrics. Pay attention to today's date - we'll see this update after we insert new orders."

### Step 6: Insert New Orders Using Stored Procedure
```sql
-- ⚠️ generate_orders() procedure removed
-- Use Snowpipe Streaming to generate orders
-- See: snowpipe-streaming-java/ or snowpipe-streaming-python/

-- For demo purposes: check existing orders
SELECT COUNT(*) FROM automated_intelligence.raw.orders;
```

**What to say**: 
> "The generate_orders stored procedure has been removed. In production, we now use Snowpipe Streaming for realistic continuous order ingestion. For this demo, we'll work with existing orders in the system, or you can run the Snowpipe Streaming application to generate new data in real-time."

### Step 7: Verify New Data in Raw Tables
```sql
-- Confirm the new orders are in the raw table
SELECT 
    'orders' AS table_name,
    COUNT(*) AS total_rows,
    MAX(order_date) AS latest_order_date
FROM automated_intelligence.raw.orders
UNION ALL
SELECT 
    'order_items',
    COUNT(*),
    NULL
FROM automated_intelligence.raw.order_items;
```

**What to say**: 
> "Perfect! We now have 50,600 orders (up from 50,100). The latest order_date shows these were just created. Now let's manually refresh each tier to see incremental refresh in action.
>
> **Important note about DOWNSTREAM lag**: In production, when Tier 1's **scheduled refresh** runs (every ~12 hours), Snowflake automatically triggers Tier 2 and Tier 3 (which have DOWNSTREAM lag). However, **manual refreshes do NOT trigger DOWNSTREAM dependencies** - that's why we need to manually refresh each tier in this demo. The automatic cascade only works with scheduled refreshes, not manual ones. So we're simulating what would happen automatically in production by manually stepping through each tier!"

### Step 8: Manually Refresh Tier 1 Dynamic Tables
```sql
-- Refresh the first tier (enrichment layer)
-- NOTE: In production, this happens automatically every ~12 hours
ALTER DYNAMIC TABLE automated_intelligence.dynamic_tables.enriched_orders REFRESH;
ALTER DYNAMIC TABLE automated_intelligence.dynamic_tables.enriched_order_items REFRESH;
```

**What to say**: 
> "I'm manually refreshing the Tier 1 tables for demo purposes. In production, these would automatically refresh every ~12 hours based on their target lag setting. Because they use incremental refresh, they'll only process the 500 new orders, not all 50,600. 
>
> Note that this manual refresh does NOT automatically trigger Tier 2 and Tier 3 - manual refreshes don't cascade to DOWNSTREAM dependencies. Only scheduled refreshes cascade automatically!"

### Step 9: Manually Refresh Tier 2 Dynamic Table
```sql
-- Refresh the integration layer
-- NOTE: In production, this automatically refreshes when Tier 1 completes (DOWNSTREAM lag)
ALTER DYNAMIC TABLE automated_intelligence.dynamic_tables.fact_orders REFRESH;
```

**What to say**: 
> "Manually refreshing Tier 2 now. In production, when Tier 1 completes its **scheduled refresh**, the DOWNSTREAM target lag means Snowflake automatically triggers Tier 2. But manual refreshes don't cascade - I need to explicitly refresh this tier. This is simulating what would happen automatically in production!"

### Step 10: Manually Refresh Tier 3 Dynamic Tables
```sql
-- Refresh the aggregation layer
-- NOTE: In production, these automatically refresh when Tier 2 completes (DOWNSTREAM lag)
ALTER DYNAMIC TABLE automated_intelligence.dynamic_tables.daily_business_metrics REFRESH;
ALTER DYNAMIC TABLE automated_intelligence.dynamic_tables.product_performance_metrics REFRESH;
```

**What to say**: 
> "Finally, manually refreshing our Tier 3 aggregation tables. In production, these also have DOWNSTREAM lag, so they automatically refresh when Tier 2 completes its **scheduled refresh**. The key point: **scheduled refreshes cascade automatically through DOWNSTREAM dependencies, but manual refreshes do not**. That's why we're manually triggering each tier - to simulate the automatic production flow in a way we can demonstrate step-by-step!"

---

## Validation & Results

### Step 11: Query Refresh History to Show Incremental Refresh
```sql
-- Show the refresh operations we just triggered
SELECT 
    name,
    refresh_action,
    refresh_trigger,
    state,
    data_timestamp,
    refresh_start_time,
    refresh_end_time,
    DATEDIFF('second', refresh_start_time, refresh_end_time) AS duration_seconds
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(
    NAME_PREFIX => 'AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES'
))
ORDER BY data_timestamp DESC
LIMIT 20;
```

**What to say**: 
> "**This is the key insight!** Look at the 'refresh_action' column - all our refreshes show INCREMENTAL. This means each dynamic table only processed the 500 new orders, not the entire dataset of 50,600+ orders. 
> 
> The 'duration_seconds' shows how fast these refreshes completed. Incremental refresh is exponentially faster as your data grows - instead of reprocessing terabytes, you only process megabytes of changes."

### Step 12: Verify Data Propagation - Check Row Counts
```sql
-- Confirm all tables now have the updated data
SELECT 'RAW: orders' AS layer_table, COUNT(*) AS row_count 
FROM automated_intelligence.raw.orders
UNION ALL
SELECT 'TIER 1: enriched_orders', COUNT(*) 
FROM automated_intelligence.dynamic_tables.enriched_orders
UNION ALL
SELECT 'TIER 2: fact_orders', COUNT(*) 
FROM automated_intelligence.dynamic_tables.fact_orders
UNION ALL
SELECT 'TIER 3: daily_metrics', COUNT(*) 
FROM automated_intelligence.dynamic_tables.daily_business_metrics;
```

**What to say**: 
> "Perfect data lineage! The 500 new orders have propagated through all three tiers. Notice the fact_orders count increased by ~3,000 rows (500 orders × ~6 items each)."

### Step 13: Query Updated Daily Metrics (After Insert)
```sql
-- Show the updated daily metrics
SELECT 
    order_date_only,
    total_orders,
    unique_customers,
    total_revenue,
    total_final_revenue,
    avg_order_value
FROM automated_intelligence.dynamic_tables.daily_business_metrics
ORDER BY order_date_only DESC
LIMIT 5;
```

**What to say**: 
> "Look at today's date - the metrics have updated to include our 500 new orders. The aggregations happened automatically as part of the incremental refresh."

### Step 14: Show Product Performance Updates
```sql
-- Display updated product category metrics
SELECT 
    product_category,
    orders_count,
    items_sold,
    total_quantity_sold,
    total_revenue,
    ROUND(avg_unit_price, 2) AS avg_unit_price
FROM automated_intelligence.dynamic_tables.product_performance_metrics
ORDER BY total_revenue DESC;
```

**What to say**: 
> "Our product performance metrics are also up-to-date. These aggregations would be expensive to compute on-demand over millions of rows, but with dynamic tables, they're pre-computed and incrementally maintained."

---

## Advanced Features Demo (Optional)

### Step 15: Show Dynamic Table Dependency Graph
```sql
-- Show the dependency chain and configuration
SHOW DYNAMIC TABLES IN DATABASE automated_intelligence;
```

**Alternative SQL query (if you want formatted output):**
```sql
-- Query to show key properties
SELECT 
    name,
    target_lag_sec,
    target_lag_type,
    latest_data_timestamp,
    last_completed_refresh_state,
    scheduling_state
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLES())
WHERE database_name = 'AUTOMATED_INTELLIGENCE'
ORDER BY 
    CASE 
        WHEN target_lag_type = 'DOWNSTREAM' THEN 2
        ELSE 1
    END,
    name;
```

**What to say**: 
> "Snowflake automatically manages the dependency graph. Tables with time-based target lag (12 hours) refresh independently. Tables with DOWNSTREAM lag wait for their dependencies, ensuring data consistency."

### Step 16: Show Current State of All Dynamic Tables
```sql
-- Detailed status of each dynamic table
SELECT 
    name AS table_name,
    target_lag_type,
    target_lag_sec,
    latest_data_timestamp,
    last_completed_refresh_state,
    scheduling_state,
    mean_lag_sec,
    maximum_lag_sec
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLES())
WHERE database_name = 'AUTOMATED_INTELLIGENCE'
AND schema_name = 'DYNAMIC_TABLES'
ORDER BY name;
```

**What to say**: 
> "Here's the current state of our pipeline. All tables are ACTIVE and using INCREMENTAL refresh mode. The data_timestamp shows when each table was last refreshed."

---

## Demo Comparison: Incremental vs Full Refresh

### Step 17: Show the Efficiency of Incremental Refresh
```sql
-- Show the most recent refresh for each dynamic table
SELECT 
    name,
    refresh_action,
    refresh_trigger,
    state,
    DATEDIFF('second', refresh_start_time, refresh_end_time) AS duration_seconds,
    data_timestamp,
    statistics:numInsertedRows::INT AS rows_inserted,
    statistics:numDeletedRows::INT AS rows_deleted,
    CASE 
        WHEN refresh_action = 'INCREMENTAL' THEN 'Only processed changes'
        WHEN refresh_action = 'FULL' THEN 'Processed entire dataset'
        WHEN refresh_action = 'NO_DATA' THEN 'No changes detected'
    END AS refresh_description
FROM (
    SELECT 
        name,
        refresh_action,
        refresh_trigger,
        state,
        refresh_start_time,
        refresh_end_time,
        data_timestamp,
        statistics,
        ROW_NUMBER() OVER (PARTITION BY name ORDER BY data_timestamp DESC) AS rn
    FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(
        NAME_PREFIX => 'AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES'
    ))
)
WHERE rn = 1
ORDER BY name;
```

**Alternative - Show refresh action distribution:**
```sql
-- Count refresh types across all dynamic tables
SELECT 
    name,
    refresh_action,
    COUNT(*) AS refresh_count,
    AVG(DATEDIFF('second', refresh_start_time, refresh_end_time)) AS avg_duration_sec,
    SUM(statistics:numInsertedRows::INT) AS total_rows_inserted
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(
    NAME_PREFIX => 'AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES'
))
GROUP BY name, refresh_action
ORDER BY name, refresh_action;
```

**What to say**: 
> "Here you can see the refresh history for all our dynamic tables. Look at the key columns:
> - **refresh_action**: Shows INCREMENTAL when processing changes, or NO_DATA when no changes were detected
> - **rows_inserted/rows_deleted**: The actual row changes processed - notice how incremental refreshes only touch the changed rows
> - **duration_seconds**: Incremental refreshes are extremely fast because they only process deltas
> 
> The alternative query shows aggregated statistics across all refreshes. You'll see that we have INCREMENTAL refreshes that processed thousands of rows in just 1-2 seconds. This is the key to scaling - as your data grows to millions or billions of rows, you still only process the changes.
> 
> **Important**: You'll mainly see NO_DATA and INCREMENTAL refreshes in the history. NO_DATA means the refresh ran but detected no changes to process. INCREMENTAL means changes were detected and processed efficiently. This demonstrates how dynamic tables are smart about only doing work when needed."

---

## Key Takeaways for Audience

**At the end of the demo, summarize:**

1. **Incremental Refresh**: Dynamic tables intelligently detect changes and only process deltas, not entire datasets
2. **Automatic Dependency Management**: The DOWNSTREAM target lag ensures proper refresh ordering without manual orchestration
3. **Declarative Pipelines**: No need to write complex DAGs or manage orchestration - just declare your transformations
4. **Real-time Insights**: Pre-computed aggregations are always fresh within the target lag window
5. **Cost Efficiency**: Pay only for the compute needed to process changes, not to reprocess everything
6. **Zero Manual Intervention**: In production, the entire pipeline is self-orchestrating - set the target lag once and it runs forever

### Production Deployment: Set It and Forget It

**Important clarification for the audience:**

> "Everything we manually refreshed today happens **automatically** in production - but only with **scheduled refreshes**, not manual ones. Here's the key distinction:
>
> **Manual Refresh (what we did in demo):**
> - Does NOT trigger DOWNSTREAM dependencies
> - Must manually refresh each tier
> - Only used for demos, testing, or emergency immediate updates
>
> **Scheduled Refresh (production behavior):**
> - DOES automatically trigger DOWNSTREAM dependencies
> - Entire cascade happens automatically
> - This is how production works!
>
> **What you configure once:**
> - Tier 1 tables: `TARGET_LAG = '12 hours'`
> - Tier 2 tables: `TARGET_LAG = DOWNSTREAM`
> - Tier 3 tables: `TARGET_LAG = DOWNSTREAM`
>
> **What happens automatically forever (scheduled refreshes):**
> 1. Every ~12 hours, Tier 1's **scheduled refresh** runs automatically
> 2. Snowflake detects Tier 2 depends on Tier 1 → automatically triggers Tier 2 refresh
> 3. Snowflake detects Tier 3 depends on Tier 2 → automatically triggers Tier 3 refresh
> 4. All refreshes use incremental mode → only process changes
> 5. Entire cascade completes in seconds/minutes, not hours
>
> **You never have to:**
> - Write orchestration code
> - Manage dependencies manually
> - Schedule jobs in external tools
> - Monitor for failures in the cascade
> - Manually trigger refreshes
>
> **You just deploy the DDL once, and the scheduled refreshes run forever!**"

---

# DEMO 2: Interactive Tables & High-Concurrency Performance

## Overview
Demonstrates Interactive Tables and Interactive Warehouses for customer-facing applications requiring consistent sub-100ms query latency under high concurrency (100+ concurrent users).

## Quick Start

```bash
cd interactive
./demo.sh
```

**What it demonstrates:**
- Real-time pipeline: Data flows from ingestion → transformation → serving (5-minute lag)
- High-concurrency: 10-20x faster queries under load (P95: 80-100ms vs 1-2s)
- Complete native stack: No external cache or API database needed

## Key Demo Points

### Part 1: Real-Time Pipeline (Optional)
```bash
# Generate orders and watch them flow through the pipeline
./demo.sh --enable-realtime --orders 50
```

**Talking points:**
> "We're generating 50 new orders that will appear in our Interactive Tables within 5 minutes. Once there, we can query them in under 100 milliseconds - fast enough for customer-facing applications."

### Part 2: Concurrent Load Testing
```bash
# Test both warehouses for comparison
./demo.sh --threads 150 --warehouse both
```

**Talking points:**
> "We're simulating 150 concurrent users hitting our API simultaneously - like a busy e-commerce site during peak hours. Standard warehouses struggle with queuing and variable latency under this load. Interactive warehouses maintain consistent sub-second median latency - that's **3-4x faster at P95** with 21 million orders in the dataset. The key isn't just speed - it's consistency. Standard warehouse queries range from 1 second to 7 seconds. Interactive warehouse stays predictable: 0.5 to 2.5 seconds even under heavy concurrent load."

### Expected Results (150 threads, 500 queries, 21.3M orders in dataset)

| Metric | Standard Warehouse | Interactive Warehouse | Improvement |
|--------|-------------------|----------------------|-------------|
| **P95** | 6,897 ms (6.9s) | 2,119 ms (2.1s) | **3.3x faster** |
| **Median** | 4,254 ms (4.3s) | 945 ms (0.95s) | **4.5x faster** |
| **Average** | 4,221 ms (4.2s) | 1,083 ms (1.1s) | **3.9x faster** |
| **Consistency** | Variable (queuing) | Predictable | ✓ |

**Closing:**
> "This is a complete native Snowflake pipeline. No Redis for caching, no separate API database, no complex ETL to sync data. Just Snowflake, from ingestion to serving, with production-ready performance at scale. We just demonstrated queries staying under 1 second median even with 150 concurrent users and 21 million orders!"

**See:** `interactive/README.md` for detailed documentation

---

# DEMO 3: Snowpipe Streaming - Billion-Scale Ingestion

## Overview
Demonstrates high-performance real-time data ingestion using Snowpipe Streaming, capable of scaling from thousands to **1 billion orders** through parallel processing. Available in both **Java** and **Python** implementations with identical functionality.

## Architecture Highlights

**Performance benchmarks:**
- Single instance: 10K orders in ~5-7 seconds
- 5 parallel instances: 1M orders in ~45 seconds (**100x faster** than stored procedures)
- 10 parallel instances: 10M orders in ~5 minutes
- Billion-scale ready: 1B orders in 30-60 minutes with 50+ instances

## Implementation Options

### Option 1: Python Implementation (Recommended for Quick Start)

```bash
cd snowpipe-streaming-python

# Single instance demo (10K orders)
python src/automated_intelligence_streaming.py 10000

# Parallel demo (1M orders across 5 instances)
python src/parallel_streaming_orchestrator.py 1000000 5

# Large scale demo (10M orders across 10 instances)
python src/parallel_streaming_orchestrator.py 10000000 10
```

**Python Setup:**
```bash
pip install -r requirements.txt
cp profile.json.template profile.json
# Edit profile.json with your credentials
```

### Option 2: Java Implementation

```bash
cd snowpipe-streaming-java

# Build
mvn clean install

# Single instance demo (10K orders)
java -jar target/automated-intelligence-streaming-1.0.0.jar 10000

# Parallel demo (1M orders across 5 instances)
java ParallelStreamingOrchestrator 1000000 5
```

## Key Demo Points

**Talking points:**
> "We're streaming data directly into Snowflake with sub-second latency. This architecture can scale horizontally - each instance operates independently with unique channels. We've validated performance up to **10 million orders in 5 minutes** with 10 parallel instances, and the architecture is ready for billion-scale workloads.
>
> Both Python and Java implementations deliver identical performance and business logic. The Python SDK is Rust-backed for high performance, making it just as fast as the Java version while offering simpler deployment and integration with Python data tools."

### Monitoring

```sql
-- Check channel status
SELECT 
    CHANNEL_NAME,
    PIPE_NAME,
    TABLE_NAME,
    LAST_COMMITTED_TIME,
    STATUS
FROM SNOWFLAKE.ACCOUNT_USAGE.SNOWPIPE_STREAMING_CHANNEL_HISTORY
WHERE TABLE_DATABASE = 'AUTOMATED_INTELLIGENCE'
  AND TABLE_SCHEMA = 'RAW'
ORDER BY LAST_COMMITTED_TIME DESC;

-- Verify data ingestion
SELECT 'orders' AS table_name, COUNT(*) AS row_count FROM RAW.ORDERS
UNION ALL
SELECT 'order_items', COUNT(*) FROM RAW.ORDER_ITEMS;
```

**Real-World Performance Results:**

**10 Million Orders Demo (Python - 10 parallel instances):**
- Total execution: ~5 minutes
- Throughput: ~34,000 orders/second
- Order items generated: ~55 million
- Success rate: 100% (10/10 instances completed)
- Customer partitioning: Perfect distribution across 20,505 customers
- Final dataset: 21.3M orders, 117M order items

**Closing:**
> "Snowpipe Streaming provides exactly-once delivery guarantees, automatic offset management, and linear horizontal scaling. No external streaming infrastructure needed - it's native to Snowflake. Choose Python for rapid development and integration with data science tools, or Java for enterprise JVM environments. Both deliver identical performance and functionality."

**See:** 
- Python: `snowpipe-streaming-python/README.md` and `COMPARISON.md`
- Java: `snowpipe-streaming-java/README.md`

---

# DEMO 4: Security & Governance - Row-Based Access Control

## Overview
Demonstrates row-based access control (RBAC) using Snowflake Intelligence with region-filtered data views. Same agent, dramatically different answers based on role.

## The Setup

**Two Roles, Dramatically Different Views:**

| Role | States Visible | Revenue | Customers |
|------|---------------|---------|-----------|
| **SNOWFLAKE_INTELLIGENCE_ADMIN** | All 10 states | $733M | 20,200 |
| **WEST_COAST_MANAGER** | Only CA, OR, WA | $224M | 6,115 |

## Live Demo Script

### Open Snowflake Intelligence in Two Browser Windows

**Window 1 (Admin Role):**
```sql
USE ROLE snowflake_intelligence_admin;
```

**Window 2 (West Coast Manager):**
```sql
USE ROLE west_coast_manager;
```

### Question 1: Total Revenue
**Ask both roles:** "What's our total revenue?"

- **Admin sees:** $733M (100%)
- **West Coast sees:** $224M (31%) ← 69% hidden!

### Question 2: Revenue by State
**Ask both roles:** "Show me revenue by state"

- **Admin sees:** 10 states in chart
- **West Coast sees:** 3 states only (CA, OR, WA)

### Question 3: Top Performing States
**Ask both roles:** "What are our top 3 states by revenue?"

- **Admin sees:** NV ($76M), OR ($75M), CA ($75M)
- **West Coast sees:** OR ($75M), CA ($75M), WA ($73M) - *Doesn't even know NV exists!*

## Key Talking Points

**Transparent Security:**
> "The row access policy is completely transparent to the agent and users. West Coast Manager doesn't know that other regions exist - they're automatically filtered out at the database level. No application code changes needed."

**Natural Language Works:**
> "The agent generates SQL that automatically respects the row access policy. When the West Coast Manager asks for 'total revenue,' they get their region's revenue - the policy filters data before the agent even sees it."

**Production Use Cases:**
- Multi-region sales organizations
- Franchise models
- Multi-brand companies
- Compliance requirements (data residency, privacy regulations)
- Partner networks

**Closing:**
> "This is Snowflake's governance model: security is built into the data platform, not the application layer. One agent serves all roles with appropriate data views, and you maintain a single source of truth."

**See:** `security-and-governance/README.md` for setup and SQL examples

---

## 🔄 Running Demos Sequentially

### Demo Order (Recommended)
1. **Dynamic Tables** - Shows foundational data pipeline
2. **Interactive Tables** - Shows performance optimization for serving layer
3. **Snowpipe Streaming** - Shows high-scale ingestion capability
4. **Security & Governance** - Shows enterprise security with AI agents

### Notes for Sequential Execution
- ✅ All demos share the same base database (`AUTOMATED_INTELLIGENCE`)
- ✅ Data is additive - each demo can generate more orders without breaking others
- ✅ No cleanup needed between demos
- ⚠️ For RBAC demo, remember to switch to appropriate roles to demonstrate filtering
- ⚠️ Interactive warehouse uses separate schema (`INTERACTIVE`) - no conflicts with base setup

### Data Growth Tracking
After running all demos, you can check total data volumes:

```sql
SELECT 
    'customers' AS table_name, 
    COUNT(*) AS row_count 
FROM AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS
UNION ALL
SELECT 'orders', COUNT(*) FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS
UNION ALL
SELECT 'order_items', COUNT(*) FROM AUTOMATED_INTELLIGENCE.RAW.ORDER_ITEMS
UNION ALL
SELECT 'interactive: customer_order_analytics', COUNT(*) 
FROM AUTOMATED_INTELLIGENCE.INTERACTIVE.CUSTOMER_ORDER_ANALYTICS
ORDER BY table_name;
```

---

## 🎯 Complete Demo Summary

After running all four demos, summarize the platform capabilities:

**Data Ingestion:**
- ✅ Snowpipe Streaming: Sub-second latency, billion-scale ready, parallel processing (Python or Java)

**Data Transformation:**
- ✅ Dynamic Tables: Incremental refresh, automatic dependencies, zero maintenance

**Data Serving:**
- ✅ Interactive Tables: Sub-100ms queries, high concurrency, no external cache

**Data Governance:**
- ✅ Row Access Policies: Transparent security, role-based filtering, agent-compatible

**Platform Benefits:**
- ✅ Fully native stack - no external systems required
- ✅ Set-and-forget automation - minimal operational overhead
- ✅ Linear scalability - from thousands to billions of records
- ✅ Enterprise-grade security - built into the data platform

---

## 🧹 Cleanup (After All Demos)

If you want to reset for another demo session:

```sql
-- Optional: Drop and recreate everything
-- (Only run if you want to start fresh)
DROP DATABASE automated_intelligence CASCADE;

-- Remove row access policy
DROP ROW ACCESS POLICY IF EXISTS automated_intelligence.raw.customers_region_policy;

-- Remove roles
DROP ROLE IF EXISTS west_coast_manager;
```

Or keep the structure and just add more data:

```sql
-- Add more orders via Snowpipe Streaming
-- See: snowpipe-streaming-java/ or snowpipe-streaming-python/
```

---

## 📚 Additional Resources

### Setup & Configuration
- **Setup Scripts**: `setup/*.sql`
- **Connection Guide**: Snowflake CLI configuration for `dash-builder-si` connection

### Demo Documentation
- **Main README**: `README.md` - Platform overview and quick start
- **This File**: `DEMO_SCRIPT.md` - Complete demo guide with talking points
- **Interactive Tables**: `interactive/README.md` - Performance deep dive
- **Snowpipe Python**: `snowpipe-streaming-python/README.md` and `COMPARISON.md`
- **Snowpipe Java**: `snowpipe-streaming-java/README.md`
- **RBAC Demo**: `security-and-governance/README.md`

### Query Scripts
- **Dynamic Tables**: SQL scripts in `setup/` directory
- **Interactive Performance**: `interactive/demo_interactive_performance.sql`
- **Validation**: Various test and validation SQL files in each directory

---

**Remember: After one-time setup, all demos work independently and can be run in any order!** 🚀
