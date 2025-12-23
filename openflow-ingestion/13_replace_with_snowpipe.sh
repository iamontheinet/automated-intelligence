#!/bin/bash
set -e

API_BASE="https://of--sfsenorthamerica-gen-ai-hol.snowflakecomputing.app/dashing/nifi-api"
PG_ID="0a9f1d18-019b-1000-0000-000034cc7230"

# Old processor IDs
OLD_CONVERTER_ORDERS="13e1f69e-019b-1000-0000-00003a683c21"
OLD_CONVERTER_ITEMS="13e1f8c6-019b-1000-0000-000048683fa8"
OLD_EXEC_SQL_ORDERS="13e1fa76-019b-1000-0000-0000411892ca"
OLD_EXEC_SQL_ITEMS="13e1fc13-019b-1000-0000-000031a6c3b9"

echo "Deleting old ExecuteSQL processors and converters..."

# Get connections to delete
CONN_TO_EXEC_ORDERS=$(curl -s -H "Authorization: Bearer $PAT" \
    "${API_BASE}/process-groups/${PG_ID}/connections" | \
    python3 -c "import sys,json; [print(c['id']) for c in json.load(sys.stdin)['connections'] if c['destinationId']=='${OLD_EXEC_SQL_ORDERS}']")

CONN_TO_EXEC_ITEMS=$(curl -s -H "Authorization: Bearer $PAT" \
    "${API_BASE}/process-groups/${PG_ID}/connections" | \
    python3 -c "import sys,json; [print(c['id']) for c in json.load(sys.stdin)['connections'] if c['destinationId']=='${OLD_EXEC_SQL_ITEMS}']")

# Delete connections
for conn_id in $CONN_TO_EXEC_ORDERS $CONN_TO_EXEC_ITEMS; do
    conn_ver=$(curl -s -H "Authorization: Bearer $PAT" "${API_BASE}/connections/${conn_id}" | \
        python3 -c "import sys,json; print(json.load(sys.stdin)['revision']['version'])")
    curl -s -X DELETE -H "Authorization: Bearer $PAT" \
        "${API_BASE}/connections/${conn_id}?version=${conn_ver}" > /dev/null
done

# Delete old processors
for proc_id in $OLD_CONVERTER_ORDERS $OLD_CONVERTER_ITEMS $OLD_EXEC_SQL_ORDERS $OLD_EXEC_SQL_ITEMS; do
    proc_ver=$(curl -s -H "Authorization: Bearer $PAT" "${API_BASE}/processors/${proc_id}" | \
        python3 -c "import sys,json; print(json.load(sys.stdin)['revision']['version'])")
    curl -s -X DELETE -H "Authorization: Bearer $PAT" \
        "${API_BASE}/processors/${proc_id}?version=${proc_ver}" > /dev/null
done

echo "✓ Old processors deleted"

# Create PutSnowpipeStreaming2 for Orders
echo "Creating PutSnowpipeStreaming2 - Orders..."
SNOWPIPE_ORDERS=$(curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/processors" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "type": "com.snowflake.openflow.runtime.processors.snowpipe.streaming.PutSnowpipeStreaming2",
            "bundle": {
                "group": "com.snowflake.openflow.runtime",
                "artifact": "runtime-snowpipe-streaming-2-processors-nar",
                "version": "2025.9.23.19"
            },
            "name": "PutSnowpipeStreaming - Orders",
            "position": {"x": 1200, "y": 200},
            "config": {
                "properties": {
                    "snowflake-connection-name": "dash-builder-si",
                    "table-name": "automated_intelligence.analytics_iceberg.orders"
                },
                "autoTerminatedRelationships": ["success", "failure"]
            }
        }
    }' | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

echo "✓ Orders processor created: ${SNOWPIPE_ORDERS}"

# Create PutSnowpipeStreaming2 for Order Items
echo "Creating PutSnowpipeStreaming2 - Order Items..."
SNOWPIPE_ITEMS=$(curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/processors" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "type": "com.snowflake.openflow.runtime.processors.snowpipe.streaming.PutSnowpipeStreaming2",
            "bundle": {
                "group": "com.snowflake.openflow.runtime",
                "artifact": "runtime-snowpipe-streaming-2-processors-nar",
                "version": "2025.9.23.19"
            },
            "name": "PutSnowpipeStreaming - Order Items",
            "position": {"x": 1200, "y": 400},
            "config": {
                "properties": {
                    "snowflake-connection-name": "dash-builder-si",
                    "table-name": "automated_intelligence.analytics_iceberg.order_items"
                },
                "autoTerminatedRelationships": ["success", "failure"]
            }
        }
    }' | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

echo "✓ Order Items processor created: ${SNOWPIPE_ITEMS}"

# Get SplitJson processor IDs
SPLIT_ORDERS="13b30fc0-019b-1000-ffff-ffffb99bb7ec"
SPLIT_ITEMS="13b311cc-019b-1000-0000-00004c223a2f"

# Create connections
echo "Creating connections..."
curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/connections" \
    -d "{
        \"revision\": {\"version\": 0},
        \"component\": {
            \"name\": \"SplitJson Orders to Snowpipe\",
            \"source\": {
                \"id\": \"${SPLIT_ORDERS}\",
                \"groupId\": \"${PG_ID}\",
                \"type\": \"PROCESSOR\"
            },
            \"destination\": {
                \"id\": \"${SNOWPIPE_ORDERS}\",
                \"groupId\": \"${PG_ID}\",
                \"type\": \"PROCESSOR\"
            },
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
            \"name\": \"SplitJson Items to Snowpipe\",
            \"source\": {
                \"id\": \"${SPLIT_ITEMS}\",
                \"groupId\": \"${PG_ID}\",
                \"type\": \"PROCESSOR\"
            },
            \"destination\": {
                \"id\": \"${SNOWPIPE_ITEMS}\",
                \"groupId\": \"${PG_ID}\",
                \"type\": \"PROCESSOR\"
            },
            \"selectedRelationships\": [\"split\"],
            \"flowFileExpiration\": \"0 sec\",
            \"backPressureDataSizeThreshold\": \"1 GB\",
            \"backPressureObjectThreshold\": \"10000\"
        }
    }" > /dev/null

echo "✓ Connections created"
echo ""
echo "Pipeline replaced with PutSnowpipeStreaming2 processors"
echo "  Orders: ${SNOWPIPE_ORDERS}"
echo "  Items: ${SNOWPIPE_ITEMS}"
