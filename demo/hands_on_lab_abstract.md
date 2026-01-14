# Hands-On Lab: Abstract Options

## Option 1: Conference/Summit Style (Formal)

**Title:** Building an End-to-End AI Application on Snowflake: From Code to Production Intelligence

**Abstract:**

In this hands-on lab, you'll build a complete AI-powered retail analytics application entirely within Snowflake—no external infrastructure required. Starting with AI-assisted development using Cortex Code, you'll generate SQL and dbt models from natural language. Next, you'll train a GPU-accelerated XGBoost recommendation model (`tree_method='gpu_hist'`) in Snowflake Notebooks within Workspaces, register it in the Model Registry, and create a service endpoint on Snowflake's GPU compute pool using `create_service()`. Finally, you'll create a hybrid data architecture with Snowflake Postgres for OLTP workloads, automatically sync data to Snowflake for analytics, and export to Iceberg format on S3—where **pg_lake** (an external PostgreSQL instance) queries the same data without any Snowflake connection, demonstrating true lakehouse interoperability. Tie it all together with Snowflake Intelligence: a conversational AI that orchestrates Cortex Analyst, Cortex Search, and your custom ML model via a single REST API.

**What You'll Learn:**
- Accelerate development with Cortex Code CLI and VS Code Extension
- Train XGBoost models on GPU and deploy service endpoints via Model Registry
- Build hybrid OLTP/OLAP architectures with Snowflake Postgres
- Query Snowflake data from external systems using pg_lake and Iceberg
- Create conversational AI experiences with Snowflake Intelligence

**Prerequisites:** Basic SQL and Python knowledge. Snowflake account with Enterprise features enabled.

**Duration:** 90 minutes

---

## Option 2: Workshop Style (Engaging)

**Title:** One Platform, Zero Excuses: Ship Production AI in 90 Minutes

**Abstract:**

Stop stitching together tools. In this lab, you'll experience what "unified platform" actually means—writing code with an AI assistant, training models on GPUs, and deploying conversational AI, all without leaving Snowflake.

You'll start by letting Cortex Code write your SQL. Then you'll train a product recommendation model using XGBoost with `gpu_hist` in a Snowflake Notebook, log it to the Model Registry, and spin up a service endpoint on the GPU compute pool with a single `create_service()` call. Finally, you'll build a hybrid data architecture: Postgres handles transactional writes, Snowflake powers analytics, and **pg_lake**—an external PostgreSQL instance—queries the same data directly from S3 via Iceberg, proving there's no vendor lock-in. All of this feeds into an AI agent that answers questions in plain English.

Walk away with a working application and a new understanding of what's possible when everything runs on one platform.

**You'll Build:**
- AI-generated dbt models and SQL queries
- GPU-trained XGBoost model with service endpoint deployment
- OLTP→Analytics sync pipeline with Iceberg export
- pg_lake integration: external Postgres querying Snowflake data via Iceberg
- Conversational AI with REST API access

**Who Should Attend:** Data engineers, ML engineers, and architects who want to simplify their stack.

**Duration:** 90 minutes

---

## Option 3: Short Form (200 words)

**Title:** From Code to Conversational AI on Snowflake

**Abstract:**

Build a production AI application entirely within Snowflake. This hands-on lab covers three integrated workflows: (1) AI-assisted development with Cortex Code, VS Code Extension, and Snow CLI; (2) GPU-accelerated XGBoost training in Notebooks within Workspaces, Model Registry for versioning, and service endpoint deployment via `create_service()`; and (3) hybrid data architecture combining Snowflake Postgres for OLTP, Iceberg export to S3, **pg_lake for external system access**, and Snowflake Intelligence for conversational AI. The pg_lake demonstration proves true lakehouse interoperability—external PostgreSQL queries Snowflake data without any direct connection, using open Iceberg format. Participants will leave with working code and a clear understanding of Snowflake's unified platform capabilities.

**Duration:** 90 minutes | **Level:** Intermediate

---

## Key Technologies Covered

| Category | Technologies |
|----------|--------------|
| Developer Tools | Cortex Code CLI, VS Code Extension, Snow CLI |
| ML/AI Training | Notebooks vNext (Workspaces), XGBoost GPU, Model Registry |
| Model Serving | `create_service()`, GPU compute pools |
| Data Architecture | Snowflake Postgres (OLTP), MERGE sync, Iceberg tables |
| Lakehouse | pg_lake, S3, open Iceberg format |
| Conversational AI | Snowflake Intelligence, Cortex Analyst, Cortex Search |
| Integration | REST API, custom ML tools |
