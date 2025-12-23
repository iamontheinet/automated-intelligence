#!/bin/bash
#
# Update ExecuteScript processor to use Groovy (not Python)
#

set -e

RUNTIME_URL="https://of--sfsenorthamerica-gen-ai-hol.snowflakecomputing.app/dashing"
API_BASE="${RUNTIME_URL}/nifi-api"
EXECUTE_SCRIPT_ID="13a83e9c-019b-1000-ffff-ffffcc2cea4c"

if [ -z "$PAT" ]; then
    echo "Error: PAT environment variable not set"
    exit 1
fi

echo "Updating ExecuteScript processor to use Groovy..."

# Groovy script to generate orders and order_items JSON
GROOVY_SCRIPT=$(cat <<'GROOVY_EOF'
import groovy.json.JsonOutput
import java.nio.charset.StandardCharsets

def flowFile = session.get()
if (flowFile == null) return

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
(1..100).each { i ->
    def orderId = UUID.randomUUID().toString()
    def customerId = random.nextInt(1000) + 1
    def orderDate = new Date(baseTime - random.nextInt(90) * 24 * 60 * 60 * 1000L)
    def orderStatus = orderStatuses[random.nextInt(orderStatuses.size())]
    def discountPercent = random.nextInt(30)
    def shippingCost = 5.00 + random.nextDouble() * 20.00
    
    // Generate 1-5 items per order
    def numItems = random.nextInt(5) + 1
    def totalAmount = 0.0
    
    (1..numItems).each { j ->
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
    
    // Apply discount
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

def jsonString = JsonOutput.toJson(output)

// Write to flowfile
flowFile = session.write(flowFile, { outputStream ->
    outputStream.write(jsonString.getBytes(StandardCharsets.UTF_8))
} as OutputStreamCallback)

session.transfer(flowFile, REL_SUCCESS)
GROOVY_EOF
)

# Update processor with Groovy script
curl -s -X PUT -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/processors/${EXECUTE_SCRIPT_ID}" \
    -d '{
        "revision": {"version": 6},
        "component": {
            "id": "'"$EXECUTE_SCRIPT_ID"'",
            "config": {
                "properties": {
                    "Script Engine": "Groovy",
                    "Script Body": '"$(echo "$GROOVY_SCRIPT" | jq -Rs .)"'
                }
            }
        }
    }' > /dev/null

echo "✅ ExecuteScript processor updated to use Groovy"
echo ""
echo "The processor now:"
echo "  - Uses Groovy (not Python)"
echo "  - Generates 100 orders + items per execution"
echo "  - Outputs JSON with orders[] and order_items[] arrays"
echo ""
echo "Next: Start the processors in Openflow UI"
