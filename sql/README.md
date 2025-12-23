# Gen2 Warehouse Setup

This directory contains setup scripts for **Demo 1: Gen2 Warehouse Performance**.

## Purpose

Sets up the staging pipeline and MERGE procedures needed to demonstrate Gen2 warehouse performance improvements (10-40% faster MERGE/UPDATE operations).

## Files

- `setup_staging_pipeline.sql` - Creates staging schema, tables, and Gen2 warehouse
- `setup_merge_procedures.sql` - Creates MERGE/UPDATE procedures with benchmarking

## Setup Instructions

```bash
# Run both scripts in order
snow sql -f sql/setup_staging_pipeline.sql -c dash-builder-si
snow sql -f sql/setup_merge_procedures.sql -c dash-builder-si
```

## Prerequisites

- Core setup must be completed first (`setup/setup.sql`)
- Snowpipe Streaming configured to load data into staging tables

## What Gets Created

**Staging Schema:**
- `staging.orders_staging` - Append-only staging table for orders
- `staging.order_items_staging` - Append-only staging table for order items
- `staging.customers_staging` - Append-only staging table for customers

**Gen2 Warehouse:**
- `automated_intelligence_gen2_wh` - Gen2 warehouse with `RESOURCE_CONSTRAINT = 'STANDARD_GEN_2'`

**Stored Procedures:**
- `merge_orders_gen1()` - MERGE orders using Gen1 warehouse
- `merge_orders_gen2()` - MERGE orders using Gen2 warehouse
- `merge_order_items_gen1()` - MERGE order_items using Gen1 warehouse
- `merge_order_items_gen2()` - MERGE order_items using Gen2 warehouse

## Usage

After setup, use the Streamlit dashboard to run Gen1 vs Gen2 comparison tests.

See main project README for full demo instructions.
