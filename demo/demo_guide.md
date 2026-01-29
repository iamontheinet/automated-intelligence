# Automated Intelligence: Demo Guide

## The Story

A retail company modernizes their entire data stack on Snowflake—from development to production AI. Three acts, one platform:

1. **Build** → Developer tools accelerate code-to-production
2. **Train** → GPU-powered ML with governed deployment
3. **Serve** → Hybrid data architecture powering conversational AI

---

## How It All Fits Together

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           DEMO 1: DEVELOPER TOOLS                           │
│                                                                             │
│   Cortex Code CLI ──→ VS Code Extension ──→ Snow CLI                        │
│   (AI generates)      (edit & browse)       (deploy & automate)             │
│         │                                                                   │
│         ▼                                                                   │
│   dbt models, SQL, Python code                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         DEMO 2: NOTEBOOKS + ML                              │
│                                                                             │
│   Workspaces (Git) ──→ Notebook vNext (GPU) ──→ Model Registry ──→ Service  │
│                              │                        │            Endpoint │
│                              ▼                        ▼                     │
│                     XGBoost Training         Versioned Models               │
│                     (gpu_hist)                       │                      │
│                                                      ▼                      │
│                                         create_service() on GPU pool        │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    DEMO 3: DATA + INTELLIGENCE                              │
│                                                                             │
│   ┌──────────────────┐      ┌──────────────────┐      ┌──────────────────┐  │
│   │ SNOWFLAKE        │      │ SNOWFLAKE        │      │ ICEBERG ON S3    │  │
│   │ POSTGRES         │ ───► │ (RAW tables)     │ ───► │ (open format)    │  │
│   │ (managed OLTP)   │ MERGE│                  │export│                  │  │
│   │                  │ sync │ product_reviews  │      │ product_reviews  │  │
│   │ product_reviews  │      │ support_tickets  │      │ support_tickets  │  │
│   │ support_tickets  │      │                  │      │                  │  │
│   └──────────────────┘      └────────┬─────────┘      └────────┬─────────┘  │
│                                      │                         │            │
│                                      ▼                         ▼            │
│                          Snowflake Intelligence           pg_lake           │
│                          ┌─────────────────────┐    (external Postgres)     │
│                          │ Cortex Analyst      │          │                 │
│                          │ Cortex Search       │          ▼                 │
│                          │ Custom ML Tools     │    Any Iceberg-compatible  │
│                          └──────────┬──────────┘    system can query this   │
│                                     │               data (Spark, Trino,     │
│                                     ▼               DuckDB, etc.)           │
│                                 REST API                                    │
└─────────────────────────────────────────────────────────────────────────────┘

