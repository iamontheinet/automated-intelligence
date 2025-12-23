#!/bin/bash
#
# Add processors to Orders Data Generator using ExecuteScript approach
# Creates realistic synthetic data for orders and order_items
#

set -e

# Configuration
RUNTIME_URL="https://of--sfsenorthamerica-gen-ai-hol.snowflakecomputing.app/dashing"
API_BASE="${RUNTIME_URL}/nifi-api"
PG_ID="0a9f1d18-019b-1000-0000-000034cc7230"

if [ -z "$PAT" ]; then
    echo "Error: PAT environment variable not set"
    exit 1
fi

echo "================================================================================"
echo "Creating Data Generator Flow with ExecuteScript"
echo "================================================================================"
echo ""

# Python script for data generation
read -r -d '' PYTHON_SCRIPT << 'EOFSCRIPT' || true
import json
import random
import uuid
from datetime import datetime, timedelta
from java.io import InputStreamReader, OutputStreamWriter
from java.nio.charset import StandardCharsets

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
output = json.dumps({
    "orders": orders,
    "order_items": order_items
}, indent=2)

flowFile = session.write(flowFile, OutputStreamWriter, lambda writer: writer.write(output))
flowFile = session.putAttribute(flowFile, "record.count", str(len(orders)))
session.transfer(flowFile, REL_SUCCESS)
EOFSCRIPT

# Escape script for JSON
ESCAPED_SCRIPT=$(echo "$PYTHON_SCRIPT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')

# Step 1: Create GenerateFlowFile processor
echo "Step 1: Creating GenerateFlowFile processor (trigger)..."
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
GEN_VERSION=$(echo "$GEN_PROC" | python3 -c "import sys, json; print(json.load(sys.stdin)['revision']['version'])")
echo "✅ GenerateFlowFile: $GEN_ID"

# Step 2: Create ExecuteScript processor
echo "Step 2: Creating ExecuteScript processor..."
SCRIPT_PROC=$(curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/processors" \
    -d "{
        \"revision\": {\"version\": 0},
        \"component\": {
            \"type\": \"org.apache.nifi.processors.script.ExecuteScript\",
            \"name\": \"Generate Orders & Items\",
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
SCRIPT_VERSION=$(echo "$SCRIPT_PROC" | python3 -c "import sys, json; print(json.load(sys.stdin)['revision']['version'])")
echo "✅ ExecuteScript: $SCRIPT_ID"

# Step 3: Create EvaluateJsonPath to extract orders array
echo "Step 3: Creating EvaluateJsonPath for orders..."
EVAL_ORDERS=$(curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/processors" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "type": "org.apache.nifi.processors.standard.EvaluateJsonPath",
            "name": "Extract Orders Array",
            "position": {"x": 100.0, "y": 500.0},
            "config": {
                "schedulingPeriod": "0 sec",
                "schedulingStrategy": "TIMER_DRIVEN",
                "properties": {
                    "Destination": "flowfile-content",
                    "Return Type": "json",
                    "$.orders": "$.orders"
                },
                "autoTerminatedRelationships": ["failure", "unmatched"]
            }
        }
    }')

EVAL_ORDERS_ID=$(echo "$EVAL_ORDERS" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
echo "✅ EvaluateJsonPath (orders): $EVAL_ORDERS_ID"

# Step 4: Create EvaluateJsonPath to extract order_items array  
echo "Step 4: Creating EvaluateJsonPath for order items..."
EVAL_ITEMS=$(curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/processors" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "type": "org.apache.nifi.processors.standard.EvaluateJsonPath",
            "name": "Extract Order Items Array",
            "position": {"x": 500.0, "y": 500.0},
            "config": {
                "schedulingPeriod": "0 sec",
                "schedulingStrategy": "TIMER_DRIVEN",
                "properties": {
                    "Destination": "flowfile-content",
                    "Return Type": "json",
                    "$.order_items": "$.order_items"
                },
                "autoTerminatedRelationships": ["failure", "unmatched"]
            }
        }
    }')

EVAL_ITEMS_ID=$(echo "$EVAL_ITEMS" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
echo "✅ EvaluateJsonPath (order_items): $EVAL_ITEMS_ID"

echo ""
echo "================================================================================"
echo "Processors Created!"
echo "================================================================================"
echo ""
echo "✅ Trigger: $GEN_ID"
echo "✅ Data Generator: $SCRIPT_ID"
echo "✅ Orders Extractor: $EVAL_ORDERS_ID"
echo "✅ Items Extractor: $EVAL_ITEMS_ID"
echo ""
echo "Next: Create connections between processors"
