#!/bin/bash
#
# Clean up and recreate everything properly
#

set -e

RUNTIME_URL="https://of--sfsenorthamerica-gen-ai-hol.snowflakecomputing.app/dashing"
API_BASE="${RUNTIME_URL}/nifi-api"
PG_ID="0a9f1d18-019b-1000-0000-000034cc7230"

CONNECTION_POOL_ID="13b2ec3d-019b-1000-ffff-ffffe8649370"
RECORD_READER_ID="13b30762-019b-1000-ffff-ffffea3bef7f"
PUTDB_ORDERS_ID="13b313a1-019b-1000-0000-00001de9bb39"
PUTDB_ITEMS_ID="13b316fb-019b-1000-0000-000079b848f8"
SPLITJSON_ORDERS_ID="13b30fc0-019b-1000-ffff-ffffb99bb7ec"
SPLITJSON_ITEMS_ID="13b311cc-019b-1000-0000-00004c223a2f"

if [ -z "$PAT" ]; then
    echo "Error: PAT environment variable not set"
    exit 1
fi

echo "================================================================================"
echo "Clean Rebuild of Database Processors"
echo "================================================================================"
echo ""

# Step 1: Disable and delete old PutDatabaseRecord processors
echo "Step 1: Deleting old PutDatabaseRecord processors..."

ORDERS_VERSION=$(curl -s -H "Authorization: Bearer $PAT" \
    "${API_BASE}/processors/${PUTDB_ORDERS_ID}" | \
    python3 -c "import sys, json; print(json.load(sys.stdin)['revision']['version'])")

# Delete connections first
CONNECTIONS=$(curl -s -H "Authorization: Bearer $PAT" \
    "${API_BASE}/process-groups/${PG_ID}/connections")

# Find and delete connection to PutDB Orders
ORDER_CONN=$(echo "$CONNECTIONS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for conn in data['connections']:
    if conn['destinationId'] == '${PUTDB_ORDERS_ID}':
        print(conn['id'] + ':' + str(conn['revision']['version']))
        break
")

if [ -n "$ORDER_CONN" ]; then
    CONN_ID=$(echo "$ORDER_CONN" | cut -d: -f1)
    CONN_VER=$(echo "$ORDER_CONN" | cut -d: -f2)
    curl -s -X DELETE -H "Authorization: Bearer $PAT" \
        "${API_BASE}/connections/${CONN_ID}?version=${CONN_VER}" > /dev/null
    echo "  ✓ Deleted connection to PutDB Orders"
fi

# Find and delete connection to PutDB Items
ITEMS_CONN=$(echo "$CONNECTIONS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for conn in data['connections']:
    if conn['destinationId'] == '${PUTDB_ITEMS_ID}':
        print(conn['id'] + ':' + str(conn['revision']['version']))
        break
")

if [ -n "$ITEMS_CONN" ]; then
    CONN_ID=$(echo "$ITEMS_CONN" | cut -d: -f1)
    CONN_VER=$(echo "$ITEMS_CONN" | cut -d: -f2)
    curl -s -X DELETE -H "Authorization: Bearer $PAT" \
        "${API_BASE}/connections/${CONN_ID}?version=${CONN_VER}" > /dev/null
    echo "  ✓ Deleted connection to PutDB Items"
fi

# Delete processors
sleep 1
curl -s -X DELETE -H "Authorization: Bearer $PAT" \
    "${API_BASE}/processors/${PUTDB_ORDERS_ID}?version=${ORDERS_VERSION}" > /dev/null
echo "  ✓ Deleted PutDB Orders"

ITEMS_VERSION=$(curl -s -H "Authorization: Bearer $PAT" \
    "${API_BASE}/processors/${PUTDB_ITEMS_ID}" | \
    python3 -c "import sys, json; print(json.load(sys.stdin)['revision']['version'])")

curl -s -X DELETE -H "Authorization: Bearer $PAT" \
    "${API_BASE}/processors/${PUTDB_ITEMS_ID}?version=${ITEMS_VERSION}" > /dev/null
echo "  ✓ Deleted PutDB Items"

# Step 2: Fix connection pool (remove invalid driver path)
echo ""
echo "Step 2: Fixing connection pool..."

POOL_VERSION=$(curl -s -H "Authorization: Bearer $PAT" \
    "${API_BASE}/controller-services/${CONNECTION_POOL_ID}" | \
    python3 -c "import sys, json; print(json.load(sys.stdin)['revision']['version'])")

# Disable first
curl -s -X PUT -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/controller-services/${CONNECTION_POOL_ID}/run-status" \
    -d '{
        "revision": {"version": '"$POOL_VERSION"'},
        "state": "DISABLED"
    }' > /dev/null

sleep 2

# Update properties (remove driver location, it will use built-in)
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
                "Database User": "#{snowflake.username}",
                "Max Wait Time": "500 millis",
                "Max Total Connections": "8"
            }
        }
    }' > /dev/null

echo "  ✓ Fixed connection pool properties"

# Enable
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
sleep 3

# Step 3: Create new PutDatabaseRecord processors with ONLY correct properties
echo ""
echo "Step 3: Creating new PutDatabaseRecord processors..."