**Two PostgreSQL instances, two purposes:**
| Instance | Type | Purpose |
|----------|------|--------|
| **Snowflake Postgres** | Managed (inside Snowflake) | OLTP workloads—fast transactional writes |
| **pg_lake** | External (Docker container) | Demonstrates Iceberg interoperability—external systems querying Snowflake data |
```

**The Thread:** Code written in Demo 1 → trains models in Demo 2 → powers intelligence in Demo 3.

---

## Demo 1: Developer Tools (5 min)

### Setup
- Terminal open
- VS Code with Snowflake extension installed
- Snow CLI configured

### Script

#### 0:00 - Cortex Code CLI (2 min)

**Open Cortex Code:**
```bash
cortex -c dash-connection-si
```

**Ask for SQL:**
```
> Show me top 10 customers by total spend
```
*Cortex Code generates and optionally runs:*
```sql
SELECT c.customer_id, c.first_name, c.last_name, SUM(o.total_amount) as total_spend
FROM AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS c
JOIN AUTOMATED_INTELLIGENCE.RAW.ORDERS o ON c.customer_id = o.customer_id
GROUP BY 1, 2, 3
ORDER BY total_spend DESC
LIMIT 10;
```

**Ask for dbt model:**
```
> Create a dbt model for customer lifetime value
```
*Generates full dbt SQL with CTEs, documentation, tests*

---

#### 2:00 - VS Code Extension (1.5 min)

**Show:**
1. **Object Explorer** - Browse databases, schemas, tables
2. **Query Editor** - Open `.sql` file, syntax highlighting
3. **Run Query** - Execute inline, results in panel
4. **Autocomplete** - Table/column suggestions

**Quick query:**
```sql
-- Run this in VS Code
SELECT COUNT(*) as order_count, SUM(total_amount) as revenue
FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS
WHERE order_date >= DATEADD(day, -30, CURRENT_DATE);
```

---

#### 3:30 - Snow CLI (1.5 min)

**List tables:**
```bash
snow object list table --in schema RAW
```

**Run query:**
```bash
snow sql -q "SELECT COUNT(*) FROM AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS"
```

**Run Streamlit app locally:**
```bash
cd streamlit-dashboard
streamlit run streamlit_app.py --server.port 8501
```

**Deploy to Snowflake:**
```bash
snow streamlit deploy the_dashboard --replace -c dash-builder-si
```

**Transition:** *"Now let's see how we train ML models using these same tools..."*

---

## Demo 2: Notebooks vNext + ML (5 min)

### Setup
- Workspace open in Snowsight
- ML notebook ready
- Model already trained (for time)

### Script

#### 0:00 - Workspaces (1 min)

**Show:**
1. **Git Integration** - Connected repo, branch selector
2. **File Explorer** - dbt project, notebooks, SQL files
3. **Collaboration** - Multiple users can work on same project

**Navigate to:** `ml-training/product_recommendations.ipynb`

---

#### 1:00 - Notebook vNext (2 min)

**Highlight:**
1. **Compute Selector** - Show GPU option (NVIDIA A10G)
2. **Container Runtime** - Python packages pre-installed

**Show training cell:**
```python
# GPU-accelerated XGBoost
model = XGBClassifier(
    n_estimators=1000,
    max_depth=20,
    tree_method='gpu_hist',  # ← GPU acceleration
    predictor='gpu_predictor'
)
model.fit(X_train, y_train)
```

**Show results:**
- Training time: ~30 seconds (vs 5+ min on CPU)
- F1 Score: 0.977

---

#### 3:00 - Model Registry (1 min)

**Show registration cell:**
```python
from snowflake.ml.registry import Registry

registry = Registry(session=session)
model_ref = registry.log_model(
    model=model,
    model_name="PRODUCT_RECOMMENDATION_MODEL",
    version_name=f"v_{timestamp}",
    sample_input_data=X_train,
    target_platforms=["WAREHOUSE", "SNOWPARK_CONTAINER_SERVICES"]
)
```

**Navigate to Model Registry UI:**
- Show version history
- Show metrics (F1, precision, recall)
- Show lineage

---

#### 4:00 - Service Endpoint (1 min)

**Show service creation:**
```python
# Create service endpoint on GPU compute pool
mv.create_service(
    service_name="gpu_xgboost_service",
    service_compute_pool="SYSTEM_COMPUTE_POOL_GPU",
    ingress_enabled=True,
    gpu_requests="1"
)
```

**Call endpoint:**
```python
# Load and predict via registry
model_ref = registry.get_model('product_recommendation_xgboost').version('latest')
loaded_model = model_ref.load()
predictions = loaded_model.predict_proba(customer_features)
```

**Transition:** *"Now let's see this model in action, powering our conversational AI..."*

---

## Demo 3: Postgres → Intelligence (5 min)

### Setup
- Terminal with psql or Python ready
- pg_lake container running
- Snowflake Intelligence open

### Script

#### 0:00 - Snowflake Postgres (1 min)

**Insert a review (simulating OLTP):**
```bash
cd /Users/ddesai/Apps/automated-intelligence/snowflake-postgres
SNOWFLAKE_CONNECTION_NAME=dash-builder-si python insert_product_reviews.py
```

**Query Postgres directly:**
```sql
-- Via Snowflake
SELECT * FROM TABLE(pg_query('SELECT * FROM product_reviews ORDER BY created_at DESC LIMIT 5'));
```

**Show:** New review appears with AI-generated content

---

#### 1:00 - MERGE Sync & Iceberg Export (30 sec)

**How, Why, When:**

| Step | Task | Source → Target | Schedule |
|------|------|-----------------|----------|
| **1. Postgres Sync** | `POSTGRES_SYNC_TASK` | Snowflake Postgres → RAW tables | Every 5 min |
| **2. Iceberg Export** | `PG_LAKE_REFRESH_TASK` | RAW tables → Iceberg on S3 | Every 5 min |

**Show sync tasks:**
```sql
-- Both tasks run every 5 minutes
SHOW TASKS LIKE '%SYNC%' IN SCHEMA AUTOMATED_INTELLIGENCE.POSTGRES;
SHOW TASKS LIKE '%REFRESH%' IN SCHEMA AUTOMATED_INTELLIGENCE.PG_LAKE;

