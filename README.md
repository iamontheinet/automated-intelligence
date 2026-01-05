# Automated Intelligence Platform - Complete Demo Suite

## 🎯 Overview

This comprehensive demo platform showcases Snowflake's Automated Intelligence capabilities through interconnected demos that demonstrate a complete data pipeline - from ingestion to serving to governance:

1. **Gen2 Warehouse Performance** - Next-generation MERGE/UPDATE operations (10-40% faster)
2. **Dynamic Tables Pipeline** - Zero-maintenance incremental transformations
3. **Interactive Tables & Warehouses** - High-concurrency serving layer (<100ms queries)
4. **Snowpipe Streaming** - Billion-scale real-time ingestion (Python + Java)
5. **Security & Governance** - Row-based access control with AI agents
6. **ML Training** - Ray distributed training for customer churn prediction
7. **DBT Analytics** - Batch analytical models (CLV, segmentation, cohorts)
8. **Streamlit Dashboard** - Real-time monitoring of ingestion and performance
9. **Snowflake Intelligence** - Natural language queries with Cortex Agent

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
│  DEMO 1: STAGING & TRANSFORMATION LAYER                           │
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
│  DEMO 6: ML TRAINING LAYER                                       │
│  Ray on Snowflake → Distributed ML training                     │
│  • XGBoost churn prediction model                               │
│  • Distributed across 4-node Ray cluster                        │
│  • Model Registry integration                                   │
└──────────────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────────────┐
│  DEMO 7: ANALYTICAL LAYER                                        │
│  DBT Analytical Models → Batch processing                       │
│  • Customer lifetime value & segmentation                       │
│  • Product affinity & recommendations                          │
│  • Monthly cohort retention analysis                           │
└──────────────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────────────┐
│  SEMANTIC LAYER & AI INTERFACE                                   │
│  Semantic Views + Cortex Agent → Natural language queries       │
│  • Business terminology mapping                                  │
│  • Verified query repository (VQR)                              │
│  • Multi-source integration                                      │
└──────────────────────────────────────────────────────────────────┘
```

---

## 📋 Prerequisites

Before starting, ensure you have:

### 1. Snowflake Account Requirements
- **Account**: Snowflake Enterprise or higher
- **Cloud Provider**: AWS, Azure, or GCP (check feature availability by region)
- **Role**: `ACCOUNTADMIN` or custom role with necessary privileges:
  - CREATE DATABASE, CREATE SCHEMA, CREATE WAREHOUSE
  - CREATE TABLE, CREATE DYNAMIC TABLE, CREATE PROCEDURE
  - CREATE STREAMLIT, CREATE MODEL, CREATE NOTEBOOK
  - USAGE on DATABASE, SCHEMA, WAREHOUSE
- **Features**: Ensure these features are enabled:
  - Dynamic Tables
  - Interactive Warehouses (preview - select AWS regions)
  - Gen2 Warehouses (check region availability)
  - Snowflake ML (for model registry and Ray)
  - Snowpipe Streaming SDK
  - Cortex AI (Analyst, Agent, Search)

### 2. Tools & Software
- **Snowflake CLI**: Latest version for deployment
  ```bash
  # Install via pip
  pip install snowflake-cli-labs
  
  # Verify installation
  snow --version
  ```
- **Python**: 3.8 or higher (for Snowpipe Streaming, Streamlit, DBT)
- **Java**: JDK 11 or higher (optional - only for Java Snowpipe Streaming)
- **Git**: For cloning and version control

### 3. Credentials & Authentication
- **Snowflake Connection**: Configure using Snowflake CLI
  ```bash
  # Add a new connection
  snow connection add
  
  # Or use existing connection
  snow connection list
  ```
- **RSA Key Pair**: Required for Snowpipe Streaming (both Python and Java)
  - Generate key pair in PEM format (unencrypted)
  - Upload public key to Snowflake user account
  - See `snowpipe-streaming-python/README.md` for detailed instructions

### 4. Regional Feature Availability
Verify these features are available in your Snowflake region:
- **Interactive Warehouses**: Limited AWS regions (preview)
- **Gen2 Warehouses**: [Check availability](https://docs.snowflake.com/en/user-guide/warehouses-gen2#region-availability)
- **Container Runtime** (for Ray): Required for ML training notebooks

---

## 🚀 Quick Start - One-Time Setup

### Core Setup (Required for All Demos)

Run this script **once** to set up shared infrastructure:

```bash
# Core infrastructure (database, schemas, warehouse, tables, dynamic tables)
snow sql -f setup.sql -c <your-connection-name>

