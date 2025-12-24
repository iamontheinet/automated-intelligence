# Automated Intelligence Platform - Complete Demo Suite

## 🎯 Overview

This comprehensive demo platform showcases Snowflake's Automated Intelligence capabilities through interconnected demos that demonstrate a complete data pipeline - from ingestion to serving to governance:

1. **Gen2 Warehouse Performance** - Next-generation MERGE/UPDATE operations (10-40% faster) (NEW!)
2. **Dynamic Tables Pipeline** - Zero-maintenance incremental transformations
3. **Interactive Tables & Warehouses** - High-concurrency serving layer (<100ms queries)
4. **Snowpipe Streaming** - Billion-scale real-time ingestion (Python + Java)
5. **Security & Governance** - Row-based access control with AI agents
6. **Streamlit Dashboard** - Real-time monitoring of ingestion and performance

All demos share the same foundation and work together to show an end-to-end platform.

---

## 🏗️ Platform Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│  DEMO 4: INGESTION LAYER                                         │
│  Snowpipe Streaming (Python/Java) → Real-time data ingestion    │
│  • Single instance: 10K orders in 5-7 seconds                   │
│  • 10 parallel: 10M orders in 5 minutes                         │
│  • Billion-scale ready: Linear horizontal scaling               │
└──────────────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────────────┐
│  DEMO 1: STAGING & TRANSFORMATION LAYER (NEW!)                   │
│  Gen2 Warehouses → Staging → MERGE/UPDATE → Production          │
│  • 10-40% faster MERGE/UPDATE/DELETE operations                 │
│  • Production pattern: Staging → Deduplication → Raw tables     │
│  • Fair benchmarking with snapshot/restore                      │
└──────────────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────────────┐
│  DEMO 2: TRANSFORMATION LAYER                                    │
│  Dynamic Tables (3 tiers) → Incremental transformations         │
│  • Tier 1: Enrichment (12-hour refresh)                         │
│  • Tier 2: Integration (DOWNSTREAM)                             │
│  • Tier 3: Aggregation (DOWNSTREAM)                             │
└──────────────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────────────┐
│  DEMO 3: SERVING LAYER                                           │
│  Interactive Tables → High-concurrency performance               │
│  • Sub-100ms queries under load                                  │
│  • 100+ concurrent users                                         │
│  • 3-10x faster than standard warehouses                         │
└──────────────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────────────┐
│  DEMO 5: GOVERNANCE LAYER                                        │
│  Row Access Policies → Transparent security                      │
│  • Role-based filtering                                          │
│  • Agent-compatible                                              │
│  • Zero application changes                                      │
└──────────────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────────────┐
│  SEMANTIC LAYER (NEW!)                                           │
│  Semantic Views + Cortex Agent → Natural language queries       │
│  • Business terminology mapping                                  │
│  • Verified query repository (VQR)                              │
│  • Multi-source integration                                      │
└──────────────────────────────────────────────────────────────────┘
```

---

## 🚀 Quick Start - One-Time Setup

### Core Setup (Required for All Demos)

Run these scripts **once** to set up shared infrastructure:

```bash
# Core infrastructure (database, schemas, warehouse, tables, dynamic tables)
snow sql -f setup.sql -c dash-builder-si
```

### Optional: Analytical Layer Setup (DBT)

For batch analytical models (CLV, segmentation, cohorts):

```bash
cd dbt-analytics
pip install dbt-snowflake
dbt deps
dbt debug  # Test connection
dbt build  # Build all models
```

See `dbt-analytics/README.md` for detailed setup and usage.

### Optional: Snowflake Intelligence Setup

See `snowflake-intelligence/README.md` for Cortex Agent, Cortex Search, and semantic model setup.

### Component-Specific Setup (Run Only What You Need)

Each demo has its own setup. Run only the ones you plan to use:

```bash
# Demo 1: Gen2 Warehouse Performance
snow sql -f sql/setup_staging_pipeline.sql -c dash-builder-si
snow sql -f sql/setup_merge_procedures.sql -c dash-builder-si
# See sql/README.md for details

