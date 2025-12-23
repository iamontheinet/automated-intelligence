#!/bin/bash
#
# Step 4: Add PutSnowflake Processors and Wire Connections
# Completes the Openflow → Iceberg data pipeline
#

set -e

# Configuration
RUNTIME_URL="https://of--sfsenorthamerica-gen-ai-hol.snowflakecomputing.app/dashing"
API_BASE="${RUNTIME_URL}/nifi-api"
PG_ID="0a9f1d18-019b-1000-0000-000034cc7230"
PARAM_CONTEXT_ID="0a9f168b-019b-1000-0000-00002778ece2"
RSA_KEY_ASSET_ID="48a1600a-ba09-304b-8103-2a7d7e8635ae"

# Processor IDs from step 3
GENERATE_FLOWFILE_ID="13a83a8c-019b-1000-0000-00007d4f39b6"
EXECUTE_SCRIPT_ID="13a83e9c-019b-1000-ffff-ffffcc2cea4c"

if [ -z "$PAT" ]; then
    echo "Error: PAT environment variable not set"
    exit 1
fi

echo "================================================================================"
echo "Adding PutSnowflake Processors and Connections"
echo "================================================================================"
echo ""

# ============================================================================
# Step 1: Add SplitJson processor to separate orders and order_items
# ============================================================================

echo "Step 1: Adding SplitJson processor..."

SPLITJSON_RESPONSE=$(curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/processors" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "type": "org.apache.nifi.processors.standard.SplitJson",
            "bundle": {
                "group": "org.apache.nifi",
                "artifact": "nifi-standard-nar",
                "version": "2.0.0"
            },
            "name": "SplitJson - Orders",
            "config": {
                "properties": {
                    "JsonPath Expression": "$.orders",
                    "Null Value Representation": "empty string"
                },
                "autoTerminatedRelationships": ["failure", "original"]
            },
            "position": {
                "x": 400,
                "y": 200
            }
        }
    }')

SPLITJSON_ORDERS_ID=$(echo "$SPLITJSON_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
echo "  SplitJson (Orders) created: $SPLITJSON_ORDERS_ID"

# Add second SplitJson for order_items
SPLITJSON_ITEMS_RESPONSE=$(curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/processors" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "type": "org.apache.nifi.processors.standard.SplitJson",
            "bundle": {
                "group": "org.apache.nifi",
                "artifact": "nifi-standard-nar",
                "version": "2.0.0"
            },
            "name": "SplitJson - Order Items",
            "config": {
                "properties": {
                    "JsonPath Expression": "$.order_items",
                    "Null Value Representation": "empty string"
                },
                "autoTerminatedRelationships": ["failure", "original"]
            },
            "position": {
                "x": 400,
                "y": 400
            }
        }
    }')

SPLITJSON_ITEMS_ID=$(echo "$SPLITJSON_ITEMS_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
echo "  SplitJson (Order Items) created: $SPLITJSON_ITEMS_ID"

# ============================================================================
# Step 2: Create SnowflakeConnectionPool controller service
# ============================================================================

echo ""
echo "Step 2: Creating SnowflakeConnectionPool controller service..."

# First, get the controller services endpoint for the process group
CONTROLLER_SERVICE_RESPONSE=$(curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/controller-services" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "type": "org.apache.nifi.snowflake.service.SnowflakeConnectionProviderService",
            "bundle": {
                "group": "org.apache.nifi",
                "artifact": "nifi-snowflake-nar",
                "version": "2.0.0"
            },
            "name": "SnowflakeConnectionPool",
            "properties": {
                "account-url": "https://sfsenorthamerica-gen-ai-hol.snowflakecomputing.com",
                "username": "#{snowflake.user}",
                "authentication-method": "key-pair",
                "private-key-source": "private-key-asset",
                "private-key-asset": "'"$RSA_KEY_ASSET_ID"'",
                "database": "#{snowflake.database}",
                "schema": "#{snowflake.schema}",
                "warehouse": "#{snowflake.warehouse}",
                "role": "#{snowflake.role}"
            }
        }
    }')

CONTROLLER_SERVICE_ID=$(echo "$CONTROLLER_SERVICE_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
echo "  SnowflakeConnectionPool created: $CONTROLLER_SERVICE_ID"

# Enable the controller service
echo "  Enabling controller service..."
curl -s -X PUT -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/controller-services/${CONTROLLER_SERVICE_ID}/run-status" \
    -d '{
        "revision": {"version": 0},
        "state": "ENABLED"
    }' > /dev/null

echo "  Controller service enabled"

# ============================================================================
# Step 3: Add PutSnowflake processor for orders table
# ============================================================================

echo ""
echo "Step 3: Adding PutSnowflake processor for orders..."

PUTSNOWFLAKE_ORDERS_RESPONSE=$(curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/processors" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "type": "org.apache.nifi.processors.snowflake.PutSnowflake",
            "bundle": {
                "group": "org.apache.nifi",
                "artifact": "nifi-snowflake-nar",
                "version": "2.0.0"
            },
            "name": "PutSnowflake - Orders",
            "config": {
                "properties": {
                    "snowflake-connection-provider": "'"$CONTROLLER_SERVICE_ID"'",
                    "table": "#{snowflake.table.orders}",
                    "source-data-format": "JSON",
                    "json-format": "JSON",
                    "ingestion-method": "snowpipe-streaming"
                },
                "autoTerminatedRelationships": ["success", "failure"]
            },
            "position": {
                "x": 700,
                "y": 200
            }
        }
    }')