-- See task execution history
SELECT NAME, STATE, SCHEDULED_TIME FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE NAME IN ('POSTGRES_SYNC_TASK', 'PG_LAKE_REFRESH_TASK')
ORDER BY SCHEDULED_TIME DESC LIMIT 5;
```

**The MERGE pattern (both tasks use MERGE):**
```sql
-- Task 1: Postgres → RAW (SYNC_POSTGRES_TO_SNOWFLAKE procedure)
MERGE INTO RAW.PRODUCT_REVIEWS AS target
USING TABLE(pg_query('SELECT * FROM product_reviews')) AS source
ON target.review_id = source.review_id
WHEN MATCHED THEN UPDATE SET ...
WHEN NOT MATCHED THEN INSERT ...;

-- Task 2: RAW → Iceberg (PG_LAKE_REFRESH_TASK)
MERGE INTO PG_LAKE.PRODUCT_REVIEWS AS target
USING RAW.PRODUCT_REVIEWS AS source
ON target.review_id = source.review_id
WHEN MATCHED THEN UPDATE SET ...
WHEN NOT MATCHED THEN INSERT ...;
```

**Verify sync:**
```sql
-- Compare counts: Postgres vs Snowflake RAW vs Iceberg
SELECT 'Postgres' as source, COUNT(*)::INT as count FROM TABLE(pg_query('SELECT COUNT(*) FROM product_reviews'))
UNION ALL
SELECT 'Snowflake RAW', COUNT(*) FROM AUTOMATED_INTELLIGENCE.RAW.PRODUCT_REVIEWS
UNION ALL
SELECT 'Iceberg', COUNT(*) FROM AUTOMATED_INTELLIGENCE.PG_LAKE.PRODUCT_REVIEWS;
```

---

#### 1:30 - pg_lake: Iceberg Interoperability (1 min)

**What is pg_lake?**
> An *external* PostgreSQL instance (not Snowflake Postgres) that can read Iceberg tables directly from S3. This demonstrates how ANY Iceberg-compatible system can access Snowflake data.

**The data path (with timing):**
```
Snowflake Postgres    →    Snowflake RAW     →    Iceberg on S3    →    pg_lake
   (writes)            POSTGRES_SYNC_TASK    PG_LAKE_REFRESH_TASK     (reads anytime)
       │                   (5 min)               (5 min)                   │
   OLTP app                 Analytics          Open format            External
   inserts here            queries here        stored here            reads here
```

**Connect to external Postgres (pg_lake):**
```bash
# This is a separate Postgres running in Docker, NOT Snowflake Postgres
docker exec -it pg_lake psql -U postgres
```

**Query Snowflake data from external Postgres:**
```sql
-- pg_lake reads Iceberg metadata from S3, no Snowflake connection needed
SELECT rating, COUNT(*) as count
FROM product_reviews
GROUP BY rating
ORDER BY rating DESC;