# Demo 2: Dynamic Tables
# (No additional setup - covered by core setup.sql)

# Demo 3: Interactive Tables
snow sql -f interactive/setup_interactive.sql -c dash-builder-si
# See interactive/README.md for details

# Demo 4: Snowpipe Streaming
# Requires RSA key generation and SDK setup
# See snowpipe-streaming-java/README.md or snowpipe-streaming-python/README.md

# Demo 5: Security & Governance
snow sql -f security-and-governance/setup_west_coast_manager.sql -c dash-builder-si
# See security-and-governance/README.md for details

# Demo 6: Streamlit Dashboard
cd streamlit-dashboard
# See streamlit-dashboard/README.md for Python environment setup
```

**After core setup, pick the demos you want and run their specific setup scripts!**

---

## 📋 Demo Selection Guide

Choose demos based on your audience and time:

| Demo | Duration | Best For | Key Takeaway |
|------|----------|----------|--------------|
| **1. Gen2 Warehouse Performance** | 10-15 min | Data Engineers, Performance Teams | 10-40% faster MERGE/UPDATE operations |
| **2. Dynamic Tables** | 15-20 min | Data Engineers, Architects | Zero-maintenance pipelines |
| **3. Interactive Tables** | 10-15 min | App Developers, Performance Engineers | Sub-100ms query latency |
| **4. Snowpipe Streaming** | 10-15 min | Real-time Engineers | Billion-scale ingestion |
| **5. Security & Governance** | 10-15 min | Security Teams, Compliance | Transparent row-level security |
| **6. Streamlit Dashboard** | Continuous | Everyone | Real-time pipeline monitoring |
| **Full Suite** | 60-75 min | Executive Demos, All-Hands | Complete platform capabilities |

---

## 📚 Demo Details

### DEMO 1: Gen2 Warehouse Performance - Next-Generation MERGE/UPDATE Operations

**What it demonstrates:**
- 10-40% performance improvements on MERGE/UPDATE/DELETE operations
- Production-ready staging pattern: Snowpipe Streaming → Staging → MERGE → Production
- Fair benchmarking with snapshot/restore mechanism (identical data state for Gen1 vs Gen2)
- Real-world data engineering pipeline with deduplication and enrichment

**Quick start:**
```bash
# 1. Stream data to staging tables
cd snowpipe-streaming-python
python src/automated_intelligence_streaming.py --config config_staging.properties --num-orders 100000

# 2. Run Gen2 vs Gen1 comparison test
cd ../streamlit-dashboard
streamlit run streamlit_app.py --server.port 8501
# Navigate to "Next-Gen Warehouse Performance" page
# Click "Run MERGE Test using Gen 1 and Gen 2"
```

**Architecture:**
```
Snowpipe Streaming (5-10s latency)
       ↓
staging.* tables (append-only)
       ↓
Gen2 MERGE/UPDATE (deduplicate, upsert, enrich)
       ↓
raw.* tables (production)
```

**Expected results (100K orders streamed):**

| Operation | Gen1 | Gen2 | Improvement |
|-----------|------|------|-------------|
| MERGE Orders | 8,900ms | 5,800ms | **35% faster** |
| MERGE Order Items | 5,200ms | 3,400ms | **35% faster** |
| UPDATE Enrichment | 1,400ms | 1,200ms | **14% faster** |
| **Total Pipeline** | **18,700ms** | **12,500ms** | **33% faster** |

**Key insights:**
- Gen2 uses `RESOURCE_CONSTRAINT = 'STANDARD_GEN_2'` for optimized MERGE/UPDATE/DELETE performance
- Staging pattern enables high-throughput ingestion without blocking production queries
- Snapshot/restore ensures fair comparison: both warehouses operate on identical data state
- Production-ready: Can automate with TASK for continuous pipeline

**MERGE operations:**
- Deduplicates using `ROW_NUMBER() OVER (PARTITION BY id ORDER BY inserted_at DESC)`
- Upserts to production tables (MATCHED → UPDATE, NOT MATCHED → INSERT)

**UPDATE operations:**
- Applies business logic (discount adjustments based on order total_amount)
- Only processes recent data (last 30 days) for efficiency

**See:** `GEN2_SETUP_GUIDE.md` for detailed setup, verification, troubleshooting, and automation with TASK

---

### DEMO 2: Dynamic Tables Pipeline

**What it demonstrates:**
- Incremental refresh (only process changes, not full datasets)
- Automatic dependency management (DOWNSTREAM cascading)
- Zero-maintenance orchestration (set once, runs forever)

**Quick start:**
```sql
-- Generate new orders via Snowpipe Streaming
-- See: snowpipe-streaming-java/ or snowpipe-streaming-python/