# What this creates:
# - Database: AUTOMATED_INTELLIGENCE
# - Schemas: RAW, STAGING, DYNAMIC_TABLES, INTERACTIVE, SEMANTIC, MODELS, DBT_STAGING, DBT_ANALYTICS
# - Warehouse: AUTOMATED_INTELLIGENCE_WH (SMALL, auto-suspend 60s)
# - Tables: customers, orders, order_items, product_catalog, support_tickets, product_reviews
# - Stored procedures: generate_orders(), generate_customers()
# - Dynamic Tables: 5-tier pipeline (enriched → fact → metrics)
# - Staging procedures: merge_staging_to_raw(), enrich_raw_data()
```

**Important Notes:**
- Replace `<your-connection-name>` with your Snowflake connection name
- This script includes a **WIPE SLATE** section that drops all existing objects
- Review the script before running if you have existing data
- The setup creates `dbt_staging` and `dbt_analytics` schemas for DBT models

### Optional: Analytical Layer Setup (DBT)

For batch analytical models (CLV, segmentation, cohorts):

```bash
cd dbt-analytics

# Install dbt-snowflake
pip install dbt-snowflake

# Install dependencies
dbt deps

# Test connection
dbt debug

# Build all models (creates tables in dbt_staging and dbt_analytics schemas)
dbt build

# Expected output: 4 staging views + 5 marts tables = 9 models
```

See `dbt-analytics/README.md` and `dbt-analytics/DEPLOYMENT.md` for detailed setup and production deployment.

### Optional: ML Training Setup

For Ray distributed ML training:

```bash
cd ml-training

# Deploy notebook to Snowflake
snow notebook create customer_churn_training \
  --database AUTOMATED_INTELLIGENCE \
  --schema MODELS \
  --file customer_churn_training.ipynb \
  --connection <your-connection-name>

# Then run in Snowsight UI: Projects > Notebooks > customer_churn_training
```

**Prerequisites:**
- Container Runtime enabled in your account
- Medium or Large warehouse recommended
- Interactive Tables populated (for training data)

See `ml-training/README.md` for detailed setup and usage.

### Optional: Snowflake Intelligence Setup

For natural language queries and semantic search:

See `snowflake-intelligence/README.md` for Cortex Agent, Cortex Search, and semantic model setup.

### Component-Specific Setup (Run Only What You Need)

Each demo has its own setup. Run only the ones you plan to use:

```bash
# Demo 1: Gen2 Warehouse Performance
snow sql -f gen2-warehouse/setup_staging_pipeline.sql -c <your-connection-name>
snow sql -f gen2-warehouse/setup_merge_procedures.sql -c <your-connection-name>
# See gen2-warehouse/README.md for details

# Demo 2: Dynamic Tables
# (No additional setup - covered by core setup.sql)

# Demo 3: Interactive Tables
snow sql -f interactive/setup_interactive.sql -c <your-connection-name>
# See interactive/README.md for details

# Demo 4: Snowpipe Streaming
# Requires RSA key generation and SDK setup
# See snowpipe-streaming-java/README.md or snowpipe-streaming-python/README.md

# Demo 5: Security & Governance
snow sql -f security-and-governance/setup_west_coast_manager.sql -c <your-connection-name>
# See security-and-governance/README.md for details

# Demo 6: ML Training
# Deploy notebook to Snowflake (see ml-training/README.md)

# Demo 7: DBT Analytics
cd dbt-analytics
dbt build  # Or use native deployment (see dbt-analytics/DEPLOYMENT.md)

# Demo 8: Streamlit Dashboard
cd streamlit-dashboard
streamlit run streamlit_app.py --server.port 8501
# See streamlit-dashboard/README.md for Python environment setup and deployment

# Demo 9: Snowflake Intelligence
# See snowflake-intelligence/README.md for setup
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
| **6. ML Training** | 10-15 min | ML Engineers, Data Scientists | Distributed training with Ray |
| **7. DBT Analytics** | 10-15 min | Analytics Engineers | Batch analytical models |
| **8. Streamlit Dashboard** | Continuous | Everyone | Real-time pipeline monitoring |
| **9. Snowflake Intelligence** | 10-15 min | Business Users, Analysts | Natural language queries |
| **Full Suite** | 90-120 min | Executive Demos, All-Hands | Complete platform capabilities |

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

