# Automated Intelligence: Demo Storyline

## Overview
A retail company modernizes their data stack—from development workflows to real-time analytics to AI-powered customer interactions. This demo shows how Snowflake's unified platform handles the entire journey.

---

## Feature Summaries

| Feature | Summary |
|---------|---------|
| **Cortex Code** | AI-powered assistant (CLI or Snowsight) that generates SQL, dbt models, and Python code from natural language to accelerate development. |
| **Workspaces** | Collaborative development environment with Git integration and native dbt pipelines for version-controlled data transformations. |
| **Snowflake Postgres** | Hybrid OLTP/OLAP architecture where Postgres handles transactional writes and Snowflake powers analytics over automatically synced data. |
| **Notebook vNext + Model Registry + SPCS** | GPU-accelerated ML training in notebooks with governed model versioning and one-click deployment to scalable inference endpoints. |
| **Snowflake Intelligence** | Conversational AI powered by Cortex Agent that orchestrates Analyst (text-to-SQL), Search (semantic retrieval), and custom ML tools—accessible via UI or REST API. |

---

## Act 1: Developer Experience

**Theme:** *"Building in the IDE, shipping to Snowflake"*

### Cortex Code
- AI-powered development using CLI or Snowsight CoCo
- Generates SQL, dbt models, and Python code with natural language
- Accelerates iteration from idea to implementation

### Workspaces
- **Git Integration:** Version-controlled pipelines with collaborative workflows
- **dbt Pipeline:** Transforms raw customer data into analytics-ready tables
  - Customer Lifetime Value (CLV)
  - Segmentation models
  - Cohort analysis
- All orchestrated natively within Snowflake

---

## Act 2: Hybrid Data Architecture

**Theme:** *"Transactional and analytical workloads, unified"*

### Snowflake Postgres
- **OLTP Layer:** Handles high-frequency writes (product reviews, support tickets)
- **OLAP Layer:** Snowflake powers analytics over synced data
- **MERGE-based Sync:** Scheduled sync handles inserts, updates, deletes

### pg_lake (Iceberg Interoperability)
- External PostgreSQL instances query Snowflake Iceberg tables directly from S3
- True lakehouse architecture—data flows seamlessly:
  - Snowflake → S3 (Iceberg format) → pg_lake → any Iceberg-compatible system
- Enables hybrid cloud and multi-engine analytics

---

## Act 3: ML at Scale

**Theme:** *"Train once, deploy anywhere"*

### Snowflake Notebook vNext
- GPU-accelerated training (`tree_method='gpu_hist'`)
- XGBoost product recommendation models
### Model Registry
- Version tracking with full lineage
- Model governance and artifact management

### SPCS Deployment
- Models served as scalable REST APIs
- No infrastructure management required
- Production-ready inference endpoints

---

## Act 4: Conversational AI

**Theme:** *"Ask your data anything"*

### Snowflake Intelligence with Cortex Agent
Orchestrates multiple capabilities in a single conversational interface:

| Capability | Purpose |
|------------|---------|
| **Cortex Analyst** | Natural language → SQL across semantic models |
| **Cortex Search** | Semantic queries over reviews and support tickets |
| **Custom Tools** | Invoke deployed ML model for real-time predictions |

### REST API
- Expose intelligence to any application
- Programmatic access to agent capabilities

### Row-Level Access Control (RLAC)
- Governance enforced transparently to the AI agent
- West Coast Manager → sees CA, OR, WA data only
- Admin → sees global data
- Same agent, different answers based on user context

---

## The Punchline

> **One platform. Zero external systems. From code to production AI—entirely within Snowflake.**

---

## Demo Flow (Suggested)

1. **Open Cortex Code** → Show AI-assisted development
2. **Navigate Workspaces** → Git repo, dbt project structure
3. **Run dbt pipeline** → Show transformation lineage
4. **Show Postgres sync** → OLTP writes flowing to Snowflake
5. **Query pg_lake** → Same Iceberg data from external Postgres
6. **Open Notebook** → GPU training, model registry
7. **Deploy to SPCS** → Model serving endpoint
8. **Launch Intelligence** → Cortex Agent with Analyst + Search + ML Tool
9. **Demo RLAC** → Switch roles, show different results
10. **Call REST API** → Programmatic agent access

---

## Key Differentiators

- **Unified Platform:** No external ETL, caching, or ML infrastructure
- **Lakehouse Interoperability:** Iceberg enables open data sharing
- **AI-Native:** From development (Cortex Code) to production (Intelligence)
- **Governance Built-In:** RLAC works transparently with AI agents