-- Prove it's the same data
SELECT COUNT(*) FROM product_reviews;  -- Should match Snowflake count
```

**Why this matters:**
- Data written to Snowflake is instantly available to external systems
- No ETL, no data copy, no vendor lock-in
- Spark, Trino, DuckDB, Presto—any Iceberg reader works
- *"True lakehouse: open formats, universal access"*

---

#### 2:30 - Snowflake Intelligence (2 min)

**Open Intelligence UI**

**Question 1 (Analyst - text-to-SQL):**
```
What are the top 5 products by revenue this month?
```
*Shows SQL generation, execution, formatted results*

**Question 2 (Search - semantic):**
```
What are customers saying about Ski Boots?
```
*Retrieves relevant reviews, summarizes sentiment*

**Question 3 (Custom Tool - ML):**
```
What products should we recommend to customer 291521?
```
*Invokes ML model, returns personalized recommendations*

---

#### 4:30 - REST API (30 sec)

**Call Intelligence programmatically:**
```bash
curl -X POST "https://<account>.snowflakecomputing.com/api/v2/cortex/agent:run" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "agent_name": "AUTOMATED_INTELLIGENCE.SEMANTIC.DATA_AGENT",
    "query": "How many orders were placed last week?"
  }'
```

**Show JSON response** with SQL, results, and natural language answer.

---

## Closing (30 sec)

> **"One platform. From code to production AI. Developer tools that accelerate building, notebooks that train at GPU speed, and an intelligence layer that makes it all accessible—entirely within Snowflake."**

---

## Backup Commands

### If Postgres insert fails:
```sql
CALL pg_exec('INSERT INTO product_reviews (customer_id, product_id, product_name, rating, review_text) VALUES (12345, 1005, ''Ski Boots'', 5, ''Amazing quality!'')');
```

### If pg_lake container not running:
```bash
cd /Users/dashdesai/Apps/automated-intelligence/pg_lake
./setup.sh  # Fetches latest Iceberg paths and starts containers
```

### Check Intelligence agent status:
```sql
SHOW CORTEX AGENTS IN SCHEMA AUTOMATED_INTELLIGENCE.SEMANTIC;
```

---

## Key Differentiators to Emphasize

| Traditional | Snowflake |
|-------------|-----------|
| Multiple IDEs + manual coding | Cortex Code generates code from natural language |
| Separate ML infrastructure | Notebooks with GPU, registry, deployment—all native |
| ETL pipelines between OLTP/OLAP | Automatic MERGE sync, Iceberg interoperability |
| Chatbot requires custom dev | Intelligence orchestrates Analyst + Search + ML |
| APIs require separate backend | REST API built-in |
| Secrets stored in CI/CD | Workload Identity Federation (zero secrets) |

---

## Bonus Demo: Workload Identity Federation (30 sec)

**The Problem:** Storing Snowflake credentials in GitHub Secrets is a security risk.

**The Solution:** OIDC-based authentication with zero secrets.

### Quick Demo Flow

1. **Show GitHub Secrets page**: "No Snowflake credentials stored!"
2. **Trigger workflow**: Actions → "❄️ Snowflake OIDC Demo" → Run workflow
3. **Watch output**:
   ```
   ✅ Authenticated as: GITHUB_ACTIONS_DBT
   ✅ Using role: SNOWFLAKE_INTELLIGENCE_ADMIN
   
   🎯 LIVE DATA FROM SNOWFLAKE
   ==================================================
      Customers:     20,505
      Total Revenue: $8,234,567.89
   ==================================================
   
   ✅ Zero secrets stored in repository!
   ```

### How It Works

```sql
-- SERVICE user trusts GitHub's OIDC provider
CREATE USER github_actions_dbt
WORKLOAD_IDENTITY = (
  TYPE = OIDC
  ISSUER = 'https://token.actions.githubusercontent.com'
  SUBJECT = 'repo:iamontheinet/automated-intelligence:ref:refs/heads/main'
)
TYPE = SERVICE;
```

**Key points:**
- GitHub vouches for the workflow identity
- Snowflake validates the JWT token
- No passwords, keys, or secrets exchanged
- Token expires in 10 minutes (not permanent)

**Supported platforms:** GitHub Actions, AWS IAM (EC2/Lambda), EKS, AKS, GKE

> See `workload-identity/` folder for full setup instructions.

### Known Limitation

dbt-snowflake does not yet support Workload Identity Federation. Use Python connector directly for OIDC demos.
