#!/bin/bash
#
# Replace ExecuteScript with ExecuteGroovyScript processor (better for Groovy)
#

set -e

RUNTIME_URL="https://of--sfsenorthamerica-gen-ai-hol.snowflakecomputing.app/dashing"
API_BASE="${RUNTIME_URL}/nifi-api"
PG_ID="0a9f1d18-019b-1000-0000-000034cc7230"
OLD_EXECUTE_SCRIPT_ID="13a83e9c-019b-1000-ffff-ffffcc2cea4c"

if [ -z "$PAT" ]; then
    echo "Error: PAT environment variable not set"
    exit 1
fi

echo "================================================================================"
echo "Replacing ExecuteScript with ExecuteGroovyScript"
echo "================================================================================"
echo ""

# Step 1: Stop the old processor (if running)
echo "Step 1: Stopping old ExecuteScript processor..."
curl -s -X PUT -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/processors/${OLD_EXECUTE_SCRIPT_ID}/run-status" \
    -d '{
        "revision": {"version": 7},
        "state": "STOPPED"
    }' > /dev/null
echo "  ✓ Stopped"

# Step 2: Get incoming connection IDs
echo ""
echo "Step 2: Getting connection details..."
CONNECTIONS=$(curl -s -H "Authorization: Bearer $PAT" \
    "${API_BASE}/process-groups/${PG_ID}/connections")

INCOMING_CONN_ID=$(echo "$CONNECTIONS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for conn in data['connections']:
    if conn['destinationId'] == '${OLD_EXECUTE_SCRIPT_ID}':
        print(conn['id'])
        break
")

echo "  Incoming connection: $INCOMING_CONN_ID"

# Get outgoing connection IDs
OUTGOING_CONN_IDS=$(echo "$CONNECTIONS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for conn in data['connections']:
    if conn['sourceId'] == '${OLD_EXECUTE_SCRIPT_ID}':
        print(conn['id'])
")

echo "  Outgoing connections: $(echo "$OUTGOING_CONN_IDS" | wc -l | xargs)"

# Step 3: Delete old connections
echo ""
echo "Step 3: Deleting old connections..."
if [ -n "$INCOMING_CONN_ID" ]; then
    INCOMING_VERSION=$(echo "$CONNECTIONS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for conn in data['connections']:
    if conn['id'] == '${INCOMING_CONN_ID}':
        print(conn['revision']['version'])
        break
")
    curl -s -X DELETE -H "Authorization: Bearer $PAT" \
        "${API_BASE}/connections/${INCOMING_CONN_ID}?version=${INCOMING_VERSION}" > /dev/null
    echo "  ✓ Deleted incoming connection"
fi

for CONN_ID in $OUTGOING_CONN_IDS; do
    CONN_VERSION=$(echo "$CONNECTIONS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for conn in data['connections']:
    if conn['id'] == '${CONN_ID}':
        print(conn['revision']['version'])
        break
")
    curl -s -X DELETE -H "Authorization: Bearer $PAT" \
        "${API_BASE}/connections/${CONN_ID}?version=${CONN_VERSION}" > /dev/null
    echo "  ✓ Deleted outgoing connection: $CONN_ID"
done

# Step 4: Delete old processor
echo ""
echo "Step 4: Deleting old ExecuteScript processor..."
sleep 1
curl -s -X DELETE -H "Authorization: Bearer $PAT" \
    "${API_BASE}/processors/${OLD_EXECUTE_SCRIPT_ID}?version=7" > /dev/null
echo "  ✓ Deleted"

# Step 5: Create new ExecuteGroovyScript processor
echo ""
echo "Step 5: Creating ExecuteGroovyScript processor..."

GROOVY_SCRIPT=$(cat <<'GROOVY_EOF'
import groovy.json.JsonOutput

def flowFile = session.get()
if (!flowFile) return

// Generate 100 orders
def orders = []
def orderItems = []

def orderStatuses = ['completed', 'pending', 'shipped', 'cancelled']
def productCategories = ['Electronics', 'Clothing', 'Home & Garden', 'Sports', 'Books']
def productNames = [
    'Laptop', 'Smartphone', 'Headphones', 'Monitor', 'Keyboard',
    'T-Shirt', 'Jeans', 'Jacket', 'Shoes', 'Hat',
    'Sofa', 'Lamp', 'Rug', 'Plant', 'Desk',
    'Basketball', 'Tennis Racket', 'Yoga Mat', 'Dumbbell', 'Bicycle',
    'Novel', 'Cookbook', 'Magazine', 'Comic', 'Textbook'
]

def random = new Random()
def baseTime = System.currentTimeMillis()

// Generate 100 orders
100.times { i ->
    def orderId = UUID.randomUUID().toString()
    def customerId = random.nextInt(1000) + 1
    def orderDate = new Date(baseTime - random.nextInt(90) * 24 * 60 * 60 * 1000L)
    def orderStatus = orderStatuses[random.nextInt(orderStatuses.size())]
    def discountPercent = random.nextInt(30)
    def shippingCost = 5.00 + random.nextDouble() * 20.00
    
    // Generate 1-5 items per order
    def numItems = random.nextInt(5) + 1
    def totalAmount = 0.0
    
    numItems.times { j ->
        def orderItemId = UUID.randomUUID().toString()
        def productId = random.nextInt(1000) + 1
        def productName = productNames[random.nextInt(productNames.size())]
        def productCategory = productCategories[random.nextInt(productCategories.size())]
        def quantity = random.nextInt(5) + 1
        def unitPrice = 10.00 + random.nextDouble() * 490.00
        def lineTotal = quantity * unitPrice
        
        totalAmount += lineTotal
        
        orderItems << [
            ORDER_ITEM_ID: orderItemId,
            ORDER_ID: orderId,
            PRODUCT_ID: productId,
            PRODUCT_NAME: productName,
            PRODUCT_CATEGORY: productCategory,
            QUANTITY: quantity,
            UNIT_PRICE: Math.round(unitPrice * 100) / 100.0,
            LINE_TOTAL: Math.round(lineTotal * 100) / 100.0
        ]
    }
    
    totalAmount = totalAmount * (1 - discountPercent / 100.0) + shippingCost
    
    orders << [
        ORDER_ID: orderId,
        CUSTOMER_ID: customerId,
        ORDER_DATE: orderDate.format("yyyy-MM-dd'T'HH:mm:ss"),
        ORDER_STATUS: orderStatus,
        TOTAL_AMOUNT: Math.round(totalAmount * 100) / 100.0,
        DISCOUNT_PERCENT: discountPercent,
        SHIPPING_COST: Math.round(shippingCost * 100) / 100.0
    ]
}

// Create JSON output
def output = [
    orders: orders,
    order_items: orderItems,
    generated_at: new Date().format("yyyy-MM-dd'T'HH:mm:ss"),
    record_count: [
        orders: orders.size(),
        order_items: orderItems.size()
    ]
]

flowFile = session.write(flowFile) { outputStream ->
    outputStream.write(JsonOutput.toJson(output).bytes)
}

session.transfer(flowFile, REL_SUCCESS)
GROOVY_EOF
)

GROOVY_RESPONSE=$(curl -s -X POST -H "Authorization: Bearer $PAT" \
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
            "name": "Generate Orders & Items (Groovy)",
            "config": {
                "properties": {
                    "Script Body": '"$(echo "$GROOVY_SCRIPT" | jq -Rs .)"'
                },
                "autoTerminatedRelationships": ["failure"]
            },
            "position": {
                "x": 400,
                "y": 300
            }
        }
    }')

NEW_PROCESSOR_ID=$(echo "$GROOVY_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
echo "  ✓ Created: $NEW_PROCESSOR_ID"

# Step 6: Recreate connections
echo ""
echo "Step 6: Recreating connections..."

# Incoming: GenerateFlowFile -> ExecuteGroovyScript
curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/connections" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "name": "GenerateFlowFile to ExecuteGroovyScript",
            "source": {
                "id": "13a83a8c-019b-1000-0000-00007d4f39b6",
                "groupId": "'"$PG_ID"'",
                "type": "PROCESSOR"
            },
            "destination": {
                "id": "'"$NEW_PROCESSOR_ID"'",
                "groupId": "'"$PG_ID"'",
                "type": "PROCESSOR"
            },
            "selectedRelationships": ["success"],
            "flowFileExpiration": "0 sec",
            "backPressureDataSizeThreshold": "1 GB",
            "backPressureObjectThreshold": "10000"
        }
    }' > /dev/null
echo "  ✓ GenerateFlowFile → ExecuteGroovyScript"

# Outgoing: ExecuteGroovyScript -> SplitJson (Orders)
curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/connections" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "name": "ExecuteGroovyScript to SplitJson Orders",
            "source": {
                "id": "'"$NEW_PROCESSOR_ID"'",
                "groupId": "'"$PG_ID"'",
                "type": "PROCESSOR"
            },
            "destination": {
                "id": "13b30fc0-019b-1000-ffff-ffffb99bb7ec",
                "groupId": "'"$PG_ID"'",
                "type": "PROCESSOR"
            },
            "selectedRelationships": ["success"],
            "flowFileExpiration": "0 sec",
            "backPressureDataSizeThreshold": "1 GB",
            "backPressureObjectThreshold": "10000"
        }
    }' > /dev/null
