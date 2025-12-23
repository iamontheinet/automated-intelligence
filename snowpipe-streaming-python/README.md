# Snowpipe Streaming for Automated Intelligence - Python SDK

Python implementation of real-time data ingestion using the Snowpipe Streaming Python SDK for the Automated Intelligence demo.

## Overview

This application streams synthetic e-commerce data (customers, orders, and order items) directly into Snowflake tables using the high-performance Snowpipe Streaming Python SDK. It provides:

- **Real-time ingestion** with 5-10 second end-to-end latency
- **Exactly-once delivery** using offset tokens
- **Parallel streaming** with multiple concurrent instances
- **Resumable ingestion** from last committed offset
- **Same business logic** as the Java implementation

## Architecture

### Tables
- `AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS`
- `AUTOMATED_INTELLIGENCE.RAW.ORDERS`
- `AUTOMATED_INTELLIGENCE.RAW.ORDER_ITEMS`

### Channels (2 channels - customers not streamed)
1. **orders_channel** → `ORDERS` table
2. **order_items_channel** → `ORDER_ITEMS` table

### Offset Tokens
- Orders: `order_<order_id>`
- Order Items: `item_<order_item_id>`

## Prerequisites

- **Python**: 3.9 or later
- **Snowflake Account**: With appropriate database, schema, and tables
- **Authentication**: Key-pair authentication (RSA private key)
- **Permissions**: 
  - INSERT on target tables
  - USAGE on database/schema
  - OPERATE on PIPE objects

## Setup

### 1. Install Dependencies

```bash
pip install -r requirements.txt
```

### 2. Create Snowflake PIPE Objects

Run the following SQL in Snowflake:

```sql
USE DATABASE AUTOMATED_INTELLIGENCE;
USE SCHEMA RAW;

CREATE OR REPLACE PIPE ORDERS_PIPE AS COPY INTO ORDERS;
CREATE OR REPLACE PIPE ORDER_ITEMS_PIPE AS COPY INTO ORDER_ITEMS;
```

### 3. Generate RSA Key Pair for Authentication

```bash
# Generate private key
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt

# Generate public key
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub
```

### 4. Assign Public Key to Snowflake User

```sql
ALTER USER YOUR_USER SET RSA_PUBLIC_KEY='<public_key_content>';
```

Replace `<public_key_content>` with the content of `rsa_key.pub` (without BEGIN/END headers).

### 5. Configure Application

Copy the template and fill in your credentials:

```bash
cp profile.json.template profile.json
```

Edit `profile.json`:
```json
{
  "account": "YOUR_ACCOUNT",
  "user": "YOUR_USER",
  "url": "https://YOUR_ACCOUNT.snowflakecomputing.com",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----",
  "database": "AUTOMATED_INTELLIGENCE",
  "schema": "RAW",
  "warehouse": "COMPUTE_WH"
}
```

**Note**: Paste the **entire private key** from `rsa_key.p8` including headers.

## Usage

### Single-Instance Streaming

Stream orders using a single Python process:

```bash
cd src
python automated_intelligence_streaming.py [num_orders]
```

Examples:
```bash
# Stream 100 orders (default)
python automated_intelligence_streaming.py

# Stream 10,000 orders
python automated_intelligence_streaming.py 10000
```

### Parallel Streaming (High Throughput)

Scale horizontally with multiple concurrent instances:

```bash
cd src
python parallel_streaming_orchestrator.py <total_orders> <num_instances>
```

Examples:
```bash
# Stream 1M orders using 5 parallel instances
python parallel_streaming_orchestrator.py 1000000 5

# Stream 10M orders using 10 parallel instances
python parallel_streaming_orchestrator.py 10000000 10
```

**How it works:**
- Partitions the customer ID range across instances
- Each instance uses separate channels with unique names
- Prevents ID collisions using offset token tracking
- Runs all instances concurrently in thread pool

## Configuration

Edit `config.properties` to tune performance:

```properties
# Batch size: Orders per append_rows() call
orders.batch.size=10000

# Max client lag: Higher = better compression, lower = lower latency
max.client.lag=60

# Default orders to generate
num.orders.per.batch=100
```

### Understanding Data Flush Behavior

Data doesn't appear in Snowflake tables immediately after calling `insertRows()`. Snowpipe Streaming uses intelligent buffering for optimal performance:

**Key Configuration:**
- **`max.client.lag=60`**: Buffers data for up to **60 seconds** before flushing to tables
  - Optimizes query performance through better file partitioning
  - Recommended default by Snowflake for production workloads

