#!/bin/bash
#
# Add processors to Orders Data Generator process group
# Creates GenerateFlowFile, UpdateAttribute, JoltTransformJSON, and PutSnowflake processors
#

set -e

# Configuration
RUNTIME_URL="https://of--sfsenorthamerica-gen-ai-hol.snowflakecomputing.app/dashing"
API_BASE="${RUNTIME_URL}/nifi-api"
PG_ID="0a9f1d18-019b-1000-0000-000034cc7230"  # From previous step

# Check PAT token
if [ -z "$PAT" ]; then
    echo "Error: PAT environment variable not set"
    exit 1
fi

echo "================================================================================"
echo "Adding Processors to Orders Data Generator"
echo "================================================================================"
echo ""

# Step 1: Create GenerateFlowFile processor
echo "Step 1: Creating GenerateFlowFile processor..."
GEN_PROC=$(curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/processors" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "type": "org.apache.nifi.processors.standard.GenerateFlowFile",
            "name": "Generate Orders",
            "position": {"x": 200.0, "y": 200.0},
            "config": {
                "schedulingPeriod": "10 sec",
                "schedulingStrategy": "TIMER_DRIVEN",
                "properties": {
                    "File Size": "1 KB",
                    "Batch Size": "1",
                    "Data Format": "Text",
                    "Unique FlowFiles": "false",
                    "Custom Text": "{}"
                },
                "autoTerminatedRelationships": []
            }
        }
    }')

GEN_ID=$(echo "$GEN_PROC" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
echo "✅ GenerateFlowFile processor created: $GEN_ID"
echo ""

# Step 2: Create UpdateAttribute processor to add order data
echo "Step 2: Creating UpdateAttribute processor..."
UPDATE_PROC=$(curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/processors" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "type": "org.apache.nifi.processors.attributes.UpdateAttribute",
            "name": "Add Order Fields",
            "position": {"x": 200.0, "y": 350.0},
            "config": {
                "schedulingPeriod": "0 sec",
                "schedulingStrategy": "TIMER_DRIVEN",
                "properties": {
                    "order_id": "${UUID()}",
                    "customer_id": "${random():mod(10000):plus(1)}",
                    "order_date": "${now():format(\"yyyy-MM-dd HH:mm:ss\")}",
                    "order_status": "pending",
                    "total_amount": "${random():mod(50000):plus(1000):divide(100)}",
                    "discount_percent": "${random():mod(30)}",
                    "shipping_cost": "${random():mod(5000):plus(500):divide(100)}"
                },
                "autoTerminatedRelationships": []
            }
        }
    }')

UPDATE_ID=$(echo "$UPDATE_PROC" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
echo "✅ UpdateAttribute processor created: $UPDATE_ID"
echo ""

# Step 3: Create EvaluateJsonPath processor to extract attributes as JSON content
echo "Step 3: Creating EvaluateJsonPath processor..."
EVAL_PROC=$(curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/processors" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "type": "org.apache.nifi.processors.standard.EvaluateJsonPath",
            "name": "Build Order JSON",
            "position": {"x": 200.0, "y": 500.0},
            "config": {
                "schedulingPeriod": "0 sec",
                "schedulingStrategy": "TIMER_DRIVEN",
                "properties": {
                    "Destination": "flowfile-content",
                    "Return Type": "json",
                    "order_json": "${literal('{\"ORDER_ID\":\"'):append(${order_id}):append('\",\"CUSTOMER_ID\":'):append(${customer_id}):append(',\"ORDER_DATE\":\"'):append(${order_date}):append('\",\"ORDER_STATUS\":\"'):append(${order_status}):append('\",\"TOTAL_AMOUNT\":'):append(${total_amount}):append(',\"DISCOUNT_PERCENT\":'):append(${discount_percent}):append(',\"SHIPPING_COST\":'):append(${shipping_cost}):append('}')}"
                },
                "autoTerminatedRelationships": ["failure", "unmatched"]
            }
        }
    }')

EVAL_ID=$(echo "$EVAL_PROC" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
echo "✅ EvaluateJsonPath processor created: $EVAL_ID"
echo ""

echo "================================================================================"
echo "Processors Created Successfully!"
echo "================================================================================"
echo ""
echo "📦 GenerateFlowFile: $GEN_ID"
echo "✏️  UpdateAttribute: $UPDATE_ID"
echo "📝 EvaluateJsonPath: $EVAL_ID"
echo ""
echo "Next: Create connections and add PutSnowflake processor"
echo ""
