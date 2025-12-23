#!/bin/bash
set -e

API_BASE="https://of--sfsenorthamerica-gen-ai-hol.snowflakecomputing.app/dashing/nifi-api"
PG_ID="0a9f1d18-019b-1000-0000-000034cc7230"

# ExecuteSQL processor IDs
EXEC_SQL_ORDERS="13e1fa76-019b-1000-0000-0000411892ca"
EXEC_SQL_ITEMS="13e1fc13-019b-1000-0000-000031a6c3b9"

echo "Updating ExecuteSQL - Orders..."
ORDERS_VERSION=$(curl -s -H "Authorization: Bearer $PAT" \
    "${API_BASE}/processors/${EXEC_SQL_ORDERS}" | \
    python3 -c "import sys,json; print(json.load(sys.stdin)['revision']['version'])")

curl -s -X PUT -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/processors/${EXEC_SQL_ORDERS}" \
    -d "{
        \"revision\": {\"version\": ${ORDERS_VERSION}},
        \"component\": {
            \"id\": \"${EXEC_SQL_ORDERS}\",
            \"config\": {
                \"properties\": {
                    \"SQL\": \"\${flowfile_content}\",
                    \"snowflake-connection-name\": \"dash-builder-si\"
                }
            }
        }
    }" > /dev/null

echo "✓ ExecuteSQL - Orders updated"

echo "Updating ExecuteSQL - Order Items..."
ITEMS_VERSION=$(curl -s -H "Authorization: Bearer $PAT" \
    "${API_BASE}/processors/${EXEC_SQL_ITEMS}" | \
    python3 -c "import sys,json; print(json.load(sys.stdin)['revision']['version'])")

curl -s -X PUT -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/processors/${EXEC_SQL_ITEMS}" \
    -d "{
        \"revision\": {\"version\": ${ITEMS_VERSION}},
        \"component\": {
            \"id\": \"${EXEC_SQL_ITEMS}\",
            \"config\": {
                \"properties\": {
                    \"SQL\": \"\${flowfile_content}\",
                    \"snowflake-connection-name\": \"dash-builder-si\"
                }
            }
        }
    }" > /dev/null

echo "✓ ExecuteSQL - Order Items updated"
echo ""
echo "Checking validation status..."

curl -s -H "Authorization: Bearer $PAT" \
    "${API_BASE}/processors/${EXEC_SQL_ORDERS}" | \
    python3 -c "
import sys, json
data = json.load(sys.stdin)
status = data['component'].get('validationStatus', 'UNKNOWN')
print(f'Orders processor: {status}')
errors = data['component'].get('validationErrors', [])
for err in errors:
    print(f'  - {err}')
"

curl -s -H "Authorization: Bearer $PAT" \
    "${API_BASE}/processors/${EXEC_SQL_ITEMS}" | \
    python3 -c "
import sys, json
data = json.load(sys.stdin)
status = data['component'].get('validationStatus', 'UNKNOWN')
print(f'Order Items processor: {status}')
errors = data['component'].get('validationErrors', [])
for err in errors:
    print(f'  - {err}')
"

echo ""
echo "ExecuteSQL processors configured to use flowfile content and Snowflake connection"