echo "  ✓ ExecuteGroovyScript → SplitJson (Orders)"

# Outgoing: ExecuteGroovyScript -> SplitJson (Order Items)
curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}/connections" \
    -d '{
        "revision": {"version": 0},
        "component": {
            "name": "ExecuteGroovyScript to SplitJson Items",
            "source": {
                "id": "'"$NEW_PROCESSOR_ID"'",
                "groupId": "'"$PG_ID"'",
                "type": "PROCESSOR"
            },
            "destination": {
                "id": "13b311cc-019b-1000-0000-00004c223a2f",
                "groupId": "'"$PG_ID"'",
                "type": "PROCESSOR"
            },
            "selectedRelationships": ["success"],
            "flowFileExpiration": "0 sec",
            "backPressureDataSizeThreshold": "1 GB",
            "backPressureObjectThreshold": "10000"
        }
    }' > /dev/null
echo "  ✓ ExecuteGroovyScript → SplitJson (Order Items)"

echo ""
echo "================================================================================"
echo "✅ Successfully Replaced with ExecuteGroovyScript!"
echo "================================================================================"
echo ""
echo "New Processor ID: $NEW_PROCESSOR_ID"
echo ""
echo "Pipeline Flow:"
echo "  GenerateFlowFile → ExecuteGroovyScript → SplitJson → PutDatabaseRecord → Iceberg"
echo ""
echo "Next Steps:"
echo "  1. Open Openflow UI and start all processors"
echo "  2. Verify data flows into Iceberg tables"
echo ""
