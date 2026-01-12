# pg_lake Demo

Query Snowflake Iceberg data directly from Postgres using pg_lake - demonstrating the **Open Lakehouse** pattern where Snowflake exports data to S3 in Iceberg format, and external systems (Postgres) can read it natively.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Snowflake Postgres (OLTP)                     │
│  ┌─────────────────────┐ ┌─────────────────────────────────┐    │
│  │   product_reviews   │ │       support_tickets           │    │
│  │   (transactional    │ │       (transactional            │    │
│  │    writes)          │ │        writes)                  │    │
│  └─────────────────────┘ └─────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                           │
                           │ MERGE-based Sync (5 min)
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Snowflake (OLAP)                              │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  AUTOMATED_INTELLIGENCE.RAW.PRODUCT_REVIEWS                 ││
│  │  AUTOMATED_INTELLIGENCE.RAW.SUPPORT_TICKETS                 ││
│  └─────────────────────────────────────────────────────────────┘│
│                           │                                      │
│                           │ Iceberg Tables (PG_LAKE schema)      │
│                           ▼                                      │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  AUTOMATED_INTELLIGENCE.PG_LAKE.PRODUCT_REVIEWS (Iceberg)   ││
│  │  AUTOMATED_INTELLIGENCE.PG_LAKE.SUPPORT_TICKETS (Iceberg)   ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
                           │
                           │ S3 (Iceberg format)
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                      S3 Bucket                                   │
│  s3://dash-iceberg-snowflake/demos/pg_lake/                     │
│  ├── product_reviews.xxx/metadata/00001-xxx.metadata.json       │
│  └── support_tickets.xxx/metadata/00001-xxx.metadata.json       │
└─────────────────────────────────────────────────────────────────┘
                           │
                           │ Foreign Tables (Iceberg metadata)
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                      pg_lake (Postgres)                          │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  product_reviews (foreign table → Iceberg metadata)         ││
│  │  support_tickets (foreign table → Iceberg metadata)         ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

## Prerequisites

