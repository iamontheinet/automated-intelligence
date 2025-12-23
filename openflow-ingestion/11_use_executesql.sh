#!/bin/bash
#
# Replace PutDatabaseRecord with ExecuteSQLStatement processors
#

set -e

RUNTIME_URL="https://of--sfsenorthamerica-gen-ai-hol.snowflakecomputing.app/dashing"
API_BASE="${RUNTIME_URL}/nifi-api"
PG_ID="0a9f1d18-019b-1000-0000-000034cc7230"

SPLITJSON_ORDERS_ID="13b30fc0-019b-1000-ffff-ffffb99bb7ec"
SPLITJSON_ITEMS_ID="13b311cc-019b-1000-0000-00004c223a2f"
PUTDB_ORDERS_ID="13d0f657-019b-1000-0000-000051ea1f36"
PUTDB_ITEMS_ID="13d0f816-019b-1000-0000-00004e8d9db3"

if [ -z "$PAT" ]; then
    echo "Error: PAT environment variable not set"
    exit 1
fi

echo "================================================================================"
echo "Replacing PutDatabaseRecord with ExecuteSQLStatement"
echo "================================================================================"
echo ""

# Step 1: Delete old PutDatabaseRecord processors
echo "Step 1: Deleting PutDatabaseRecord processors..."

# Get connections
CONNECTIONS=$(curl -s -H "Authorization: Bearer $PAT" \
    "${API_BASE}/process-groups/${PG_ID}/connections")

# Delete connection to PutDB Orders
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

# Delete connection to PutDB Items
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
ORDERS_VERSION=$(curl -s -H "Authorization: Bearer $PAT" \
    "${API_BASE}/processors/${PUTDB_ORDERS_ID}" | \
    python3 -c "import sys, json; print(json.load(sys.stdin)['revision']['version'])")

curl -s -X DELETE -H "Authorization: Bearer $PAT" \
    "${API_BASE}/processors/${PUTDB_ORDERS_ID}?version=${ORDERS_VERSION}" > /dev/null
echo "  ✓ Deleted PutDB Orders"

ITEMS_VERSION=$(curl -s -H "Authorization: Bearer $PAT" \
    "${API_BASE}/processors/${PUTDB_ITEMS_ID}" | \
    python3 -c "import sys, json; print(json.load(sys.stdin)['revision']['version'])")

curl -s -X DELETE -H "Authorization: Bearer $PAT" \
    "${API_BASE}/processors/${PUTDB_ITEMS_ID}?version=${ITEMS_VERSION}" > /dev/null
echo "  ✓ Deleted PutDB Items"

# Step 2: Create ExecuteScript processors to convert JSON to SQL
echo ""
echo "Step 2: Creating JSON-to-SQL converters..."

# Script to convert orders JSON to INSERT SQL
ORDERS_SQL_SCRIPT=$(cat <<'GROOVY_EOF'
import groovy.json.JsonSlurper

def flowFile = session.get()
if (!flowFile) return

// Read JSON
def json = new JsonSlurper().parseText(session.read(flowFile).getText('UTF-8'))

// Build INSERT statement
def sql = """INSERT INTO automated_intelligence.analytics_iceberg.orders 
(ORDER_ID, CUSTOMER_ID, ORDER_DATE, ORDER_STATUS, TOTAL_AMOUNT, DISCOUNT_PERCENT, SHIPPING_COST)
VALUES ('${json.ORDER_ID}', ${json.CUSTOMER_ID}, '${json.ORDER_DATE}', '${json.ORDER_STATUS}', ${json.TOTAL_AMOUNT}, ${json.DISCOUNT_PERCENT}, ${json.SHIPPING_COST})"""

// Write SQL to flowfile
flowFile = session.write(flowFile) { outputStream ->
    outputStream.write(sql.bytes)
}

flowFile = session.putAttribute(flowFile, 'sql.statement', sql)
session.transfer(flowFile, REL_SUCCESS)
GROOVY_EOF
)

ORDERS_CONVERTER_RESPONSE=$(curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/processors" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "type": "org.apache.nifi.processors.groovyx.ExecuteGroovyScript",
            "bundle": {
                "group": "org.apache.nifi",
                "artifact": "nifi-groovyx-nar",
                "version": "2025.9.23.19"
            },
            "name": "Convert Orders to SQL",
            "config": {
                "properties": {
                    "groovyx-script-body": '"$(echo "$ORDERS_SQL_SCRIPT" | jq -Rs .)"'
                },
                "autoTerminatedRelationships": ["failure"]
            },
            "position": {
                "x": 800,
                "y": 200
            }
        }
    }')

