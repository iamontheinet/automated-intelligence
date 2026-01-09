# Snowflake Postgres Integration

This module sets up a **Hybrid OLTP/OLAP Architecture** using Snowflake Postgres for transactional workloads and Snowflake for analytics.

## Overview

Snowflake Postgres is a managed PostgreSQL service within Snowflake. This integration demonstrates:
- **OLTP Layer (Postgres)**: Handles transactional writes for product_reviews and support_tickets
- **OLAP Layer (Snowflake)**: Analytics, Cortex AI, and natural language queries
- **MERGE-based Sync**: Scheduled task syncs data from Postgres to Snowflake
- **Cortex Search**: Semantic search over synced data for AI-powered queries

## Setup

### 0. Configure Postgres Credentials

```bash
# Copy the template and fill in your credentials
cp postgres_config.json.template postgres_config.json
# Edit postgres_config.json with your host, user, and password
```

### 1. Create Postgres Tables

Connect to your Snowflake Postgres instance and run:

```bash
# Using psql
psql "postgres://user:pass@host:5432/postgres?sslmode=require" -f 01_create_postgres_tables.sql
```

Or use Python:
```bash
pip install psycopg2-binary
python insert_sample_data.py  # Creates tables and inserts sample data
```

### 2. Setup External Access in Snowflake

Run in Snowflake (update credentials in the script first):

```bash
snow sql -c <connection> -f 02_setup_external_access.sql
```

### 3. Create Query Functions

```bash
snow sql -c <connection> -f 03_create_query_functions.sql
```

### 4. Query Postgres from Snowflake

See `04_example_queries.sql` for examples, or:

```sql
-- Simple count
CALL query_postgres('SELECT COUNT(*) FROM customers');

-- Query as table
SELECT result FROM TABLE(pg_query('SELECT * FROM customers LIMIT 10'));

-- Extract fields
SELECT 
    result:customer_id::INT as customer_id,
    result:first_name::STRING as first_name
FROM TABLE(pg_query('SELECT * FROM customers LIMIT 10'));
```

## Files

| File | Description |
|------|-------------|
| `01_create_postgres_tables.sql` | DDL to create tables in Postgres |
| `02_setup_external_access.sql` | Snowflake network rule, secret, and integration |
| `03_create_query_functions.sql` | Snowflake stored procedure and UDTF |
| `04_example_queries.sql` | Example queries using the functions |
| `05_create_sync_task.sql` | MERGE-based sync procedure and scheduled task |
| `insert_sample_data.py` | Python script to populate tables with sample data |
| `insert_product_reviews.py` | Generate product reviews with sentiment distribution |
| `insert_support_tickets.py` | Generate support tickets with sentiment distribution |

## Tables

The schema mirrors `AUTOMATED_INTELLIGENCE.RAW` in Snowflake:

- `customers` - Customer information (synced from Snowflake)
- `orders` - Order headers
- `order_items` - Order line items
- `product_catalog` - Product information (synced from Snowflake)
- `product_reviews` - Customer reviews (**OLTP source** - written in Postgres, synced to Snowflake)
- `support_tickets` - Support ticket data (**OLTP source** - written in Postgres, synced to Snowflake)

## Hybrid OLTP/OLAP Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    OLTP Layer (Postgres)                         │
│  ┌─────────────────────┐ ┌─────────────────────────────────┐    │
│  │   product_reviews   │ │       support_tickets           │    │
│  │   (transactional    │ │       (transactional            │    │
│  │    writes)          │ │        writes)                  │    │
│  └─────────────────────┘ └─────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                           │
                           │ MERGE-based Sync (5 min task)
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                    OLAP Layer (Snowflake)                        │
│  ┌─────────────────────┐ ┌─────────────────────────────────┐    │
│  │ RAW.PRODUCT_REVIEWS │ │    RAW.SUPPORT_TICKETS          │    │
│  └─────────────────────┘ └─────────────────────────────────┘    │
│                           │                                      │
│                           ▼                                      │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              Cortex Search Services (SEMANTIC)             │  │
│  │  • product_reviews_search - semantic search over reviews  │  │
│  │  • support_tickets_search - semantic search over tickets  │  │
│  └───────────────────────────────────────────────────────────┘  │
│                           │                                      │
│                           ▼                                      │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              Cortex Agent (Snowflake Intelligence)         │  │
│  │  Natural language queries over reviews and tickets        │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Sync Mechanism

The sync uses MERGE operations (more realistic than DELETE+INSERT):

```sql
-- Sync procedure handles:
-- 1. MERGE: Insert new records, update existing ones
-- 2. DELETE: Remove records deleted from Postgres source

CALL POSTGRES.sync_postgres_to_snowflake();

-- Scheduled task runs every 5 minutes
ALTER TASK POSTGRES.postgres_sync_task RESUME;
```

## Cortex Search Integration

After sync, data is searchable via Cortex Search:

```sql
-- Search product reviews
SELECT PARSE_JSON(
    SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'AUTOMATED_INTELLIGENCE.SEMANTIC.PRODUCT_REVIEWS_SEARCH',
        '{"query": "quality issues with boots", "columns": ["review_title", "review_text", "rating"], "limit": 5}'
    )
)['results'] AS results;

-- Search support tickets
SELECT PARSE_JSON(
    SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'AUTOMATED_INTELLIGENCE.SEMANTIC.SUPPORT_TICKETS_SEARCH',
        '{"query": "shipping delays", "columns": ["subject", "description", "priority"], "limit": 5}'
    )
)['results'] AS results;
```

## Connection Details

```
Host: o6gnp7eqn5awvivkqhk22xpoym.sfsenorthamerica-gen-ai-hol.us-west-2.aws.postgres.snowflake.app
Port: 5432
Database: postgres
SSL: Required
```

## Architecture

## External Access Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Snowflake Account                        │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  External Access Integration (POSTGRES schema)       │    │
│  │  - Network Rule (egress to Postgres host)           │    │
│  │  - Secret (Postgres credentials)                    │    │
│  └─────────────────────────────────────────────────────┘    │
│                           │                                  │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Python UDF/Stored Procedure (POSTGRES schema)       │    │
│  │  - query_postgres(sql) → VARIANT (single result)    │    │
│  │  - pg_query(sql) → TABLE (multiple rows)            │    │
│  │  - pg_execute(sql) → INT (DML operations)           │    │
│  │  - sync_postgres_to_snowflake() → VARIANT (sync)    │    │
│  └─────────────────────────────────────────────────────┘    │
│                           │                                  │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Scheduled Task                                       │    │
│  │  - postgres_sync_task (every 5 minutes)              │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│              Snowflake Postgres Instance                     │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐   │
│  │  customers  │ │   orders    │ │    order_items      │   │
│  └─────────────┘ └─────────────┘ └─────────────────────┘   │
│  ┌─────────────────────┐ ┌─────────────────────────────┐   │
│  │   product_catalog   │ │      product_reviews        │   │
│  └─────────────────────┘ └─────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                  support_tickets                     │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Data Volumes

| Table | Records | Sentiment Distribution |
|-------|---------|------------------------|
| product_reviews | ~395 | 65% positive, 15% negative, 20% neutral |
| support_tickets | ~500 | 40% positive, 20% negative, 40% neutral |
| customers | 1,000 | Synced from Snowflake |
| product_catalog | 10 | Synced from Snowflake |
