#!/bin/bash
#
# Step 3: Complete Openflow → Iceberg Implementation
# Uses Openflow REST API to create complete data generator flow writing to Iceberg
#

set -e

# Configuration
RUNTIME_URL="https://of--sfsenorthamerica-gen-ai-hol.snowflakecomputing.app/dashing"
API_BASE="${RUNTIME_URL}/nifi-api"
PG_ID="0a9f1d18-019b-1000-0000-000034cc7230"  # Existing process group
PARAM_CONTEXT_ID="0a9f168b-019b-1000-0000-00002778ece2"  # Existing parameter context

if [ -z "$PAT" ]; then
    echo "Error: PAT environment variable not set"
    exit 1
fi

echo "================================================================================"
echo "Completing Openflow → Iceberg Data Generator"
echo "================================================================================"
echo ""
echo "Process Group: $PG_ID"
echo "Parameter Context: $PARAM_CONTEXT_ID"
echo ""

# ============================================================================
# Step 1: Update parameter context with Iceberg table targets
# ============================================================================

echo "Step 1: Updating parameter context for Iceberg tables..."

# Get current parameter context version
CONTEXT_INFO=$(curl -s -H "Authorization: Bearer $PAT" \
    "${API_BASE}/parameter-contexts/${PARAM_CONTEXT_ID}")

CONTEXT_VERSION=$(echo "$CONTEXT_INFO" | python3 -c "import sys, json; print(json.load(sys.stdin)['revision']['version'])")

# Update with Iceberg schema and tables
UPDATED_CONTEXT=$(curl -s -X PUT -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/parameter-contexts/${PARAM_CONTEXT_ID}" \
    -d "{
        \"revision\": {\"version\": $CONTEXT_VERSION},
        \"component\": {
            \"id\": \"$PARAM_CONTEXT_ID\",
            \"parameters\": [
                {
                    \"parameter\": {
                        \"name\": \"snowflake.account\",
                        \"description\": \"Snowflake account identifier\",
                        \"sensitive\": false,
                        \"value\": \"sfsenorthamerica-gen_ai_hol\"
                    }
                },
                {
                    \"parameter\": {
                        \"name\": \"snowflake.username\",
                        \"description\": \"Snowflake username\",
                        \"sensitive\": false,
                        \"value\": \"dash\"
                    }
                },
                {
                    \"parameter\": {
                        \"name\": \"snowflake.role\",
                        \"description\": \"Snowflake role\",
                        \"sensitive\": false,
                        \"value\": \"snowflake_intelligence_admin\"
                    }
                },
                {
                    \"parameter\": {
                        \"name\": \"snowflake.warehouse\",
                        \"description\": \"Snowflake warehouse\",
                        \"sensitive\": false,
                        \"value\": \"automated_intelligence_wh\"
                    }
                },
                {
                    \"parameter\": {
                        \"name\": \"snowflake.database\",
                        \"description\": \"Snowflake database\",
                        \"sensitive\": false,
                        \"value\": \"AUTOMATED_INTELLIGENCE\"
                    }
                },
                {
                    \"parameter\": {
                        \"name\": \"snowflake.schema\",
                        \"description\": \"Snowflake schema (Iceberg)\",
                        \"sensitive\": false,
                        \"value\": \"ANALYTICS_ICEBERG\"
                    }
                },
                {
                    \"parameter\": {
                        \"name\": \"snowflake.table.orders\",
                        \"description\": \"Orders Iceberg table name\",
                        \"sensitive\": false,
                        \"value\": \"orders\"
                    }
                },
                {
                    \"parameter\": {
                        \"name\": \"snowflake.table.order_items\",
                        \"description\": \"Order items Iceberg table name\",
                        \"sensitive\": false,
                        \"value\": \"order_items\"
                    }
                },
                {
                    \"parameter\": {
                        \"name\": \"snowflake.private.key\",
                        \"description\": \"RSA private key for authentication\",
                        \"sensitive\": true,
                        \"value\": null,
                        \"referencedAssets\": [
                            {\"id\": \"48a1600a-ba09-304b-8103-2a7d7e8635ae\", \"name\": \"rsa_key.p8\"}
                        ]
                    }
                }
            ]
        }
    }")

echo "✅ Parameter context updated for Iceberg tables"
echo ""

# ============================================================================
# Step 2: Create processors for data generation
# ============================================================================

echo "Step 2: Creating data generator processors..."

# Python script for generating orders and order_items
read -r -d '' PYTHON_SCRIPT << 'EOFSCRIPT' || true
import json
import random
import uuid
from datetime import datetime, timedelta

flowFile = session.get()
if flowFile is None:
    exit()

# Generate orders batch
orders = []
order_items = []
num_orders = 100