-- Manually refresh each tier (production: automatic!)
ALTER DYNAMIC TABLE enriched_orders REFRESH;
ALTER DYNAMIC TABLE fact_orders REFRESH;
ALTER DYNAMIC TABLE daily_business_metrics REFRESH;

-- Verify incremental refresh
SELECT name, refresh_action, duration_seconds
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(...));
```

**Key insight:** All refreshes show `INCREMENTAL` - only 500 new orders processed, not entire dataset!

**See:** `DEMO_SCRIPT.md` (Demo 2) for complete step-by-step guide

---

### DEMO 3: Interactive Tables & Warehouses

**What it demonstrates:**
- Sub-100ms query latency under high concurrency
- 3-10x performance improvement over standard warehouses
- Complete native stack (no Redis, no external API database)

**Quick start:**
```bash
cd interactive
./demo.sh --threads 150 --warehouse both
```

**Sample queries displayed:**
- CUSTOMER_LOOKUP (50%): Point lookup by customer_id
- ORDER_LOOKUP (30%): Point lookup by order_id  
- CUSTOMER_SUMMARY (20%): Aggregation by customer_id

**Expected results (150 threads, 500 queries, 21M orders):**

| Metric | Standard WH | Interactive WH | Improvement |
|--------|-------------|----------------|-------------|
| P95 | 6,897 ms | 2,119 ms | **3.3x faster** |
| Median | 4,254 ms | 945 ms | **4.5x faster** |
| Average | 4,221 ms | 1,083 ms | **3.9x faster** |

**See:** `interactive/README.md` for complete documentation

---

### DEMO 4: Snowpipe Streaming - Billion-Scale Ingestion

**What it demonstrates:**
- High-performance real-time ingestion (34K orders/second)
- Linear horizontal scaling (1 to 50+ parallel instances)
- Python AND Java implementations (identical functionality)

**Implementation Options:**

#### Option 1: Python (Recommended for Quick Start)
```bash
cd snowpipe-streaming-python

# Single instance (10K orders)
python src/automated_intelligence_streaming.py 10000

# Parallel (1M orders, 5 instances)
python src/parallel_streaming_orchestrator.py 1000000 5

# Large scale (10M orders, 10 instances)
python src/parallel_streaming_orchestrator.py 10000000 10
```

#### Option 2: Java
```bash
cd snowpipe-streaming-java

# Build
mvn clean install

# Single instance (10K orders)
java -jar target/automated-intelligence-streaming-1.0.0.jar 10000

# Parallel (1M orders, 5 instances)
java ParallelStreamingOrchestrator 1000000 5
```

**Performance benchmarks:**
- Single instance: 10K orders in 5-7 seconds
- 5 parallel: 1M orders in 45 seconds (100x faster than stored procedures)
- 10 parallel: 10M orders in 5 minutes (~34K orders/sec)
- Billion-scale: 1B orders in 30-60 minutes with 50+ instances

**See:** 
- Python: `snowpipe-streaming-python/README.md` and `COMPARISON.md`
- Java: `snowpipe-streaming-java/README.md`

---

### DEMO 5: Security & Governance - Row-Based Access Control

**What it demonstrates:**
- Transparent row-level security with AI agents
- Same agent, dramatically different answers based on role
- Zero application code changes

**The setup:**

| Role | States Visible | Revenue | Customers |
|------|---------------|---------|-----------|
| **ADMIN** | All 10 states | $733M | 20,200 |
| **WEST_COAST** | Only CA, OR, WA | $224M | 6,115 |

**Quick test:**
```sql
-- Window 1: Admin role
USE ROLE snowflake_intelligence_admin;
SELECT state, SUM(revenue) FROM orders GROUP BY state;
-- Shows: 10 states, $733M total

