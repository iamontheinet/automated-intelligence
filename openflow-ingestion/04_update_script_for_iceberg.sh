#!/bin/bash
#
# Simplified: Update ExecuteScript to INSERT directly into Iceberg tables
#

set -e

RUNTIME_URL="https://of--sfsenorthamerica-gen-ai-hol.snowflakecomputing.app/dashing"
API_BASE="${RUNTIME_URL}/nifi-api"
EXECUTE_SCRIPT_ID="13a83e9c-019b-1000-ffff-ffffcc2cea4c"

if [ -z "$PAT" ]; then
    echo "Error: PAT environment variable not set"
    exit 1
fi

echo "================================================================================"
echo "Updating ExecuteScript to INSERT into Iceberg Tables"
echo "================================================================================"
echo ""

# Get current processor config
PROCESSOR_INFO=$(curl -s -H "Authorization: Bearer $PAT" \
    "${API_BASE}/processors/${EXECUTE_SCRIPT_ID}")

VERSION=$(echo "$PROCESSOR_INFO" | python3 -c "import sys, json; print(json.load(sys.stdin)['revision']['version'])")

# Updated Python script that INSERTs into Iceberg tables
PYTHON_SCRIPT='import json
import random
import uuid
from datetime import datetime, timedelta
import snowflake.connector
import os

flowFile = session.get()
if flowFile is None:
    exit()

# Snowflake connection
conn = snowflake.connector.connect(
    account="sfsenorthamerica-gen-ai-hol",
    user="dash",
    role="snowflake_intelligence_admin",
    warehouse="automated_intelligence_wh",
    database="automated_intelligence",
    schema="analytics_iceberg",
    authenticator="snowflake_jwt",
    private_key=open("/opt/nifi/nifi-current/rsa_key.p8", "rb").read()
)

cursor = conn.cursor()

# Generate 100 orders
num_orders = 100
orders = []
order_items = []

for _ in range(num_orders):
    order_id = str(uuid.uuid4())
    order_date = (datetime.now() - timedelta(days=random.randint(0, 7))).strftime("%Y-%m-%d %H:%M:%S")
    
    order = {
        "ORDER_ID": order_id,
        "CUSTOMER_ID": random.randint(1, 10000),
        "ORDER_DATE": order_date,
        "ORDER_STATUS": random.choice(["pending", "processing", "shipped", "delivered"]),
        "TOTAL_AMOUNT": round(random.uniform(50, 500), 2),
        "DISCOUNT_PERCENT": round(random.uniform(0, 25), 2),
        "SHIPPING_COST": round(random.uniform(5, 50), 2)
    }
    
    orders.append(order)
    
    # Generate 1-10 items per order
    num_items = random.randint(1, 10)
    for item_idx in range(num_items):
        unit_price = round(random.uniform(10, 500), 2)
        quantity = random.randint(1, 5)
        line_total = round(unit_price * quantity, 2)
        
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

# Insert orders
for order in orders:
    cursor.execute("""
        INSERT INTO orders (ORDER_ID, CUSTOMER_ID, ORDER_DATE, ORDER_STATUS, TOTAL_AMOUNT, DISCOUNT_PERCENT, SHIPPING_COST)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
    """, (
        order["ORDER_ID"],
        order["CUSTOMER_ID"],
        order["ORDER_DATE"],
        order["ORDER_STATUS"],
        order["TOTAL_AMOUNT"],
        order["DISCOUNT_PERCENT"],
        order["SHIPPING_COST"]
    ))

# Insert order items
for item in order_items:
    cursor.execute("""
        INSERT INTO order_items (ORDER_ITEM_ID, ORDER_ID, PRODUCT_ID, PRODUCT_NAME, PRODUCT_CATEGORY, QUANTITY, UNIT_PRICE, LINE_TOTAL)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
    """, (
        item["ORDER_ITEM_ID"],
        item["ORDER_ID"],
        item["PRODUCT_ID"],
        item["PRODUCT_NAME"],
        item["PRODUCT_CATEGORY"],
        item["QUANTITY"],
        item["UNIT_PRICE"],
        item["LINE_TOTAL"]
    ))

conn.commit()
cursor.close()
conn.close()

# Output summary
output = json.dumps({
    "orders_inserted": len(orders),
    "items_inserted": len(order_items),
    "timestamp": datetime.now().isoformat()
})

flowFile = session.write(flowFile, output)
session.transfer(flowFile, REL_SUCCESS)'

# URL encode the script
ENCODED_SCRIPT=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.stdin.read()))" <<< "$PYTHON_SCRIPT")

# Update the processor
curl -s -X PUT -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/processors/${EXECUTE_SCRIPT_ID}" \
    -d "{
        \"revision\": {\"version\": $VERSION},
        \"component\": {
            \"id\": \"$EXECUTE_SCRIPT_ID\",
            \"config\": {
                \"properties\": {
                    \"Script Body\": \"$ENCODED_SCRIPT\",
                    \"Script Engine\": \"python\"
                }
            }
        }
    }" > /dev/null

echo "✅ ExecuteScript processor updated!"
echo ""
echo "The script now:"
echo "  - Generates 100 orders + items"
echo "  - INSERTs directly into Iceberg tables"
echo "  - Uses Snowflake Python connector"
echo ""
echo "Next: Start the processors and watch data flow!"
echo ""
