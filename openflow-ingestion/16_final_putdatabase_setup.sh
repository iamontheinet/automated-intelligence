#!/bin/bash
set -e

API_BASE="https://of--sfsenorthamerica-gen-ai-hol.snowflakecomputing.app/dashing/nifi-api"
PG_ID="0a9f1d18-019b-1000-0000-000034cc7230"
DBCP_SERVICE_ID="13b18417-019b-1000-ffff-ffffed76158c"
JSON_READER_ID="13b30762-019b-1000-ffff-ffffea3bef7f"

# Delete old PutSnowpipeStreaming2 processors
echo "Deleting PutSnowpipeStreaming2 processors..."
SNOWPIPE_ORDERS="1421f987-019b-1000-0000-00005cad2dfe"
SNOWPIPE_ITEMS="1421fb36-019b-1000-0000-000012bae471"

# Delete connections first
for conn_id in $(curl -s -H "Authorization: Bearer $PAT" \
    "${API_BASE}/process-groups/${PG_ID}/connections" | \
    python3 -c "import sys,json; [print(c['id']) for c in json.load(sys.stdin)['connections'] if c['destinationId'] in ['${SNOWPIPE_ORDERS}', '${SNOWPIPE_ITEMS}']]"); do
    conn_ver=$(curl -s -H "Authorization: Bearer $PAT" "${API_BASE}/connections/${conn_id}" | \
        python3 -c "import sys,json; print(json.load(sys.stdin)['revision']['version'])")
    curl -s -X DELETE -H "Authorization: Bearer $PAT" \
        "${API_BASE}/connections/${conn_id}?version=${conn_ver}" > /dev/null
done

# Delete processors
for proc_id in $SNOWPIPE_ORDERS $SNOWPIPE_ITEMS; do
    proc_ver=$(curl -s -H "Authorization: Bearer $PAT" "${API_BASE}/processors/${proc_id}" | \
        python3 -c "import sys,json; print(json.load(sys.stdin)['revision']['version'])")
    curl -s -X DELETE -H "Authorization: Bearer $PAT" \
        "${API_BASE}/processors/${proc_id}?version=${proc_ver}" > /dev/null
done

echo "✓ Old processors deleted"

# Create PutDatabaseRecord for Orders
echo ""
echo "Creating PutDatabaseRecord - Orders..."
PUTDB_ORDERS=$(curl -s -X POST -H "Authorization: Bearer $PAT" \
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
            "position": {"x": 1200, "y": 200},
            "config": {
                "properties": {
                    "put-db-record-record-reader": "'${JSON_READER_ID}'",
                    "put-db-record-statement-type": "INSERT",
                    "put-db-record-dcbp-service": "'${DBCP_SERVICE_ID}'",
                    "put-db-record-schema-name": "analytics_iceberg",
                    "put-db-record-table-name": "orders"
                },
                "autoTerminatedRelationships": ["success", "failure", "retry"]
            }
        }
    }' | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

echo "✓ Orders processor created: ${PUTDB_ORDERS}"

# Create PutDatabaseRecord for Order Items
echo ""
echo "Creating PutDatabaseRecord - Order Items..."
PUTDB_ITEMS=$(curl -s -X POST -H "Authorization: Bearer $PAT" \
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
            "position": {"x": 1200, "y": 400},
            "config": {
                "properties": {
                    "put-db-record-record-reader": "'${JSON_READER_ID}'",
                    "put-db-record-statement-type": "INSERT",
                    "put-db-record-dcbp-service": "'${DBCP_SERVICE_ID}'",
                    "put-db-record-schema-name": "analytics_iceberg",
                    "put-db-record-table-name": "order_items"
                },
                "autoTerminatedRelationships": ["success", "failure", "retry"]
            }
        }
    }' | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

echo "✓ Order Items processor created: ${PUTDB_ITEMS}"

# Create connections
SPLIT_ORDERS="13b30fc0-019b-1000-ffff-ffffb99bb7ec"
SPLIT_ITEMS="13b311cc-019b-1000-0000-00004c223a2f"

echo ""
echo "Creating connections..."
curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/connections" \
    -d "{
        \"revision\": {\"version\": 0},
        \"component\": {
            \"name\": \"SplitJson Orders to PutDB\",
            \"source\": {\"id\": \"${SPLIT_ORDERS}\", \"groupId\": \"${PG_ID}\", \"type\": \"PROCESSOR\"},
            \"destination\": {\"id\": \"${PUTDB_ORDERS}\", \"groupId\": \"${PG_ID}\", \"type\": \"PROCESSOR\"},
            \"selectedRelationships\": [\"split\"],
            \"flowFileExpiration\": \"0 sec\",
            \"backPressureDataSizeThreshold\": \"1 GB\",
            \"backPressureObjectThreshold\": \"10000\"
        }
    }" > /dev/null

curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/connections" \
    -d "{
        \"revision\": {\"version\": 0},
        \"component\": {
            \"name\": \"SplitJson Items to PutDB\",
            \"source\": {\"id\": \"${SPLIT_ITEMS}\", \"groupId\": \"${PG_ID}\", \"type\": \"PROCESSOR\"},
            \"destination\": {\"id\": \"${PUTDB_ITEMS}\", \"groupId\": \"${PG_ID}\", \"type\": \"PROCESSOR\"},
            \"selectedRelationships\": [\"split\"],
            \"flowFileExpiration\": \"0 sec\",
            \"backPressureDataSizeThreshold\": \"1 GB\",
            \"backPressureObjectThreshold\": \"10000\"
        }
    }" > /dev/null

echo "✓ Connections created"
echo ""
echo "Pipeline complete with PutDatabaseRecord processors using working DBCP!"