-- Window 2: West Coast role
USE ROLE west_coast_manager;
SELECT state, SUM(revenue) FROM orders GROUP BY state;
-- Shows: 3 states only, $224M total
```

**Key insight:** West Coast Manager doesn't even know other states exist - filtered at database level!

**See:** `security-and-governance/README.md` for setup and agent demos

---

### DEMO 6: Streamlit Dashboard - Real-Time Monitoring

**What it demonstrates:**
- Real-time pipeline monitoring (live ingestion metrics)
- Interactive query performance testing
- Pipeline health status (Dynamic Tables, Interactive Tables, data freshness)

**Quick start:**
```bash
cd streamlit-dashboard

# Local development
pip install streamlit snowflake-snowpark-python pandas
streamlit run streamlit_app.py --server.port 8501

# Open browser
http://localhost:8501
```

**Dashboard features:**
- **Live Ingestion**: 21.3M orders, 117M order items, real-time trends
- **Query Performance**: On-demand latency testing (avg, P95, distribution)
- **Pipeline Health**: Dynamic Tables status, Interactive Tables health, data freshness

**Use cases:**
- Run dashboard during Snowpipe Streaming demos to show live ingestion
- Monitor pipeline health during presentations
- Test Interactive Tables performance in real-time
- Display current data volumes and trends

**Deploy to Snowflake:**
```bash
# Upload to stage
snow stage copy streamlit_app.py @AUTOMATED_INTELLIGENCE.RAW.THE_DASHBOARD_STAGE \
  --overwrite -c dash-builder-si

# Create app
CREATE STREAMLIT AUTOMATED_INTELLIGENCE.RAW.PIPELINE_DASHBOARD
  FROM '@AUTOMATED_INTELLIGENCE.RAW.THE_DASHBOARD_STAGE'
  MAIN_FILE = 'streamlit_app.py';

ALTER STREAMLIT AUTOMATED_INTELLIGENCE.RAW.PIPELINE_DASHBOARD 
  SET QUERY_WAREHOUSE = AUTOMATED_INTELLIGENCE_WH;
```

**See:** `streamlit-dashboard/README.md` for detailed documentation

---

## 🔄 Running Demos Sequentially

### Recommended Order
1. **Snowpipe Streaming** - Shows high-scale ingestion capability
2. **Gen2 Warehouse Performance** - Shows next-gen MERGE/UPDATE performance from staged data
3. **Dynamic Tables** - Shows foundational transformation pipeline
4. **Interactive Tables** - Shows performance serving layer
5. **Security & Governance** - Shows enterprise security with AI
6. **Snowflake Intelligence** - Natural language queries via Cortex Agent

### Notes for Sequential Execution
- ✅ All demos share same base database (`AUTOMATED_INTELLIGENCE`)
- ✅ Schemas: `RAW` (source data), `DYNAMIC_TABLES` (transformations), `SEMANTIC` (semantic layer), `INTERACTIVE` (serving)
- ✅ Data is additive - each demo adds more orders without breaking others
- ✅ No cleanup needed between demos
- ⚠️ For RBAC demo, switch roles to demonstrate filtering
- ⚠️ For Snowflake Intelligence, use AI & ML > Snowflake Intelligence UI

### Track Data Growth
After running all demos:

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
SELECT 'dynamic_table: daily_business_metrics', COUNT(*) 
FROM AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES.DAILY_BUSINESS_METRICS
UNION ALL
SELECT 'interactive: customer_order_analytics', COUNT(*) 
FROM AUTOMATED_INTELLIGENCE.INTERACTIVE.CUSTOMER_ORDER_ANALYTICS
UNION ALL
SELECT 'semantic_views', COUNT(*) 
FROM INFORMATION_SCHEMA.SEMANTIC_VIEWS 
WHERE SEMANTIC_VIEW_SCHEMA = 'SEMANTIC'
ORDER BY table_name;
```

