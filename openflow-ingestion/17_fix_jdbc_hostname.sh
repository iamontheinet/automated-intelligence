#!/bin/bash
set -e

# Get PAT from snowflake connection
PAT=$(snow connection generate-jwt --account sfsenorthamerica-gen_ai_hol --user dash --role snowflake_intelligence_admin 2>/dev/null || echo "")

if [ -z "$PAT" ]; then
    echo "❌ Failed to get PAT. Please run manually:"
    echo "   PAT=\$(snow connection generate-jwt --account sfsenorthamerica-gen_ai_hol --user dash --role snowflake_intelligence_admin)"
    echo "   export PAT"
    echo "   Then run this script again"
    exit 1
fi

API_BASE="https://of--sfsenorthamerica-gen-ai-hol.snowflakecomputing.app/dashing/nifi-api"
DBCP_SERVICE_ID="13b18417-019b-1000-ffff-ffffed76158c"

echo "Step 1: Disable DBCPConnectionPool..."
DBCP_REVISION=$(curl -s -H "Authorization: Bearer $PAT" \
    "${API_BASE}/controller-services/${DBCP_SERVICE_ID}" | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(d['revision']['version'])")

curl -s -X PUT -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/controller-services/${DBCP_SERVICE_ID}/run-status" \
    -d "{
        \"revision\": {\"version\": ${DBCP_REVISION}},
        \"state\": \"DISABLED\"
    }" > /dev/null

echo "✓ Service disabled"

# Wait for disable
sleep 2

echo "Step 2: Update JDBC connection URL..."
DBCP_REVISION=$(curl -s -H "Authorization: Bearer $PAT" \
    "${API_BASE}/controller-services/${DBCP_SERVICE_ID}" | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(d['revision']['version'])")

# Get current properties
CURRENT_PROPS=$(curl -s -H "Authorization: Bearer $PAT" \
    "${API_BASE}/controller-services/${DBCP_SERVICE_ID}" | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d['component']['properties']))")

echo "Current URL:"
echo "$CURRENT_PROPS" | python3 -c "import sys,json; p=json.load(sys.stdin); print(p.get('database-connection-url', 'N/A'))"

# Correct URL with underscore preserved in hostname
NEW_URL="jdbc:snowflake://sfsenorthamerica-gen_ai_hol.snowflakecomputing.com/?db=#{snowflake.database}&schema=#{snowflake.schema}&warehouse=#{snowflake.warehouse}&role=#{snowflake.role}"

# Update properties
UPDATE_PROPS=$(echo "$CURRENT_PROPS" | python3 -c "
import sys, json
props = json.load(sys.stdin)
props['database-connection-url'] = '$NEW_URL'
print(json.dumps(props))
")

curl -s -X PUT -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/controller-services/${DBCP_SERVICE_ID}" \
    -d "{
        \"revision\": {\"version\": ${DBCP_REVISION}},
        \"component\": {
            \"id\": \"${DBCP_SERVICE_ID}\",
            \"properties\": ${UPDATE_PROPS}
        }
    }" | python3 -c "
import sys, json
result = json.load(sys.stdin)
print('✓ URL updated to:', result['component']['properties']['database-connection-url'])
"

echo ""
echo "Step 3: Re-enable DBCPConnectionPool..."
DBCP_REVISION=$(curl -s -H "Authorization: Bearer $PAT" \
    "${API_BASE}/controller-services/${DBCP_SERVICE_ID}" | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(d['revision']['version'])")

curl -s -X PUT -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/controller-services/${DBCP_SERVICE_ID}/run-status" \
    -d "{
        \"revision\": {\"version\": ${DBCP_REVISION}},
        \"state\": \"ENABLED\"
    }" | python3 -c "
import sys, json
result = json.load(sys.stdin)
state = result['component']['state']
valid = result['component'].get('validationStatus', 'UNKNOWN')
print(f'✓ Service state: {state}, validation: {valid}')
"

echo ""
echo "✅ JDBC URL fixed! The hostname now correctly includes the underscore."
echo "   Old: sfsenorthamerica-gen-ai-hol.snowflakecomputing.com"
echo "   New: sfsenorthamerica-gen_ai_hol.snowflakecomputing.com"
