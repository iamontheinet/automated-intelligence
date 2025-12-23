#!/bin/bash
#
# Fix PutDatabaseRecord processors and enable connection pool
#

set -e

RUNTIME_URL="https://of--sfsenorthamerica-gen-ai-hol.snowflakecomputing.app/dashing"
API_BASE="${RUNTIME_URL}/nifi-api"
PG_ID="0a9f1d18-019b-1000-0000-000034cc7230"

CONNECTION_POOL_ID="13b2ec3d-019b-1000-ffff-ffffe8649370"
RECORD_READER_ID="13b30762-019b-1000-ffff-ffffea3bef7f"
PUTDB_ORDERS_ID="13b313a1-019b-1000-0000-00001de9bb39"
PUTDB_ITEMS_ID="13b316fb-019b-1000-0000-000079b848f8"

if [ -z "$PAT" ]; then
    echo "Error: PAT environment variable not set"
    exit 1
fi

echo "================================================================================"
echo "Fixing PutDatabaseRecord Processors and Connection Pool"
echo "================================================================================"
echo ""

# Step 1: Fix DBCPConnectionPool to use correct parameter name
echo "Step 1: Fixing DBCPConnectionPool parameter reference..."
POOL_VERSION=$(curl -s -H "Authorization: Bearer $PAT" \
    "${API_BASE}/controller-services/${CONNECTION_POOL_ID}" | \
    python3 -c "import sys, json; print(json.load(sys.stdin)['revision']['version'])")

curl -s -X PUT -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/controller-services/${CONNECTION_POOL_ID}" \
    -d '{
        "revision": {"version": '"$POOL_VERSION"'},
        "component": {
            "id": "'"$CONNECTION_POOL_ID"'",
            "properties": {
                "Database Connection URL": "jdbc:snowflake://sfsenorthamerica-gen-ai-hol.snowflakecomputing.com/?warehouse=automated_intelligence_wh&db=automated_intelligence&schema=analytics_iceberg&role=snowflake_intelligence_admin",
                "Database Driver Class Name": "net.snowflake.client.jdbc.SnowflakeDriver",
                "database-driver-locations": "/opt/nifi/nifi-current/lib/snowflake-jdbc.jar",
                "Database User": "#{snowflake.username}",
                "Max Wait Time": "500 millis",
                "Max Total Connections": "8",
                "Validation-query": "SELECT 1"
            }
        }
    }' > /dev/null

echo "  ✓ Fixed parameter reference (snowflake.user → snowflake.username)"

# Step 2: Enable connection pool
echo ""
echo "Step 2: Enabling DBCPConnectionPool..."
sleep 1
POOL_VERSION=$(curl -s -H "Authorization: Bearer $PAT" \
    "${API_BASE}/controller-services/${CONNECTION_POOL_ID}" | \
    python3 -c "import sys, json; print(json.load(sys.stdin)['revision']['version'])")

curl -s -X PUT -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/controller-services/${CONNECTION_POOL_ID}/run-status" \
    -d '{
        "revision": {"version": '"$POOL_VERSION"'},
        "state": "ENABLED"
    }' > /dev/null

echo "  ✓ Connection pool enabled"

# Step 3: Fix PutDatabaseRecord (Orders) with correct property names
echo ""
echo "Step 3: Fixing PutDatabaseRecord (Orders) properties..."
ORDERS_VERSION=$(curl -s -H "Authorization: Bearer $PAT" \
    "${API_BASE}/processors/${PUTDB_ORDERS_ID}" | \
    python3 -c "import sys, json; print(json.load(sys.stdin)['revision']['version'])")

curl -s -X PUT -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/processors/${PUTDB_ORDERS_ID}" \
    -d '{
        "revision": {"version": '"$ORDERS_VERSION"'},
        "component": {
            "id": "'"$PUTDB_ORDERS_ID"'",
            "config": {
                "properties": {
                    "put-db-record-record-reader": "'"$RECORD_READER_ID"'",
                    "db-type": "Generic",
                    "put-db-record-statement-type": "INSERT",
                    "put-db-record-dcbp-service": "'"$CONNECTION_POOL_ID"'",
                    "put-db-record-catalog-name": "",
                    "put-db-record-schema-name": "analytics_iceberg",
                    "put-db-record-table-name": "orders",
                    "put-db-record-binary-format": "UTF-8",
                    "Column Name Translation Strategy": "REMOVE_UNDERSCORE",
                    "put-db-record-allow-multiple-statements": "false",
                    "put-db-record-query-timeout": "0 seconds",
                    "rollback-on-failure": "false",
                    "table-schema-cache-size": "100"
                }
            }
        }
    }' > /dev/null

echo "  ✓ PutDatabaseRecord (Orders) fixed"

# Step 4: Fix PutDatabaseRecord (Order Items) with correct property names
echo ""
echo "Step 4: Fixing PutDatabaseRecord (Order Items) properties..."
ITEMS_VERSION=$(curl -s -H "Authorization: Bearer $PAT" \
    "${API_BASE}/processors/${PUTDB_ITEMS_ID}" | \
    python3 -c "import sys, json; print(json.load(sys.stdin)['revision']['version'])")

curl -s -X PUT -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/processors/${PUTDB_ITEMS_ID}" \
    -d '{
        "revision": {"version": '"$ITEMS_VERSION"'},
        "component": {
            "id": "'"$PUTDB_ITEMS_ID"'",
            "config": {
                "properties": {
                    "put-db-record-record-reader": "'"$RECORD_READER_ID"'",
                    "db-type": "Generic",
                    "put-db-record-statement-type": "INSERT",
                    "put-db-record-dcbp-service": "'"$CONNECTION_POOL_ID"'",
                    "put-db-record-catalog-name": "",
                    "put-db-record-schema-name": "analytics_iceberg",
                    "put-db-record-table-name": "order_items",
                    "put-db-record-binary-format": "UTF-8",
                    "Column Name Translation Strategy": "REMOVE_UNDERSCORE",
                    "put-db-record-allow-multiple-statements": "false",
                    "put-db-record-query-timeout": "0 seconds",
                    "rollback-on-failure": "false",
                    "table-schema-cache-size": "100"
                }
            }
        }
    }' > /dev/null

echo "  ✓ PutDatabaseRecord (Order Items) fixed"

echo ""
echo "================================================================================"
echo "✅ All Components Fixed!"
echo "================================================================================"
echo ""
echo "Fixed:"
echo "  - DBCPConnectionPool: Parameter reference and enabled"
echo "  - PutDatabaseRecord (Orders): Correct property names"
echo "  - PutDatabaseRecord (Order Items): Correct property names"
echo ""
echo "Pipeline should now be valid and ready to start!"
echo ""
