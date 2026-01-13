## Dash's BUILD London 2026 Keynote Demos

### Overview

**Use Case:** A retail company modernizing their data stack on Snowflake—from development to production AI.

Build analytics pipelines faster with AI-powered developer tools. Train product recommendation models with GPU-accelerated notebooks. Unify transactional and analytical workloads via hybrid Postgres + Snowflake architecture—all accessible through natural language with Snowflake Intelligence.


### Features

**DEMO 1: Developer Tools**
- Cortex Code CLI → Generate SQL queries and dbt models from natural language (AI-assisted code generation)
- VS Code Extension → Browse objects, edit SQL, run queries inline (familiar IDE experience)
- Snow CLI → List tables, run ad-hoc queries, deploy stored procedures (CLI automation)

**DEMO 2: Notebooks + ML**
- Workspaces (Git) → Navigate repo, show dbt project and notebooks (version-controlled collaboration)
- Notebook vNext (GPU) → Train XGBoost on GPU compute pool
- Model Registry → Register model with metrics and versioning (governed ML lifecycle)
- Service Endpoint → Deploy model as scalable inference API for Snowflake Intelligence (production serving)

**DEMO 3: Data + Intelligence**
- Snowflake Postgres → Product reviews and Support tickets (managed OLTP for transactional writes)
- MERGE Sync → Scheduled task syncing Postgres to RAW tables (real-time OLTP/OLAP unification)
- Iceberg Export → Export to open format on S3 (no vendor lock-in)
- pg_lake → Query Snowflake data from external Postgres (Iceberg interoperability)
- Snowflake Intelligence → Business users ask questions in plain English (Analyst + Search + ML)
- REST API → Embed AI insights into apps, dashboards, and workflows

---

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