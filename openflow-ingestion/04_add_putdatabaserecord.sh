#!/bin/bash
#
# Step 4: Complete Openflow → Iceberg Pipeline
# Uses PutDatabaseRecord with JDBC connection to insert into Iceberg tables
#

set -e

RUNTIME_URL="https://of--sfsenorthamerica-gen-ai-hol.snowflakecomputing.app/dashing"
API_BASE="${RUNTIME_URL}/nifi-api"
PG_ID="0a9f1d18-019b-1000-0000-000034cc7230"
PARAM_CONTEXT_ID="0a9f168b-019b-1000-0000-00002778ece2"

# Processor IDs from step 3
GENERATE_FLOWFILE_ID="13a83a8c-019b-1000-0000-00007d4f39b6"
EXECUTE_SCRIPT_ID="13a83e9c-019b-1000-ffff-ffffcc2cea4c"

if [ -z "$PAT" ]; then
    echo "Error: PAT environment variable not set"
    exit 1
fi

echo "================================================================================"
echo "Setting up Openflow → Iceberg Data Pipeline"
echo "================================================================================"
echo ""

# ============================================================================
# Step 1: Create DBCPConnectionPool controller service for Snowflake
# ============================================================================

echo "Step 1: Creating Snowflake JDBC Connection Pool..."

CONNECTION_POOL_RESPONSE=$(curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/controller-services" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "type": "org.apache.nifi.dbcp.DBCPConnectionPool",
            "bundle": {
                "group": "org.apache.nifi",
                "artifact": "nifi-dbcp-service-nar",
                "version": "2025.9.23.19"
            },
            "name": "SnowflakeConnectionPool"
        }
    }')

CONNECTION_POOL_ID=$(echo "$CONNECTION_POOL_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
CONNECTION_POOL_VERSION=$(echo "$CONNECTION_POOL_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['revision']['version'])")
echo "  Connection Pool created: $CONNECTION_POOL_ID"

# Update with properties
echo "  Configuring connection pool..."
sleep 1
curl -s -X PUT -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/controller-services/${CONNECTION_POOL_ID}" \
    -d '{
        "revision": {"version": '"$CONNECTION_POOL_VERSION"'},
        "component": {
            "id": "'"$CONNECTION_POOL_ID"'",
            "properties": {
                "Database Connection URL": "jdbc:snowflake://sfsenorthamerica-gen-ai-hol.snowflakecomputing.com/?warehouse=automated_intelligence_wh&db=automated_intelligence&schema=analytics_iceberg&role=snowflake_intelligence_admin",
                "Database Driver Class Name": "net.snowflake.client.jdbc.SnowflakeDriver",
                "database-driver-locations": "/opt/nifi/nifi-current/lib/snowflake-jdbc.jar",
                "Database User": "#{snowflake.user}",
                "Max Wait Time": "500 millis",
                "Max Total Connections": "8",
                "Validation-query": "SELECT 1"
            }
        }
    }' > /dev/null

echo "  Connection pool configured"

# Enable the controller service
echo "  Enabling connection pool..."
sleep 2
curl -s -X PUT -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/controller-services/${CONNECTION_POOL_ID}/run-status" \
    -d '{
        "revision": {"version": 1},
        "state": "ENABLED"
    }' > /dev/null

echo "  Connection pool enabled"

# ============================================================================
# Step 2: Create JsonRecordSetWriter controller service
# ============================================================================

echo ""
echo "Step 2: Creating JsonRecordSetWriter..."

RECORD_WRITER_RESPONSE=$(curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/controller-services" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "type": "org.apache.nifi.json.JsonRecordSetWriter",
            "bundle": {
                "group": "org.apache.nifi",
                "artifact": "nifi-record-serialization-services-nar",
                "version": "2025.9.23.19"
            },
            "name": "JsonRecordSetWriter"
        }
    }')

RECORD_WRITER_ID=$(echo "$RECORD_WRITER_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
echo "  JsonRecordSetWriter created: $RECORD_WRITER_ID"

# Enable it directly (JsonRecordSetWriter has default properties)
sleep 1
curl -s -X PUT -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/controller-services/${RECORD_WRITER_ID}/run-status" \
    -d '{
        "revision": {"version": 1},
        "state": "ENABLED"
    }' > /dev/null

echo "  JsonRecordSetWriter enabled"

# ============================================================================
# Step 3: Create JsonTreeReader controller service
# ============================================================================

echo ""
echo "Step 3: Creating JsonTreeReader..."

RECORD_READER_RESPONSE=$(curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/controller-services" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "type": "org.apache.nifi.json.JsonTreeReader",
            "bundle": {
                "group": "org.apache.nifi",
                "artifact": "nifi-record-serialization-services-nar",
                "version": "2025.9.23.19"
            },
            "name": "JsonTreeReader"
        }
    }')

RECORD_READER_ID=$(echo "$RECORD_READER_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
echo "  JsonTreeReader created: $RECORD_READER_ID"

# Enable it directly (JsonTreeReader has default properties)
sleep 1
curl -s -X PUT -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/controller-services/${RECORD_READER_ID}/run-status" \
    -d '{
        "revision": {"version": 1},
        "state": "ENABLED"
    }' > /dev/null

echo "  JsonTreeReader enabled"

# ============================================================================
# Step 4: Add SplitJson processor to separate orders and order_items
# ============================================================================

echo ""
echo "Step 4: Adding SplitJson processors..."