for _ in range(num_orders):
    order_id = str(uuid.uuid4())
    order_date = (datetime.now() - timedelta(days=random.randint(0, 7))).strftime("%Y-%m-%d %H:%M:%S")
    
    order = {
        "ORDER_ID": order_id,
        "CUSTOMER_ID": random.randint(1, 10000),
        "ORDER_DATE": order_date,
        "ORDER_STATUS": random.choice(["pending", "processing", "shipped", "delivered"]),
        "TOTAL_AMOUNT": 0,
        "DISCOUNT_PERCENT": round(random.uniform(0, 25), 2),
        "SHIPPING_COST": round(random.uniform(5, 50), 2)
    }
    
    # Generate 1-10 items per order
    num_items = random.randint(1, 10)
    order_total = 0
    
    for item_idx in range(num_items):
        unit_price = round(random.uniform(10, 500), 2)
        quantity = random.randint(1, 5)
        line_total = round(unit_price * quantity, 2)
        order_total += line_total
        
        order_items.append({
            "ORDER_ITEM_ID": f"{order_id}-{item_idx}",
            "ORDER_ID": order_id,
            "PRODUCT_ID": random.randint(1, 1000),
            "PRODUCT_NAME": f"Product_{random.randint(1, 1000)}",
            "PRODUCT_CATEGORY": random.choice(["Electronics", "Clothing", "Home", "Books", "Sports"]),
            "QUANTITY": quantity,
            "UNIT_PRICE": unit_price,
            "LINE_TOTAL": line_total
        })
    
    order["TOTAL_AMOUNT"] = round(order_total + order["SHIPPING_COST"], 2)
    orders.append(order)

# Output as JSON with both arrays
from org.apache.nifi.processor.io import OutputStreamCallback

class WriteCallback(OutputStreamCallback):
    def __init__(self, data):
        self.data = data
    
    def process(self, outputStream):
        outputStream.write(self.data.encode('utf-8'))

output = json.dumps({
    "orders": orders,
    "order_items": order_items
}, indent=2)

flowFile = session.write(flowFile, WriteCallback(output))
flowFile = session.putAttribute(flowFile, "record.count", str(len(orders)))
session.transfer(flowFile, REL_SUCCESS)
EOFSCRIPT

# Escape script for JSON
ESCAPED_SCRIPT=$(echo "$PYTHON_SCRIPT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')

# Create GenerateFlowFile processor (trigger)
echo "  Creating GenerateFlowFile processor..."
GEN_PROC=$(curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/processors" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "type": "org.apache.nifi.processors.standard.GenerateFlowFile",
            "name": "Trigger Data Generation",
            "position": {"x": 300.0, "y": 200.0},
            "config": {
                "schedulingPeriod": "10 sec",
                "schedulingStrategy": "TIMER_DRIVEN",
                "properties": {
                    "File Size": "1 B",
                    "Batch Size": "1",
                    "Data Format": "Text",
                    "Unique FlowFiles": "false"
                },
                "autoTerminatedRelationships": []
            }
        }
    }')

GEN_ID=$(echo "$GEN_PROC" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
echo "  ✅ GenerateFlowFile: $GEN_ID"

# Create ExecuteScript processor
echo "  Creating ExecuteScript processor..."
SCRIPT_PROC=$(curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/processors" \
    -d "{
        \"revision\": {\"version\": 0},
        \"component\": {
            \"type\": \"org.apache.nifi.processors.script.ExecuteScript\",
            \"name\": \"Generate Orders & Items (Python)\",
            \"position\": {\"x\": 300.0, \"y\": 350.0},
            \"config\": {
                \"schedulingPeriod\": \"0 sec\",
                \"schedulingStrategy\": \"TIMER_DRIVEN\",
                \"properties\": {
                    \"Script Engine\": \"python\",
                    \"Script Body\": $ESCAPED_SCRIPT
                },
                \"autoTerminatedRelationships\": [\"failure\"]
            }
        }
    }")

SCRIPT_ID=$(echo "$SCRIPT_PROC" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
echo "  ✅ ExecuteScript: $SCRIPT_ID"

echo ""
echo "================================================================================"
echo "✅ Processors Created!"
echo "================================================================================"
echo ""
echo "GenerateFlowFile ID: $GEN_ID"
echo "ExecuteScript ID: $SCRIPT_ID"
echo ""
echo "Next Steps:"
echo "  1. Create connections between processors"
echo "  2. Add SplitJson and PutSnowflake processors for Iceberg ingestion"
echo "  3. Start the flow"
echo "  4. Validate data in Iceberg tables"
echo ""
echo "Process Group URL: ${RUNTIME_URL}/nifi/?processGroupId=${PG_ID}"
echo ""