ORDERS_CONVERTER_ID=$(echo "$ORDERS_CONVERTER_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
echo "  ✓ Created Orders SQL Converter: $ORDERS_CONVERTER_ID"

# Script to convert order_items JSON to INSERT SQL
ITEMS_SQL_SCRIPT=$(cat <<'GROOVY_EOF'
import groovy.json.JsonSlurper

def flowFile = session.get()
if (!flowFile) return

// Read JSON
def json = new JsonSlurper().parseText(session.read(flowFile).getText('UTF-8'))

// Build INSERT statement
def sql = """INSERT INTO automated_intelligence.analytics_iceberg.order_items 
(ORDER_ITEM_ID, ORDER_ID, PRODUCT_ID, PRODUCT_NAME, PRODUCT_CATEGORY, QUANTITY, UNIT_PRICE, LINE_TOTAL)
VALUES ('${json.ORDER_ITEM_ID}', '${json.ORDER_ID}', ${json.PRODUCT_ID}, '${json.PRODUCT_NAME}', '${json.PRODUCT_CATEGORY}', ${json.QUANTITY}, ${json.UNIT_PRICE}, ${json.LINE_TOTAL})"""

// Write SQL to flowfile
flowFile = session.write(flowFile) { outputStream ->
    outputStream.write(sql.bytes)
}

flowFile = session.putAttribute(flowFile, 'sql.statement', sql)
session.transfer(flowFile, REL_SUCCESS)
GROOVY_EOF
)

ITEMS_CONVERTER_RESPONSE=$(curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/processors" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "type": "org.apache.nifi.processors.groovyx.ExecuteGroovyScript",
            "bundle": {
                "group": "org.apache.nifi",
                "artifact": "nifi-groovyx-nar",
                "version": "2025.9.23.19"
            },
            "name": "Convert Order Items to SQL",
            "config": {
                "properties": {
                    "groovyx-script-body": '"$(echo "$ITEMS_SQL_SCRIPT" | jq -Rs .)"'
                },
                "autoTerminatedRelationships": ["failure"]
            },
            "position": {
                "x": 800,
                "y": 400
            }
        }
    }')

ITEMS_CONVERTER_ID=$(echo "$ITEMS_CONVERTER_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
echo "  ✓ Created Order Items SQL Converter: $ITEMS_CONVERTER_ID"

# Step 3: Create ExecuteSQLStatement processors
echo ""
echo "Step 3: Creating ExecuteSQLStatement processors..."

EXEC_SQL_ORDERS_RESPONSE=$(curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/processors" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "type": "com.snowflake.openflow.runtime.processors.database.ExecuteSQLStatement",
            "bundle": {
                "group": "com.snowflake.openflow.runtime",
                "artifact": "runtime-database-processors-nar",
                "version": "2025.9.23.19"
            },
            "name": "ExecuteSQL - Orders",
            "config": {
                "properties": {
                    "snowflake-connection-name": "dash-builder-si",
                    "sql-statement-source": "flowfile-content"
                },
                "autoTerminatedRelationships": ["success", "failure"]
            },
            "position": {
                "x": 1100,
                "y": 200
            }
        }
    }')

EXEC_SQL_ORDERS_ID=$(echo "$EXEC_SQL_ORDERS_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
echo "  ✓ Created ExecuteSQL (Orders): $EXEC_SQL_ORDERS_ID"

EXEC_SQL_ITEMS_RESPONSE=$(curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/processors" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "type": "com.snowflake.openflow.runtime.processors.database.ExecuteSQLStatement",
            "bundle": {
                "group": "com.snowflake.openflow.runtime",
                "artifact": "runtime-database-processors-nar",
                "version": "2025.9.23.19"
            },
            "name": "ExecuteSQL - Order Items",
            "config": {
                "properties": {
                    "snowflake-connection-name": "dash-builder-si",
                    "sql-statement-source": "flowfile-content"
                },
                "autoTerminatedRelationships": ["success", "failure"]
            },
            "position": {
                "x": 1100,
                "y": 400
            }
        }
    }')