# SplitJson for orders
SPLITJSON_ORDERS_RESPONSE=$(curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/processors" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "type": "org.apache.nifi.processors.standard.SplitJson",
            "bundle": {
                "group": "org.apache.nifi",
                "artifact": "nifi-standard-nar",
                "version": "2025.9.23.19"
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

SPLITJSON_ORDERS_ID=$(echo "$SPLITJSON_ORDERS_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
echo "  SplitJson (Orders) created: $SPLITJSON_ORDERS_ID"

# SplitJson for order_items
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
                "version": "2025.9.23.19"
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
# Step 5: Add PutDatabaseRecord processors for Iceberg tables
# ============================================================================

echo ""
echo "Step 5: Adding PutDatabaseRecord processors..."

# PutDatabaseRecord for orders
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
                    "put-db-record-dcbp-service": "'"$CONNECTION_POOL_ID"'",
                    "put-db-record-record-reader": "'"$RECORD_READER_ID"'",
                    "table-name": "orders",
                    "catalog-name": "",
                    "schema-name": "analytics_iceberg",
                    "statement-type": "INSERT",
                    "field-containing-sql": "",
                    "allow-multiple-statements": "false",
                    "quote-identifiers": "false",
                    "quote-table-identifier": "false",
                    "query-timeout": "0 seconds",
                    "rollback-on-failure": "false",
                    "table-schema-cache-size": "100",
                    "max-batch-size": "0"
                },
                "autoTerminatedRelationships": ["success", "failure", "retry"]
            },
            "position": {
                "x": 700,
                "y": 200
            }
        }
    }')

PUTDB_ORDERS_ID=$(echo "$PUTDB_ORDERS_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
echo "  PutDatabaseRecord (Orders) created: $PUTDB_ORDERS_ID"

# PutDatabaseRecord for order_items
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
                    "put-db-record-dcbp-service": "'"$CONNECTION_POOL_ID"'",
                    "put-db-record-record-reader": "'"$RECORD_READER_ID"'",
                    "table-name": "order_items",
                    "catalog-name": "",
                    "schema-name": "analytics_iceberg",
                    "statement-type": "INSERT",
                    "field-containing-sql": "",
                    "allow-multiple-statements": "false",
                    "quote-identifiers": "false",
                    "quote-table-identifier": "false",
                    "query-timeout": "0 seconds",
                    "rollback-on-failure": "false",
                    "table-schema-cache-size": "100",
                    "max-batch-size": "0"
                },
                "autoTerminatedRelationships": ["success", "failure", "retry"]
            },
            "position": {
                "x": 700,
                "y": 400
            }
        }
    }')

PUTDB_ITEMS_ID=$(echo "$PUTDB_ITEMS_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
echo "  PutDatabaseRecord (Order Items) created: $PUTDB_ITEMS_ID"

# ============================================================================
# Step 6: Create connections between processors
# ============================================================================

echo ""
echo "Step 6: Creating connections..."

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

echo "  ✓ GenerateFlowFile → ExecuteScript"

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

echo "  ✓ ExecuteScript → SplitJson (Orders)"

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

echo "  ✓ ExecuteScript → SplitJson (Order Items)"

# Connection 4: SplitJson (Orders) -> PutDatabaseRecord (Orders)
curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/connections" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "source": {"id": "'"$SPLITJSON_ORDERS_ID"'", "type": "PROCESSOR"},
            "destination": {"id": "'"$PUTDB_ORDERS_ID"'", "type": "PROCESSOR"},
            "selectedRelationships": ["split"]
        }
    }' > /dev/null

echo "  ✓ SplitJson (Orders) → PutDatabaseRecord (Orders)"

# Connection 5: SplitJson (Order Items) -> PutDatabaseRecord (Order Items)
curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/connections" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "source": {"id": "'"$SPLITJSON_ITEMS_ID"'", "type": "PROCESSOR"},
            "destination": {"id": "'"$PUTDB_ITEMS_ID"'", "type": "PROCESSOR"},
            "selectedRelationships": ["split"]
        }
    }' > /dev/null

echo "  ✓ SplitJson (Order Items) → PutDatabaseRecord (Order Items)"

echo ""
echo "================================================================================"
echo "✅ Complete Openflow → Iceberg Pipeline Created!"
echo "================================================================================"
echo ""
echo "Flow: GenerateFlowFile → ExecuteScript → SplitJson → PutDatabaseRecord → Iceberg"
echo ""
echo "Controller Services:"
echo "  - SnowflakeConnectionPool: $CONNECTION_POOL_ID (ENABLED)"
echo "  - JsonTreeReader: $RECORD_READER_ID (ENABLED)"
echo "  - JsonRecordSetWriter: $RECORD_WRITER_ID (ENABLED)"
echo ""
echo "Processors:"
echo "  - GenerateFlowFile: $GENERATE_FLOWFILE_ID"
echo "  - ExecuteScript: $EXECUTE_SCRIPT_ID"
echo "  - SplitJson (Orders): $SPLITJSON_ORDERS_ID"
echo "  - SplitJson (Order Items): $SPLITJSON_ITEMS_ID"
echo "  - PutDatabaseRecord (Orders): $PUTDB_ORDERS_ID"
echo "  - PutDatabaseRecord (Order Items): $PUTDB_ITEMS_ID"
echo ""
echo "Next Steps:"
echo "  1. Start all processors in NiFi UI"
echo "  2. Monitor data flow (every 10 seconds)"
echo "  3. Verify data in Iceberg tables:"
echo ""
echo "     SELECT COUNT(*) FROM automated_intelligence.analytics_iceberg.orders;"
echo "     SELECT COUNT(*) FROM automated_intelligence.analytics_iceberg.order_items;"
echo ""
echo "  4. Check S3 for Parquet files:"
echo "     - s3://bucket/ai/orders/"
echo "     - s3://bucket/ai/order_items/"
echo ""
echo "Process Group URL:"
echo "https://of--sfsenorthamerica-gen-ai-hol.snowflakecomputing.app/dashing/nifi/?processGroupId=${PG_ID}"
echo ""