**See:** `gen2-warehouse/README.md` for detailed setup, verification, troubleshooting, and automation with TASK

---

### DEMO 6: ML Training - Ray Distributed Training

**What it demonstrates:**
- Distributed ML training using Ray on Snowflake
- XGBoost customer churn prediction model
- Snowflake Model Registry integration
- Ray cluster scaling (1 head + 3 workers = 4 nodes)

**Quick start:**
```bash
# 1. Ensure Interactive Tables are populated (for training data)
# 2. Deploy notebook to Snowflake
cd ml-training
snow notebook create customer_churn_training \
  --database AUTOMATED_INTELLIGENCE \
  --schema MODELS \
  --file customer_churn_training.ipynb \
  --connection <your-connection-name>

# 3. Open in Snowsight: Projects > Notebooks > customer_churn_training
# 4. Select Medium or Large warehouse
# 5. Run all cells sequentially
```

**Model details:**
- **Features**: 6 customer behavior metrics (frequency, monetary, tenure)
- **Target**: Binary classification (churned vs active)
- **Churn definition**: No order in 7+ days (demo threshold)
- **Data leakage prevention**: Excludes recency features
- **Class imbalance handling**: Uses scale_pos_weight for 27:1 ratio

**Expected results:**
- **ROC-AUC**: 0.90-0.96 (Excellent)
- **Churned recall**: 80-90% (catches most at-risk customers)
- **Training time**: 1-3 minutes on Medium warehouse
- **Top feature**: Customer tenure (90% importance)

**Key insights:**
- Ray cluster distributes training across multiple nodes for faster processing
- Model saved to Snowflake Model Registry with version tracking
- Results visualized in Streamlit dashboard (ML Insights page)
- Production-ready: Schedule notebook runs for regular retraining

**See:** `ml-training/README.md` for detailed setup, configuration, and troubleshooting

---

### DEMO 7: DBT Analytics - Batch Analytical Models

**What it demonstrates:**
- Batch-processed analytical models complementing real-time Dynamic Tables
- Customer lifetime value and segmentation
- Product affinity and recommendations
- Monthly cohort retention analysis

**Quick start:**
```bash
cd dbt-analytics

# Local development
pip install dbt-snowflake
dbt deps
dbt debug  # Test connection
dbt build  # Build all models

# Snowflake native deployment
snow dbt deploy automated_intelligence_dbt_project \
  --connection <your-connection-name> \
  --force

snow dbt execute automated_intelligence_dbt_project \
  --connection <your-connection-name> \
  --args "build --target dev"
```

**Models created:**
- **Staging** (4 views in `dbt_staging` schema): stg_customers, stg_orders, stg_order_items, stg_products
- **Customer marts** (2 tables in `dbt_analytics` schema): customer_lifetime_value, customer_segmentation
- **Product marts** (2 tables): product_affinity, product_recommendations
- **Cohort marts** (1 table): monthly_cohorts

**Key insights:**
- Complements real-time Dynamic Tables with deep analytical queries
- RFM-based customer segmentation (Recency, Frequency, Monetary)
- Market basket analysis for product recommendations
- Cohort retention tracking for growth analysis

**Integration with real-time pipeline:**
| Layer | Technology | Refresh | Purpose |
|-------|-----------|---------|---------|
| Real-Time | Dynamic Tables | 1-min lag | Operational dashboards, live metrics |
| Analytical | dbt | Daily batch | Deep analytics, ML features, segmentation |

**See:** `dbt-analytics/README.md` for model details and `dbt-analytics/DEPLOYMENT.md` for production deployment

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

### DEMO 8: Streamlit Dashboard - Real-Time Monitoring

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
- **Data Pipeline**: Gen2 warehouse performance testing and benchmarking
- **Live Ingestion**: 21.3M orders, 117M order items, real-time trends
- **Pipeline Health**: Dynamic Tables status, data freshness
- **Query Performance**: On-demand latency testing (avg, P95, distribution)
- **ML Insights**: Model metrics, feature importance, churn predictions

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
5. **ML Training** - Shows distributed training with Ray on customer data
6. **DBT Analytics** - Shows batch analytical models (CLV, segmentation, cohorts)
7. **Security & Governance** - Shows enterprise security with AI
8. **Snowflake Intelligence** - Natural language queries via Cortex Agent

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
- ✅ Gen2 Warehouses: 10-40% faster MERGE/UPDATE/DELETE operations
- ✅ Dynamic Tables: Incremental refresh, automatic dependencies, zero maintenance