EXEC_SQL_ITEMS_ID=$(echo "$EXEC_SQL_ITEMS_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
echo "  ✓ Created ExecuteSQL (Order Items): $EXEC_SQL_ITEMS_ID"

# Step 4: Create connections
echo ""
echo "Step 4: Creating connections..."

# SplitJson Orders -> Convert Orders
curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/connections" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "name": "SplitJson to Convert Orders",
            "source": {
                "id": "'"$SPLITJSON_ORDERS_ID"'",
                "groupId": "'"$PG_ID"'",
                "type": "PROCESSOR"
            },
            "destination": {
                "id": "'"$ORDERS_CONVERTER_ID"'",
                "groupId": "'"$PG_ID"'",
                "type": "PROCESSOR"
            },
            "selectedRelationships": ["split"],
            "flowFileExpiration": "0 sec",
            "backPressureDataSizeThreshold": "1 GB",
            "backPressureObjectThreshold": "10000"
        }
    }' > /dev/null
echo "  ✓ SplitJson (Orders) → Convert to SQL"

# Convert Orders -> ExecuteSQL Orders
curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/connections" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "name": "Convert to ExecuteSQL Orders",
            "source": {
                "id": "'"$ORDERS_CONVERTER_ID"'",
                "groupId": "'"$PG_ID"'",
                "type": "PROCESSOR"
            },
            "destination": {
                "id": "'"$EXEC_SQL_ORDERS_ID"'",
                "groupId": "'"$PG_ID"'",
                "type": "PROCESSOR"
            },
            "selectedRelationships": ["success"],
            "flowFileExpiration": "0 sec",
            "backPressureDataSizeThreshold": "1 GB",
            "backPressureObjectThreshold": "10000"
        }
    }' > /dev/null
echo "  ✓ Convert Orders → ExecuteSQL (Orders)"

# SplitJson Items -> Convert Items
curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/connections" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "name": "SplitJson to Convert Items",
            "source": {
                "id": "'"$SPLITJSON_ITEMS_ID"'",
                "groupId": "'"$PG_ID"'",
                "type": "PROCESSOR"
            },
            "destination": {
                "id": "'"$ITEMS_CONVERTER_ID"'",
                "groupId": "'"$PG_ID"'",
                "type": "PROCESSOR"
            },
            "selectedRelationships": ["split"],
            "flowFileExpiration": "0 sec",
            "backPressureDataSizeThreshold": "1 GB",
            "backPressureObjectThreshold": "10000"
        }
    }' > /dev/null
echo "  ✓ SplitJson (Order Items) → Convert to SQL"

# Convert Items -> ExecuteSQL Items
curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/connections" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "name": "Convert to ExecuteSQL Items",
            "source": {
                "id": "'"$ITEMS_CONVERTER_ID"'",
                "groupId": "'"$PG_ID"'",
                "type": "PROCESSOR"
            },
            "destination": {
                "id": "'"$EXEC_SQL_ITEMS_ID"'",
                "groupId": "'"$PG_ID"'",
                "type": "PROCESSOR"
            },
            "selectedRelationships": ["success"],
            "flowFileExpiration": "0 sec",
            "backPressureDataSizeThreshold": "1 GB",
            "backPressureObjectThreshold": "10000"
        }
    }' > /dev/null
echo "  ✓ Convert Order Items → ExecuteSQL (Order Items)"

echo ""
echo "================================================================================"
echo "✅ Pipeline Rebuilt with ExecuteSQLStatement!"
echo "================================================================================"
echo ""
echo "New Pipeline Flow:"
echo "  GenerateFlowFile → ExecuteGroovyScript → SplitJson"
echo "    → Convert to SQL → ExecuteSQL → Iceberg Tables"
echo ""
echo "New Processor IDs:"
echo "  - Convert Orders to SQL: $ORDERS_CONVERTER_ID"
echo "  - Convert Order Items to SQL: $ITEMS_CONVERTER_ID"
echo "  - ExecuteSQL (Orders): $EXEC_SQL_ORDERS_ID"
echo "  - ExecuteSQL (Order Items): $EXEC_SQL_ITEMS_ID"
echo ""
echo "This approach:"
echo "  ✓ Avoids DBCP connection pool issues"
echo "  ✓ Uses Openflow's native Snowflake connectivity"
echo "  ✓ Uses connection: dash-builder-si"
echo ""
echo "Start all processors in Openflow UI!"
echo ""