**Current volumes after testing:**
- Customers: 20,705
- Orders: 21,311,205 (21.3 million!)
- Order items: 117,193,989 (117 million!)

---

## 🎯 Complete Platform Summary

After running all demos, you've demonstrated:

**Data Ingestion:**
- ✅ Snowpipe Streaming: Sub-second latency, billion-scale ready, Python or Java

**Data Transformation:**
- ✅ Dynamic Tables: Incremental refresh, automatic dependencies, zero maintenance

**Data Serving:**
- ✅ Interactive Tables: Sub-100ms queries, high concurrency, no external cache

**Data Governance:**
- ✅ Row Access Policies: Transparent security, role-based filtering, agent-compatible

**AI-Powered Analytics:**
- ✅ Semantic Views: Business terminology mapping, verified queries, multi-source integration
- ✅ Cortex Agent: Natural language queries, intelligent orchestration, visualization
- ✅ Cortex Search: Semantic product discovery, description-based search

**Platform Benefits:**
- ✅ Fully native stack - no external systems required
- ✅ Set-and-forget automation - minimal operational overhead
- ✅ Linear scalability - from thousands to billions of records
- ✅ Enterprise-grade security - built into the data platform
- ✅ Natural language interface - business users query data without SQL

---

## 🤖 AI Observability (Optional Add-On)

### Evaluate AI-Powered Analytics Quality

Located in `agent-evaluation/`, this module provides comprehensive evaluation of RAG applications built on your streaming order data.

**What it does:**
- Creates EXTERNAL AGENT objects to track application versions
- Runs LLM-as-judge evaluations (Context Relevance, Groundedness, Answer Relevance, Correctness)
- Stores traces in `SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS`
- Visualizes results in Snowsight (AI & ML > Evaluations)

**Quick Start:**
```bash
cd agent-evaluation
./setup.sh
source venv/bin/activate
python evaluate_order_analytics.py
```

**See:** `agent-evaluation/README.md` for detailed documentation

---

## 📁 Project Structure