PUTDB_ORDERS_RESPONSE=$(curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/processors" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "type": "org.apache.nifi.processors.standard.PutDatabaseRecord",
            "bundle": {
                "group": "org.apache.nifi",
                "artifact": "nifi-standard-nar",
                "version": "2025.9.23.19"
            },
            "name": "PutDatabaseRecord - Orders",
            "config": {
                "properties": {
                    "put-db-record-record-reader": "'"$RECORD_READER_ID"'",
                    "db-type": "Generic",
                    "put-db-record-statement-type": "INSERT",
                    "put-db-record-dcbp-service": "'"$CONNECTION_POOL_ID"'",
                    "put-db-record-schema-name": "analytics_iceberg",
                    "put-db-record-table-name": "orders",
                    "put-db-record-binary-format": "UTF-8",
                    "Column Name Translation Strategy": "REMOVE_UNDERSCORE",
                    "put-db-record-allow-multiple-statements": "false",
                    "put-db-record-query-timeout": "0 seconds",
                    "rollback-on-failure": "false",
                    "table-schema-cache-size": "100"
                },
                "autoTerminatedRelationships": ["success", "failure", "retry"]
            },
            "position": {
                "x": 1000,
                "y": 200
            }
        }
    }')

NEW_PUTDB_ORDERS_ID=$(echo "$PUTDB_ORDERS_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
echo "  ✓ Created PutDatabaseRecord (Orders): $NEW_PUTDB_ORDERS_ID"

PUTDB_ITEMS_RESPONSE=$(curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/processors" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "type": "org.apache.nifi.processors.standard.PutDatabaseRecord",
            "bundle": {
                "group": "org.apache.nifi",
                "artifact": "nifi-standard-nar",
                "version": "2025.9.23.19"
            },
            "name": "PutDatabaseRecord - Order Items",
            "config": {
                "properties": {
                    "put-db-record-record-reader": "'"$RECORD_READER_ID"'",
                    "db-type": "Generic",
                    "put-db-record-statement-type": "INSERT",
                    "put-db-record-dcbp-service": "'"$CONNECTION_POOL_ID"'",
                    "put-db-record-schema-name": "analytics_iceberg",
                    "put-db-record-table-name": "order_items",
                    "put-db-record-binary-format": "UTF-8",
                    "Column Name Translation Strategy": "REMOVE_UNDERSCORE",
                    "put-db-record-allow-multiple-statements": "false",
                    "put-db-record-query-timeout": "0 seconds",
                    "rollback-on-failure": "false",
                    "table-schema-cache-size": "100"
                },
                "autoTerminatedRelationships": ["success", "failure", "retry"]
            },
            "position": {
                "x": 1000,
                "y": 400
            }
        }
    }')

NEW_PUTDB_ITEMS_ID=$(echo "$PUTDB_ITEMS_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
echo "  ✓ Created PutDatabaseRecord (Order Items): $NEW_PUTDB_ITEMS_ID"

# Step 4: Recreate connections
echo ""
echo "Step 4: Recreating connections..."

# SplitJson Orders -> PutDB Orders
curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/connections" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "name": "SplitJson Orders to PutDB Orders",
            "source": {
                "id": "'"$SPLITJSON_ORDERS_ID"'",
                "groupId": "'"$PG_ID"'",
                "type": "PROCESSOR"
            },
            "destination": {
                "id": "'"$NEW_PUTDB_ORDERS_ID"'",
                "groupId": "'"$PG_ID"'",
                "type": "PROCESSOR"
            },
            "selectedRelationships": ["split"],
            "flowFileExpiration": "0 sec",
            "backPressureDataSizeThreshold": "1 GB",
            "backPressureObjectThreshold": "10000"
        }
    }' > /dev/null

echo "  ✓ SplitJson (Orders) → PutDatabaseRecord (Orders)"

# SplitJson Items -> PutDB Items
curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/connections" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "name": "SplitJson Items to PutDB Items",
            "source": {
                "id": "'"$SPLITJSON_ITEMS_ID"'",
                "groupId": "'"$PG_ID"'",
                "type": "PROCESSOR"
            },
            "destination": {
                "id": "'"$NEW_PUTDB_ITEMS_ID"'",
                "groupId": "'"$PG_ID"'",
                "type": "PROCESSOR"
            },
            "selectedRelationships": ["split"],
            "flowFileExpiration": "0 sec",
            "backPressureDataSizeThreshold": "1 GB",
            "backPressureObjectThreshold": "10000"
        }
    }' > /dev/null

echo "  ✓ SplitJson (Order Items) → PutDatabaseRecord (Order Items)"

echo ""
echo "================================================================================"
echo "✅ Clean Rebuild Complete!"
echo "================================================================================"
echo ""
echo "New Processor IDs:"
echo "  - PutDatabaseRecord (Orders): $NEW_PUTDB_ORDERS_ID"
echo "  - PutDatabaseRecord (Order Items): $NEW_PUTDB_ITEMS_ID"
echo ""
echo "Pipeline should now be fully valid and ready to start!"
echo ""