**Data Serving:**
- ✅ Interactive Tables: Sub-100ms queries, high concurrency, no external cache

**Data Governance:**
- ✅ Row Access Policies: Transparent security, role-based filtering, agent-compatible

**ML & Analytics:**
- ✅ Ray on Snowflake: Distributed ML training, model registry integration
- ✅ DBT Analytics: Customer segmentation, product affinity, cohort analysis

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

## 🔧 Troubleshooting Common Issues

### Setup Issues

**Issue: Connection errors when running setup.sql**
```
Solution: Verify your Snowflake connection
- Check connection name: snow connection list
- Test connection: snow connection test -c <connection-name>
- Verify role has necessary privileges (see Prerequisites section)
```

**Issue: "Object already exists" errors during setup**
```
Solution: The setup.sql script includes a WIPE SLATE section
- Review what will be dropped (lines 19-112 in setup.sql)
- If you have existing data, back it up first
- The script drops and recreates all objects
```

**Issue: DBT schemas not created**
```
Solution: Ensure you're using the updated setup.sql
- setup.sql should create dbt_staging and dbt_analytics schemas (lines 128-129)
- Manually create if missing:
  CREATE SCHEMA IF NOT EXISTS automated_intelligence.dbt_staging;
  CREATE SCHEMA IF NOT EXISTS automated_intelligence.dbt_analytics;
```

### Snowpipe Streaming Issues

**Issue: RSA key authentication failures**
```
Solution: Verify RSA key pair setup
1. Check key format (must be PEM, unencrypted)
2. Verify public key uploaded to Snowflake user:
   DESC USER <username>;
   -- Check RSA_PUBLIC_KEY_FP field
3. Ensure private key path in config is correct
4. See snowpipe-streaming-python/README.md for detailed setup
```

**Issue: "Channel not found" or connection errors**
```
Solution: Verify target tables exist
- Tables must exist before streaming
- Check table names in config match actual tables
- Verify role has INSERT privilege on target tables
```

### Gen2 Warehouse Issues

**Issue: Gen2 warehouse creation fails**
```
Solution: Check region availability
- Gen2 warehouses not available in all regions
- See: https://docs.snowflake.com/en/user-guide/warehouses-gen2#region-availability
- Use standard warehouse if Gen2 not available (performance gains won't apply)
```

**Issue: Snapshot/restore procedures fail**
```
Solution: Verify staging tables exist
- Run gen2-warehouse/setup_staging_pipeline.sql first
- Check tables: staging.orders_staging, staging.order_items_staging
- Verify staging.discount_snapshot table exists
```

### Interactive Warehouses Issues

**Issue: Interactive warehouse creation fails**
```
Solution: Check preview availability
- Interactive warehouses are in preview (select AWS regions only)
- Not available in all accounts/regions
- Skip this demo if not available
```

**Issue: Queries timeout at 5 seconds**
```
Solution: This is by design
- Interactive warehouses have fixed 5-second timeout
- Cannot be increased
- Optimize queries or use standard warehouses for complex queries
```

### ML Training Issues

**Issue: Ray cluster won't scale**
```
Solution: Check Container Runtime
- Verify enabled: SHOW PARAMETERS LIKE 'ENABLE_CONTAINER_RUNTIME' IN ACCOUNT;
- Contact Snowflake support if not enabled
- Requires Medium or Large warehouse
```

**Issue: Notebook deployment fails**
```
Solution: Verify paths and permissions
- Check database and schema exist
- Verify role has CREATE NOTEBOOK privilege
- Use absolute path to notebook file
```

**Issue: Model not appearing in registry**
```
Solution: Check schema permissions
- MODELS schema must exist (created by setup.sql)
- Grant CREATE MODEL privilege to your role
- Check model name: SELECT * FROM INFORMATION_SCHEMA.MODEL_VERSIONS;
```

### DBT Issues

**Issue: dbt deps fails**
```
Solution: Check internet connectivity and packages
- Verify packages.yml exists
- Try: dbt clean && dbt deps
- Check proxy settings if behind firewall
```

**Issue: "Relation does not exist" errors**
```
Solution: Verify source tables exist
- Run core setup.sql first
- Check: SELECT * FROM automated_intelligence.raw.orders LIMIT 1;
- Verify connection profile points to correct database
```