```
automated-intelligence/
├── setup.sql                   # Core setup script (run this first!)
│
├── tests/                      # Test notebooks and tutorials
│   ├── test_ai_functions.ipynb      # Interactive AI functions tutorial
│   ├── test_dynamic_tables.ipynb    # Dynamic Tables deep dive tutorial
│   ├── test_data_quality.sql        # Data quality validation
│   └── test_data_quality.ipynb      # Interactive DQ notebook
│
├── dbt-analytics/              # DBT analytical layer (batch processing)
│   ├── dbt_project.yml         # DBT project configuration
│   ├── profiles.yml            # Connection profile (uses env vars)
│   ├── models/
│   │   ├── staging/            # Staging views (stg_customers, stg_orders, etc.)
│   │   └── marts/              # Analytical marts
│   │       ├── customer/       # CLV, segmentation
│   │       ├── product/        # Affinity, recommendations
│   │       └── cohort/         # Retention analysis
│   └── README.md               # DBT setup and usage guide
│
├── snowflake-intelligence/     # Demo 2: Cortex AI & Analyst (component-specific setup)
│   ├── business_insights_semantic_model.yaml  # Semantic model definition
│   ├── create_semantic_model_stage.sql        # Stage for semantic model YAML
│   ├── create_agent.sql                       # Cortex Agent for NL queries
│   └── create_cortex_search.sql               # Cortex Search for product discovery
│
├── gen2-warehouse/             # Demo 1: Gen2 Warehouse (component-specific setup)
│   ├── setup_staging_pipeline.sql    # Staging schema, tables, Gen2 WH
│   ├── setup_merge_procedures.sql    # MERGE/UPDATE procedures with benchmarking
│   └── README.md               # Gen2 setup and demo instructions
│
├── interactive/                # Demo 3: Interactive Tables (component-specific setup)
│   ├── setup_interactive.sql   # Interactive tables and warehouse
│   ├── demo.sh                 # Main demo script
│   ├── load_test_interactive.py
│   ├── realtime_demo.py
│   └── README.md
│
├── snowpipe-streaming-python/  # Demo 4: Python implementation (component-specific setup)
│   ├── src/
│   │   ├── automated_intelligence_streaming.py
│   │   ├── parallel_streaming_orchestrator.py
│   │   ├── models.py
│   │   └── data_generator.py
│   ├── config_staging.properties      # Staging target config
│   ├── profile_staging.json           # Staging schema profile
│   ├── requirements.txt
│   └── README.md               # SDK setup and configuration instructions
│
├── snowpipe-streaming-java/    # Demo 4: Java implementation (component-specific setup)
│   ├── src/
│   ├── pom.xml
│   └── README.md               # SDK setup and configuration instructions
│
├── security-and-governance/    # Demo 5: RBAC (component-specific setup)
│   ├── setup_west_coast_manager.sql
│   ├── cleanup_west_coast_manager.sql
│   └── README.md
│
├── streamlit-dashboard/        # Demo 6: Real-time monitoring (component-specific setup)
│   ├── streamlit_app.py        # Main dashboard app
│   ├── pages/
│   │   ├── 1_data_pipeline.py  # Gen2 warehouse performance page
│   │   ├── 2_live_ingestion.py
│   │   ├── 3_pipeline_health.py
│   │   ├── 4_query_performance.py
│   │   ├── 5_ml_insights.py
│   │   └── 6_summary.py
│   ├── environment.yml         # Snowflake dependencies
│   └── README.md               # Streamlit setup and deployment
│
├── openflow-ingestion/         # Experimental: Openflow → Iceberg (untested)
│   └── README.md               # ⚠️ Reference implementation only
│
├── README.md                   # This file - Overview and quick start
└── demo_script.md              # Complete demo guide with talking points
```

---

## 🧹 Cleanup (After All Demos)

If you want to reset for another demo session:

