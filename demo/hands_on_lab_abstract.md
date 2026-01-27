# Hands-On Lab: Abstract Options

## Option 1: Conference/Summit Style (Formal)

**Title:** Building an End-to-End AI Application on Snowflake: From Data To Intelligence

**Abstract:**-

In this hands-on lab, you'll build a complete AI-powered retail analytics application entirely within Snowflake—no external infrastructure required. Starting with AI-assisted development using Cortex Code, you'll generate SQL queries and dbt models from natural language. You'll then build batch analytical models (customer lifetime value, segmentation, product affinity) using dbt in Snowflake Workspaces. Next, you'll train a GPU-accelerated XGBoost recommendation model in Snowflake Notebooks, register it in the Model Registry with metrics and versioning, and deploy it as a service endpoint. Finally, you'll create a hybrid data architecture with Snowflake Postgres for OLTP workloads (product reviews, support tickets), automatically sync data to Snowflake via scheduled MERGE tasks, and export to Iceberg format on S3—where **pg_lake** (an external PostgreSQL instance) queries the same data without any Snowflake connection, demonstrating true lakehouse interoperability. Tie it all together with Snowflake Intelligence: a conversational interface that orchestrates Cortex Analyst, Cortex Search, and your custom ML model.

**What You'll Learn:**
- Accelerate development with Cortex Code 
- Build analytical models (CLV, segmentation, cohorts) with dbt in Workspaces
- Train XGBoost models on GPU and deploy as service endpoints via Model Registry
- Build hybrid OLTP/OLAP architectures with Snowflake Postgres and MERGE sync
- Query Snowflake data from external systems using pg_lake and Iceberg
- Create conversational AI experiences with Snowflake Intelligence

**Prerequisites:** Basic SQL and Python knowledge. Snowflake account with Enterprise features enabled.

**Duration:** 90 minutes

---

## Option 2: Workshop Style (Engaging)

**Title:** One Platform, Zero Excuses: Ship Production AI in 90 Minutes

**Abstract:**

Stop stitching together tools. In this lab, you'll experience what "unified platform" actually means—writing code with an AI assistant, building dbt analytics, training models on GPUs, and deploying conversational AI, all without leaving Snowflake.

You'll start by letting Cortex Code generate your SQL and dbt models from plain English. Then you'll run dbt in Workspaces to build customer lifetime value, segmentation, and product affinity models. Next, train a product recommendation model using XGBoost with `gpu_hist` in a Snowflake Notebook, log it to the Model Registry, and deploy it as a service endpoint. Finally, build a hybrid data architecture: Snowflake Postgres handles transactional writes (reviews, tickets), scheduled tasks sync to Snowflake for analytics, and **pg_lake**—an external PostgreSQL instance—queries the same data directly from S3 via Iceberg, proving there's no vendor lock-in. All of this feeds into Snowflake Intelligence, an AI agent that answers questions in plain English using Analyst, Search, and your ML model.

Walk away with a working application and a new understanding of what's possible when everything runs on one platform.

**You'll Build:**
- AI-generated SQL queries and dbt models via Cortex Code
- Batch analytics: customer lifetime value, segmentation, product affinity (dbt)
- GPU-trained XGBoost model deployed as service endpoint
- OLTP→Analytics sync pipeline with Iceberg export
- pg_lake integration: external Postgres querying Snowflake data via Iceberg
- Conversational AI with REST API access

**Who Should Attend:** Data engineers, ML engineers, analytics engineers, and architects who want to simplify their stack.

**Duration:** 90 minutes

---

## Option 3: Short Form (200 words)

**Title:** From Code to Conversational AI on Snowflake

**Abstract:**

Build a production AI application entirely within Snowflake. This hands-on lab covers three integrated workflows: (1) AI-assisted development with Cortex Code CLI, VS Code Extension, and Snow CLI to generate SQL and dbt models; (2) dbt analytics in Workspaces for customer lifetime value, segmentation, and product affinity, plus GPU-accelerated XGBoost training in Notebooks with Model Registry and service endpoint deployment; and (3) hybrid data architecture combining Snowflake Postgres for OLTP, MERGE-based sync to Snowflake, Iceberg export to S3, **pg_lake for external system access**, and Snowflake Intelligence for conversational AI. The pg_lake demonstration proves true lakehouse interoperability—external PostgreSQL queries Snowflake data without any direct connection, using open Iceberg format. Participants will leave with working code and a clear understanding of Snowflake's unified platform capabilities.

**Duration:** 90 minutes | **Level:** Intermediate

---

## Key Technologies Covered

| Category | Technologies |
|----------|--------------|
| Developer Tools | Cortex Code CLI, VS Code Extension, Snow CLI |
| Analytics | dbt (CLV, segmentation, product affinity, cohorts) in Workspaces |
| ML/AI Training | Notebooks vNext (GPU), XGBoost, Model Registry |
| Model Serving | Service Endpoints, GPU compute pools |
| Data Architecture | Snowflake Postgres (OLTP), MERGE sync, Iceberg tables |
| Lakehouse | pg_lake, S3, open Iceberg format |
| Conversational AI | Snowflake Intelligence, Cortex Analyst, Cortex Search, Custom ML Tools |
| Integration | REST API |