**Issue: All customers show as high_value**
```
Solution: Adjust thresholds in dbt_project.yml
- high_value_threshold: 17500 (75th percentile)
- active_customer_days: 21 (median recency)
- Rebuild models: dbt run --select customer_lifetime_value customer_segmentation
```

### Streamlit Dashboard Issues

**Issue: Connection errors in Streamlit**
```
Solution: Check environment variables or connection config
- If local: Ensure SNOWFLAKE_CONNECTION_NAME env var set
- If deployed: Verify connection in Snowsight
- Check warehouse exists and is accessible
```

**Issue: "Table does not exist" errors**
```
Solution: Verify all components are set up
- Run core setup.sql
- Run component-specific setup scripts
- Check table exists: SHOW TABLES IN automated_intelligence.raw;
```

**Issue: ML Insights page shows no models**
```
Solution: Train ML model first
- Deploy and run ml-training/customer_churn_training.ipynb
- Verify model exists: SELECT * FROM INFORMATION_SCHEMA.MODEL_VERSIONS;
- Model must be in AUTOMATED_INTELLIGENCE.MODELS schema
```

### Performance Issues

**Issue: Dynamic Tables not refreshing**
```
Solution: Check target lag and refresh schedule
- Verify lag: SELECT GET_DDL('TABLE', 'automated_intelligence.dynamic_tables.enriched_orders');
- Check last refresh: SELECT * FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(...));
- Manual refresh: ALTER DYNAMIC TABLE enriched_orders REFRESH;
```

**Issue: Queries running slow**
```
Solution: Multiple factors
- Check warehouse size (may need to scale up)
- Verify clustering keys on large tables
- Check query profile in Snowsight for bottlenecks
- For Interactive Tables, ensure using interactive warehouse
```

### Data Quality Issues

**Issue: Product categories don't match product names**
```
Solution: Old data may have this issue
- Fixed in setup.sql (lines 181-216)
- Generate fresh data: CALL automated_intelligence.raw.generate_orders(1000);
- New data will have consistent product relationships
```

**Issue: Referential integrity violations**
```
Solution: Fixed in current version
- Update to latest setup.sql
- Stored procedures now generate consistent data
- Verify: Run tests/test_data_quality.sql
```

### General Tips

1. **Check Snowflake CLI version**: `snow --version` (update if old)
2. **Verify role privileges**: Use ACCOUNTADMIN or role with full privileges
3. **Review object dependencies**: Use GET_DDL() to see object definitions
4. **Check query history**: SELECT * FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY()) for errors
5. **Monitor costs**: Review warehouse credit usage if running large-scale tests

For component-specific issues, see the README in each subdirectory.

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
- **Prerequisites**: Snowflake account requirements, tools, credentials (see Prerequisites section above)
- **Setup Scripts**: `setup.sql` (core infrastructure), component-specific scripts
- **Connection Guide**: Snowflake CLI configuration for your connection

### Demo Guides
- **DEMO_SCRIPT.md** - Complete demo guide with talking points for all demos
- **gen2-warehouse/README.md** - Gen2 warehouse performance demo and setup
- **interactive/README.md** - Interactive Tables deep dive
- **ml-training/README.md** - Ray ML training setup and usage
- **dbt-analytics/README.md** - DBT setup and model details
- **dbt-analytics/DEPLOYMENT.md** - Production DBT deployment guide
- **snowpipe-streaming-python/README.md** - Python implementation guide
- **snowpipe-streaming-python/COMPARISON.md** - Python vs Java comparison
- **snowpipe-streaming-java/README.md** - Java implementation guide
- **security-and-governance/README.md** - RBAC setup and examples
- **streamlit-dashboard/README.md** - Dashboard deployment and usage
- **snowflake-intelligence/README.md** - Cortex Agent, Analyst, Search setup

### Technical Documentation
- **Gen2 Warehouses**: SQL scripts for staging pipeline and MERGE procedures with benchmarking
- **Dynamic Tables**: SQL scripts and validation queries
- **Interactive Tables**: Performance benchmarks and best practices
- **Snowpipe Streaming**: Configuration, scaling patterns, troubleshooting
- **ML Training**: Ray cluster configuration, model hyperparameters, troubleshooting
- **DBT Analytics**: Model schemas, tests, materialization strategies

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