PUTSNOWFLAKE_ORDERS_ID=$(echo "$PUTSNOWFLAKE_ORDERS_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
echo "  PutSnowflake (Orders) created: $PUTSNOWFLAKE_ORDERS_ID"

# ============================================================================
# Step 4: Add PutSnowflake processor for order_items table
# ============================================================================

echo ""
echo "Step 4: Adding PutSnowflake processor for order_items..."

PUTSNOWFLAKE_ITEMS_RESPONSE=$(curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/processors" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "type": "org.apache.nifi.processors.snowflake.PutSnowflake",
            "bundle": {
                "group": "org.apache.nifi",
                "artifact": "nifi-snowflake-nar",
                "version": "2.0.0"
            },
            "name": "PutSnowflake - Order Items",
            "config": {
                "properties": {
                    "snowflake-connection-provider": "'"$CONTROLLER_SERVICE_ID"'",
                    "table": "#{snowflake.table.order_items}",
                    "source-data-format": "JSON",
                    "json-format": "JSON",
                    "ingestion-method": "snowpipe-streaming"
                },
                "autoTerminatedRelationships": ["success", "failure"]
            },
            "position": {
                "x": 700,
                "y": 400
            }
        }
    }')

PUTSNOWFLAKE_ITEMS_ID=$(echo "$PUTSNOWFLAKE_ITEMS_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
echo "  PutSnowflake (Order Items) created: $PUTSNOWFLAKE_ITEMS_ID"

# ============================================================================
# Step 5: Create connections between processors
# ============================================================================

echo ""
echo "Step 5: Creating connections..."

# Connection 1: GenerateFlowFile -> ExecuteScript
curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/connections" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "source": {"id": "'"$GENERATE_FLOWFILE_ID"'", "type": "PROCESSOR"},
            "destination": {"id": "'"$EXECUTE_SCRIPT_ID"'", "type": "PROCESSOR"},
            "selectedRelationships": ["success"]
        }
    }' > /dev/null

echo "  GenerateFlowFile -> ExecuteScript"

# Connection 2: ExecuteScript -> SplitJson (Orders)
curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/connections" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "source": {"id": "'"$EXECUTE_SCRIPT_ID"'", "type": "PROCESSOR"},
            "destination": {"id": "'"$SPLITJSON_ORDERS_ID"'", "type": "PROCESSOR"},
            "selectedRelationships": ["success"]
        }
    }' > /dev/null

echo "  ExecuteScript -> SplitJson (Orders)"

# Connection 3: ExecuteScript -> SplitJson (Order Items)
curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/connections" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "source": {"id": "'"$EXECUTE_SCRIPT_ID"'", "type": "PROCESSOR"},
            "destination": {"id": "'"$SPLITJSON_ITEMS_ID"'", "type": "PROCESSOR"},
            "selectedRelationships": ["success"]
        }
    }' > /dev/null

echo "  ExecuteScript -> SplitJson (Order Items)"

# Connection 4: SplitJson (Orders) -> PutSnowflake (Orders)
curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/connections" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "source": {"id": "'"$SPLITJSON_ORDERS_ID"'", "type": "PROCESSOR"},
            "destination": {"id": "'"$PUTSNOWFLAKE_ORDERS_ID"'", "type": "PROCESSOR"},
            "selectedRelationships": ["split"]
        }
    }' > /dev/null

echo "  SplitJson (Orders) -> PutSnowflake (Orders)"

# Connection 5: SplitJson (Order Items) -> PutSnowflake (Order Items)
curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/connections" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "source": {"id": "'"$SPLITJSON_ITEMS_ID"'", "type": "PROCESSOR"},
            "destination": {"id": "'"$PUTSNOWFLAKE_ITEMS_ID"'", "type": "PROCESSOR"},
            "selectedRelationships": ["split"]
        }
    }' > /dev/null

echo "  SplitJson (Order Items) -> PutSnowflake (Order Items)"

echo ""
echo "================================================================================"
echo "✅ Complete Flow Created!"
echo "================================================================================"
echo ""
echo "Processors:"
echo "  - GenerateFlowFile: $GENERATE_FLOWFILE_ID"
echo "  - ExecuteScript: $EXECUTE_SCRIPT_ID"
echo "  - SplitJson (Orders): $SPLITJSON_ORDERS_ID"
echo "  - SplitJson (Order Items): $SPLITJSON_ITEMS_ID"
echo "  - PutSnowflake (Orders): $PUTSNOWFLAKE_ORDERS_ID"
echo "  - PutSnowflake (Order Items): $PUTSNOWFLAKE_ITEMS_ID"
echo ""
echo "Controller Service:"
echo "  - SnowflakeConnectionPool: $CONTROLLER_SERVICE_ID (ENABLED)"
echo ""
echo "Next Steps:"
echo "  1. Visit NiFi UI and start all processors"
echo "  2. Monitor for data flow"
echo "  3. Validate data in Iceberg tables:"
echo ""
echo "     SELECT COUNT(*) FROM automated_intelligence.analytics_iceberg.orders;"
echo "     SELECT COUNT(*) FROM automated_intelligence.analytics_iceberg.order_items;"
echo ""
echo "Process Group URL: https://of--sfsenorthamerica-gen-ai-hol.snowflakecomputing.app/dashing/nifi/?processGroupId=${PG_ID}"
echo ""