- Docker & Docker Compose
- AWS credentials configured (`~/.aws/credentials`) with access to `s3://dash-iceberg-snowflake/`
- pg_lake Docker images built locally (see [Building pg_lake Images](#building-pg_lake-images) below):
  - `pg_lake:local`
  - `pgduck-server:local`
- psql client (optional, for local connections)

## Building pg_lake Images

The Docker images must be built from the [pg_lake repository](https://github.com/Snowflake-Labs/pg_lake):

```bash
# Clone the pg_lake repository
git clone --recurse-submodules https://github.com/Snowflake-Labs/pg_lake.git
cd pg_lake

# Install go-task (build tool)
brew install go-task

# Build Docker images (requires 8-16GB Docker memory allocation)
cd docker
task compose:up

# Verify images were created
docker images | grep -E 'pg_lake|pgduck-server'
# Should show: pg_lake:local and pgduck-server:local

# Stop pg_lake's containers (we'll use our own docker-compose)
docker compose down

# Return to this project
cd /path/to/automated-intelligence/pg_lake
```

> **Note**: Building requires significant memory. If you get "cannot allocate memory" errors, increase Docker Desktop memory to 12-16GB via Settings → Resources → Memory.

## Install psql Client (Optional)

```bash
brew install libpq
echo 'export PATH="/opt/homebrew/opt/libpq/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

## Quick Start

```bash
# Start pg_lake containers
docker compose up -d

# Wait for healthy status (~30 seconds)
docker compose ps

# Connect to Postgres
psql -h localhost -p 5433 -U postgres -d postgres
# Password: postgres
```

## Query Snowflake Data

The foreign tables are auto-created on startup, pointing to Snowflake's Iceberg exports:

```sql
-- Check row counts (should match Snowflake)
SELECT 'product_reviews' as table_name, COUNT(*) FROM product_reviews
UNION ALL
SELECT 'support_tickets', COUNT(*) FROM support_tickets;

-- Query product reviews
SELECT review_id, rating, review_title 
FROM product_reviews 
LIMIT 5;

-- Query support tickets
SELECT ticket_id, category, priority, status 
FROM support_tickets 
LIMIT 5;

-- Analytics: Rating distribution
SELECT rating, COUNT(*) as count
FROM product_reviews
GROUP BY rating
ORDER BY rating DESC;

-- Analytics: Tickets by status
SELECT status, COUNT(*) as count
FROM support_tickets
GROUP BY status;
```

## How It Works

### Snowflake Side
1. RAW tables (`PRODUCT_REVIEWS`, `SUPPORT_TICKETS`) store the data
2. Iceberg tables in `PG_LAKE` schema export to S3 with Iceberg metadata
3. Use `SYSTEM$GET_ICEBERG_TABLE_INFORMATION()` to get metadata paths

### pg_lake Side
1. Foreign tables point to **Iceberg metadata JSON** files (NOT raw parquet)
2. pg_lake reads the metadata to understand schema, partitions, snapshots
3. DuckDB (via pgduck_server) executes queries against S3

### Key Pattern: Iceberg Metadata
```sql
-- CORRECT: Point to Iceberg metadata (preserves schema, snapshots, etc.)
CREATE FOREIGN TABLE product_reviews()
SERVER pg_lake
OPTIONS (path 's3://bucket/path/metadata/00001-xxx.metadata.json');

-- ANTI-PATTERN: Reading raw parquet bypasses Iceberg benefits
-- CREATE FOREIGN TABLE ... OPTIONS (path '.../*.parquet', format 'parquet')
```

## Files

| File | Description |
|------|-------------|
| `docker-compose.yml` | Docker setup for pg_lake + pgduck-server |
| `scripts/init-postgres.sql` | Creates foreign tables on startup |
| `scripts/init-pgduck-server.sql` | Configures DuckDB S3 credentials |
| `snowflake_export.sql` | SQL to create Iceberg tables in Snowflake |
| `demo_queries.sql` | Example analytics queries |

## Refreshing Data

When Snowflake data changes:

1. **Snowflake**: Refresh Iceberg tables
   ```sql
   INSERT OVERWRITE INTO AUTOMATED_INTELLIGENCE.PG_LAKE.PRODUCT_REVIEWS 
   SELECT * FROM AUTOMATED_INTELLIGENCE.RAW.PRODUCT_REVIEWS;
   ```

2. **Get new metadata path**:
   ```sql
   SELECT SYSTEM$GET_ICEBERG_TABLE_INFORMATION('AUTOMATED_INTELLIGENCE.PG_LAKE.PRODUCT_REVIEWS');
   ```

3. **pg_lake**: Recreate foreign table with new metadata path
   ```sql
   DROP FOREIGN TABLE IF EXISTS product_reviews;
   CREATE FOREIGN TABLE product_reviews()
   SERVER pg_lake
   OPTIONS (path 's3://...new-metadata-path.json');
   ```

## S3 Configuration

| Setting | Value |
|---------|-------|
| Bucket | `s3://dash-iceberg-snowflake/demos/pg_lake/` |
| Region | `us-west-2` |
| External Volume | `aws_s3_ext_volume_snowflake` |

## Cleanup

```bash
# Stop containers
docker compose down

# Remove volumes too
docker compose down -v
```

## Troubleshooting

### Connection refused
Wait 30 seconds after `docker compose up` for initialization.

### pgduck-server unhealthy / "No such file or directory"
This usually means a PostgreSQL version mismatch. The pg_lake images are built with PostgreSQL 18, so ensure `docker-compose.yml` has:
```yaml
environment:
  PG_MAJOR: "18"  # Must match the built image version
```

### S3 access denied
Ensure `~/.aws/credentials` has valid credentials. The containers mount this file read-only.

### Build fails with "cannot allocate memory"
Increase Docker Desktop memory allocation to 12-16GB via Settings → Resources → Memory, then retry the build.

### Wrong data / stale data
Iceberg metadata paths change when tables are refreshed. Get the latest path from Snowflake and recreate the foreign table.

### Schema mismatch
Foreign tables with empty `()` auto-infer schema from Iceberg metadata. If columns changed in Snowflake, recreate the foreign table.
