#!/bin/bash
#
# Step 5: Create connections between processors
#

set -e

RUNTIME_URL="https://of--sfsenorthamerica-gen-ai-hol.snowflakecomputing.app/dashing"
API_BASE="${RUNTIME_URL}/nifi-api"
PG_ID="0a9f1d18-019b-1000-0000-000034cc7230"

# Processor IDs
GENERATE_FLOWFILE_ID="13a83a8c-019b-1000-0000-00007d4f39b6"
EXECUTE_SCRIPT_ID="13a83e9c-019b-1000-ffff-ffffcc2cea4c"
SPLITJSON_ORDERS_ID="13b30fc0-019b-1000-ffff-ffffb99bb7ec"
SPLITJSON_ITEMS_ID="13b311cc-019b-1000-0000-00004c223a2f"
PUTDB_ORDERS_ID="13b313a1-019b-1000-0000-00001de9bb39"
PUTDB_ITEMS_ID="13b316fb-019b-1000-0000-000079b848f8"

if [ -z "$PAT" ]; then
    echo "Error: PAT environment variable not set"
    exit 1
fi

echo "================================================================================"
echo "Creating Openflow Pipeline Connections"
echo "================================================================================"
echo ""

# Connection 1: GenerateFlowFile -> ExecuteScript
echo "1. Creating: GenerateFlowFile → ExecuteScript"
curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/connections" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "name": "GenerateFlowFile to ExecuteScript",
            "source": {
                "id": "'"$GENERATE_FLOWFILE_ID"'",
                "groupId": "'"$PG_ID"'",
                "type": "PROCESSOR"
            },
            "destination": {
                "id": "'"$EXECUTE_SCRIPT_ID"'",
                "groupId": "'"$PG_ID"'",
                "type": "PROCESSOR"
            },
            "selectedRelationships": ["success"],
            "flowFileExpiration": "0 sec",
            "backPressureDataSizeThreshold": "1 GB",
            "backPressureObjectThreshold": "10000"
        }
    }' > /dev/null

echo "   ✓ Created"

# Connection 2: ExecuteScript -> SplitJson (Orders)
echo "2. Creating: ExecuteScript → SplitJson (Orders)"
curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/connections" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "name": "ExecuteScript to SplitJson Orders",
            "source": {
                "id": "'"$EXECUTE_SCRIPT_ID"'",
                "groupId": "'"$PG_ID"'",
                "type": "PROCESSOR"
            },
            "destination": {
                "id": "'"$SPLITJSON_ORDERS_ID"'",
                "groupId": "'"$PG_ID"'",
                "type": "PROCESSOR"
            },
            "selectedRelationships": ["success"],
            "flowFileExpiration": "0 sec",
            "backPressureDataSizeThreshold": "1 GB",
            "backPressureObjectThreshold": "10000"
        }
    }' > /dev/null

echo "   ✓ Created"

# Connection 3: ExecuteScript -> SplitJson (Order Items)  
echo "3. Creating: ExecuteScript → SplitJson (Order Items)"
curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/connections" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "name": "ExecuteScript to SplitJson Items",
            "source": {
                "id": "'"$EXECUTE_SCRIPT_ID"'",
                "groupId": "'"$PG_ID"'",
                "type": "PROCESSOR"
            },
            "destination": {
                "id": "'"$SPLITJSON_ITEMS_ID"'",
                "groupId": "'"$PG_ID"'",
                "type": "PROCESSOR"
            },
            "selectedRelationships": ["success"],
            "flowFileExpiration": "0 sec",
            "backPressureDataSizeThreshold": "1 GB",
            "backPressureObjectThreshold": "10000"
        }
    }' > /dev/null

echo "   ✓ Created"

# Connection 4: SplitJson (Orders) -> PutDatabaseRecord (Orders)
echo "4. Creating: SplitJson (Orders) → PutDatabaseRecord (Orders)"
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
                "id": "'"$PUTDB_ORDERS_ID"'",
                "groupId": "'"$PG_ID"'",
                "type": "PROCESSOR"
            },
            "selectedRelationships": ["split"],
            "flowFileExpiration": "0 sec",
            "backPressureDataSizeThreshold": "1 GB",
            "backPressureObjectThreshold": "10000"
        }
    }' > /dev/null

echo "   ✓ Created"

# Connection 5: SplitJson (Order Items) -> PutDatabaseRecord (Order Items)
echo "5. Creating: SplitJson (Order Items) → PutDatabaseRecord (Order Items)"
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
                "id": "'"$PUTDB_ITEMS_ID"'",
                "groupId": "'"$PG_ID"'",
                "type": "PROCESSOR"
            },
            "selectedRelationships": ["split"],
            "flowFileExpiration": "0 sec",
            "backPressureDataSizeThreshold": "1 GB",
            "backPressureObjectThreshold": "10000"
        }
    }' > /dev/null

echo "   ✓ Created"

echo ""
echo "================================================================================"
echo "✅ All Connections Created!"
echo "================================================================================"
echo ""
echo "Pipeline Flow:"
echo "  GenerateFlowFile → ExecuteScript → SplitJson → PutDatabaseRecord → Iceberg"
echo ""
echo "Next Steps:"
echo "  1. Open Openflow UI:"
echo "     https://of--sfsenorthamerica-gen-ai-hol.snowflakecomputing.app/dashing/nifi"
echo ""
echo "  2. Start all processors (right-click process group → Start)"
echo ""
echo "  3. Verify data in Iceberg tables:"
echo "     SELECT COUNT(*) FROM automated_intelligence.analytics_iceberg.orders;"
echo ""