**Flush Triggers:**
Data is flushed to Snowflake when **any** of these conditions are met:
1. **Buffer size threshold** (~16 MB compressed data)
2. **Time threshold** (60 seconds elapsed since first record)
3. **Channel closed** (explicit close or application shutdown)

**Latency Trade-offs:**
- **Lower lag** (e.g., `max.client.lag=5`):
  - ✅ Faster data visibility (~5 seconds)
  - ❌ More frequent flushes = smaller files = slower downstream queries
  - Use for: Demos, real-time dashboards

- **Higher lag** (e.g., `max.client.lag=60`):
  - ✅ Better file sizes = faster queries
  - ✅ Better compression and throughput
  - ❌ Slower data visibility (~60 seconds)
  - Use for: Production workloads

**Example:** With `max.client.lag=60`, expect data to appear in tables within **~60 seconds** after ingestion starts. This is normal and optimal for production!

## Project Structure

```
snowpipe-streaming-python/
├── src/
│   ├── models.py                              # Customer, Order, OrderItem data models
│   ├── data_generator.py                      # Business logic for synthetic data
│   ├── config_manager.py                      # Configuration loader
│   ├── id_tracker.py                          # Offset token parsing and ID generation
│   ├── snowpipe_streaming_manager.py          # Snowpipe SDK wrapper
│   ├── automated_intelligence_streaming.py    # Single-instance application
│   └── parallel_streaming_orchestrator.py     # Multi-instance orchestrator
├── config.properties                          # Application configuration
├── profile.json.template                      # Snowflake credentials template
├── requirements.txt                           # Python dependencies
└── README.md                                  # This file
```

## Key Features

### Exactly-Once Delivery
- Uses offset tokens to track ingestion progress
- Resumes from last committed position on restart
- Prevents duplicate data ingestion

### ID Generation Strategy
- Parses last committed offset token on startup
- Generates sequential IDs from last position
- Thread-safe ID allocation with locks

### Error Handling
- Detailed logging at INFO and DEBUG levels
- Automatic retries for transient failures
- Graceful shutdown with channel/client cleanup

### Performance Optimization
- Batch inserts with `append_rows()` (vs single-row `append_row()`)
- Configurable batch sizes (default: 10,000 orders)
- Parallel streaming with customer ID partitioning

## Comparison with Java Implementation

| Feature | Java SDK | Python SDK |
|---------|----------|------------|
| **Package** | `snowflake-ingest-java` | `snowpipe-streaming` |
| **Performance** | Native JVM | Rust-backed (high performance) |
| **API Style** | `SnowflakeStreamingIngestClient` | `StreamingIngestClient` |
| **Channel Opening** | `client.openChannel()` | `client.open_channel()` |
| **Batch Insert** | `channel.appendRows()` | `channel.append_rows()` |
| **Offset Tracking** | `getLatestCommittedOffsetToken()` | `get_latest_committed_offset_token()` |
| **Business Logic** | Identical | Identical |
| **Data Generation** | Identical | Identical |
| **Scaling** | Multi-process | Multi-threaded |

## Monitoring

Check ingestion progress:

```sql
-- View channel status
SELECT * FROM TABLE(INFORMATION_SCHEMA.PIPE_CHANNEL_STATUS('AUTOMATED_INTELLIGENCE.RAW.ORDERS_PIPE'));

-- Check row counts
SELECT COUNT(*) FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS;
SELECT COUNT(*) FROM AUTOMATED_INTELLIGENCE.RAW.ORDER_ITEMS;
```

## Troubleshooting

### Authentication Errors
- Verify private key format includes headers: `-----BEGIN PRIVATE KEY-----`
- Ensure public key is assigned to user in Snowflake
- Check user has necessary permissions

### No Data Appearing
- Verify PIPE objects exist: `SHOW PIPES IN SCHEMA AUTOMATED_INTELLIGENCE.RAW;`
- Check for errors: `SELECT * FROM TABLE(VALIDATE_PIPE_LOAD('ORDERS_PIPE', ...));`
- Wait 5-10 seconds for data to be visible (normal latency)

### Performance Issues
- Increase `orders.batch.size` in config.properties
- Use parallel streaming for large volumes
- Monitor warehouse size and scaling

## License

Apache License 2.0

## Generated with Cortex Code

This implementation was created using Snowflake Cortex Code to replicate the Java SDK implementation in Python.
