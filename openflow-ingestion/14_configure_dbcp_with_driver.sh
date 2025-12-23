#!/bin/bash
set -e

API_BASE="https://of--sfsenorthamerica-gen-ai-hol.snowflakecomputing.app/dashing/nifi-api"
PG_ID="0a9f1d18-019b-1000-0000-000034cc7230"
PARAM_CONTEXT_ID="0a9f168b-019b-1000-0000-00002778ece2"
DBCP_SERVICE_ID="13b18417-019b-1000-ffff-ffffed76158c"
ASSET_ID="4d3bee4d-08f9-303a-85cc-bc1eee47f13f"

echo "Step 1: Add JDBC driver parameter to parameter context..."
CONTEXT_VERSION=$(curl -s -H "Authorization: Bearer $PAT" \
    "${API_BASE}/parameter-contexts/${PARAM_CONTEXT_ID}" | \
    python3 -c "import sys,json; print(json.load(sys.stdin)['revision']['version'])")

curl -s -X PUT -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/parameter-contexts/${PARAM_CONTEXT_ID}" \
    -d "{
        \"revision\": {\"version\": ${CONTEXT_VERSION}},
        \"component\": {
            \"id\": \"${PARAM_CONTEXT_ID}\",
            \"parameters\": [
                {\"parameter\": {
                    \"name\": \"snowflake.jdbc.driver\",
                    \"sensitive\": false,
                    \"description\": \"Snowflake JDBC Driver JAR file\",
                    \"value\": null,
                    \"referencedAssets\": [{
                        \"id\": \"${ASSET_ID}\",
                        \"name\": \"snowflake-jdbc-3.19.1.jar\"
                    }]
                }}
            ]
        }
    }" > /dev/null

echo "✓ JDBC driver parameter added"

echo ""
echo "Step 2: Configure DBCPConnectionPool with Snowflake JDBC driver..."
DBCP_VERSION=$(curl -s -H "Authorization: Bearer $PAT" \
    "${API_BASE}/controller-services/${DBCP_SERVICE_ID}" | \
    python3 -c "import sys,json; print(json.load(sys.stdin)['revision']['version'])")

curl -s -X PUT -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/controller-services/${DBCP_SERVICE_ID}" \
    -d "{
        \"revision\": {\"version\": ${DBCP_VERSION}},
        \"component\": {
            \"id\": \"${DBCP_SERVICE_ID}\",
            \"config\": {
                \"properties\": {
                    \"database-driver-class-name\": \"net.snowflake.client.jdbc.SnowflakeDriver\",
                    \"database-connection-url\": \"jdbc:snowflake://#{snowflake.account}.snowflakecomputing.com/\",
                    \"database-driver-locations\": \"#{snowflake.jdbc.driver}\",
                    \"Database User\": \"#{snowflake.username}\",
                    \"Password\": null,
                    \"kerberos-credentials-service\": null,
                    \"kerberos-principal\": null,
                    \"kerberos-password\": null,
                    \"Max Wait Time\": \"500 millis\",
                    \"Max Total Connections\": \"8\",
                    \"Validation-query\": \"SELECT 1\"
                }
            }
        }
    }" > /dev/null

echo "✓ DBCPConnectionPool configured"

echo ""
echo "Step 3: Checking validation status..."
sleep 2

curl -s -H "Authorization: Bearer $PAT" \
    "${API_BASE}/controller-services/${DBCP_SERVICE_ID}" | \
    python3 -c "
import sys, json
data = json.load(sys.stdin)
status = data['component'].get('validationStatus', 'UNKNOWN')
print(f'Validation: {status}')
errors = data['component'].get('validationErrors', [])
if errors:
    print('Errors:')
    for err in errors:
        print(f'  - {err}')
else:
    print('✓ No validation errors')
"

echo ""
echo "DBCPConnectionPool configured with Snowflake JDBC driver"