```sql
-- Optional: Drop and recreate everything
DROP DATABASE automated_intelligence CASCADE;
DROP ROW ACCESS POLICY IF EXISTS automated_intelligence.raw.customers_region_policy;
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

### Demo Guides
- **DEMO_SCRIPT.md** - Complete demo guide with talking points for all demos
- **GEN2_QUICK_REFERENCE.md** - Quick reference for Gen2 warehouse performance demo (NEW!)
- **GEN2_SETUP_GUIDE.md** - Detailed Gen2 setup, verification, and automation guide (NEW!)
- **interactive/README.md** - Interactive Tables deep dive
- **snowpipe-streaming-python/README.md** - Python implementation guide
- **snowpipe-streaming-python/COMPARISON.md** - Python vs Java comparison
- **snowpipe-streaming-java/README.md** - Java implementation guide
- **security-and-governance/README.md** - RBAC setup and examples
- **streamlit-dashboard/README.md** - Dashboard deployment and usage

### Technical Documentation
- **Gen2 Warehouses**: SQL scripts for staging pipeline and MERGE procedures with benchmarking
- **Dynamic Tables**: SQL scripts and validation queries
- **Interactive Tables**: Performance benchmarks and best practices
- **Snowpipe Streaming**: Configuration, scaling patterns, troubleshooting

---

## ⚠️ Important Notes

### Dynamic Tables - Manual vs Scheduled Refresh

| Refresh Type | Cascades to DOWNSTREAM? | When Used |
|--------------|-------------------------|-----------|
| **Manual** | ❌ No - Must refresh each tier | Demos, testing, emergencies |
| **Scheduled** | ✅ Yes - Auto-cascades | Production (automatic) |

**In demos:** We manually refresh Tier 1 → Tier 2 → Tier 3 to show the flow step-by-step.

**In production:** Tier 1's scheduled refresh automatically triggers Tier 2 → Tier 3. Zero manual intervention!

### Dynamic Tables - Configuration & Data Freshness

#### 3-Tier Architecture

**Layer 1: Base Enrichment** (1 minute lag)
- `enriched_orders`: `TARGET_LAG = '1 minute'`
- `enriched_order_items`: `TARGET_LAG = '1 minute'`
- Reads from raw tables populated by Snowpipe Streaming

**Layer 2: Fact Tables** (Downstream)
- `fact_orders`: `TARGET_LAG = DOWNSTREAM`
- Refreshes immediately after Layer 1

**Layer 3: Metrics** (Downstream)
- `daily_business_metrics`: `TARGET_LAG = DOWNSTREAM`
- `product_performance_metrics`: `TARGET_LAG = DOWNSTREAM`
- Refreshes immediately after Layer 2

#### Data Freshness Flow
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

#### Default Configuration: Real-Time (1 Minute)

⚡ **Automatically applied by setup.sql** - No additional steps needed!

**Benefits:**
- Dashboard updates within 1-2 minutes
- Ideal for live demos and operational monitoring
- Only Layer 1 actively polls (Layers 2-3 cascade automatically)

**Cost:**
- ~1,440 warehouse refreshes/day (60/hour × 24 hours)
- Warehouse active ~1 minute per refresh
- **720x more credits** than 12-hour batch processing

#### Alternative: Batch Processing (12 Hours)

For lower costs in production:
```sql
ALTER DYNAMIC TABLE enriched_orders SET TARGET_LAG = '12 hours';
ALTER DYNAMIC TABLE enriched_order_items SET TARGET_LAG = '12 hours';
-- Downstream tables automatically adjust (still DOWNSTREAM)
```

**Cost difference:** 2 refreshes/day vs 1,440 refreshes/day

#### When to Use Each Configuration

| Use Case | Recommended Lag |
|----------|----------------|
| Live operational dashboard | 1 minute |
| Real-time fraud detection | 1 minute |
| Customer service tools | 1 minute |
| Executive daily reports | 12 hours |
| Weekly business reviews | 12 hours |
| Cost optimization | 12 hours |

#### Verify Your Configuration
```bash
for table in enriched_orders enriched_order_items fact_orders daily_business_metrics product_performance_metrics; do
  echo "=== $table ==="
  snow sql -c dash-builder-si --role snowflake_intelligence_admin -q \
    "SELECT GET_DDL('TABLE', 'automated_intelligence.dynamic_tables.$table');" | grep target_lag
done
```

### Interactive Warehouses

- ⚠️ **5-second query timeout** (cannot be increased)
- ⚠️ **Always-on billing** (no auto-suspend by design)
- ⚠️ **Preview feature** (select AWS regions only)

### Snowpipe Streaming

- Requires RSA key-pair authentication (PEM format)
- Python SDK is Rust-backed for high performance
- Both Python and Java deliver identical functionality and performance

### Gen2 Warehouses

- 10-40% performance improvements for MERGE/UPDATE/DELETE operations
- Create with `RESOURCE_CONSTRAINT = 'STANDARD_GEN_2'`
- Region availability: Check https://docs.snowflake.com/en/user-guide/warehouses-gen2#region-availability
- Snapshot/restore pattern ensures fair benchmarking (identical data state)

---

## 🎓 Learning Path

**New to the platform?** Follow this sequence:

1. **Start with setup** - Run all setup scripts once
2. **Demo 4: Snowpipe Streaming** - Scale ingestion to millions
3. **Demo 1: Gen2 Warehouse Performance** - See next-gen MERGE/UPDATE operations
4. **Demo 2: Dynamic Tables** - Understand the transformation layer
5. **Demo 3: Interactive Tables** - See the serving layer in action
6. **Demo 5: Security & Governance** - Lock down with row-level security
7. **Optional: AI Observability** - Evaluate AI analytics quality

**For executives:** Run the Full Suite (45-60 min) to show complete platform capabilities.

**For technical teams:** Deep dive into specific demos based on their domain (data engineering, app development, security, etc.)

---

**Remember: After one-time setup, all demos work independently and can be run in any order!** 🚀
