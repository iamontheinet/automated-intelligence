#!/bin/bash
#
# Openflow Data Generator Setup via REST API
# Creates NiFi flow for generating orders and order_items data
#

set -e

# Configuration
RUNTIME_URL="https://of--sfsenorthamerica-gen-ai-hol.snowflakecomputing.app/dashing"
API_BASE="${RUNTIME_URL}/nifi-api"

# Snowflake Configuration
SF_ACCOUNT="sfsenorthamerica-gen_ai_hol"
SF_USERNAME="dash"
SF_ROLE="snowflake_intelligence_admin"
SF_WAREHOUSE="automated_intelligence_wh"
SF_DATABASE="AUTOMATED_INTELLIGENCE"
SF_SCHEMA="STAGING"
RSA_KEY_PATH="/Users/ddesai/Apps/Snova/automated-intelligence/snowpipe-streaming-java/rsa_key.p8"

# Check PAT token
if [ -z "$PAT" ]; then
    echo "Error: PAT environment variable not set"
    exit 1
fi

echo "================================================================================"
echo "Openflow Data Generator Setup"
echo "================================================================================"
echo ""

# Step 1: Get root process group
echo "Step 1: Connecting to Openflow runtime..."
ROOT_PG=$(curl -s -H "Authorization: Bearer $PAT" \
    "${API_BASE}/flow/process-groups/root")
ROOT_PG_ID=$(echo "$ROOT_PG" | python3 -c "import sys, json; print(json.load(sys.stdin)['processGroupFlow']['id'])")
echo "✅ Connected to runtime: $ROOT_PG_ID"
echo ""

# Step 2: Create parameter context
echo "Step 2: Creating parameter context..."
PARAM_CONTEXT=$(curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/parameter-contexts" \
    -d "{
        \"revision\": {\"version\": 0},
        \"component\": {
            \"name\": \"Snowflake Connection - Orders Generator\",
            \"description\": \"Snowflake connection parameters for orders data generator\",
            \"parameters\": [
                {
                    \"parameter\": {
                        \"name\": \"snowflake.account\",
                        \"description\": \"Snowflake account identifier\",
                        \"sensitive\": false,
                        \"value\": \"$SF_ACCOUNT\"
                    }
                },
                {
                    \"parameter\": {
                        \"name\": \"snowflake.username\",
                        \"description\": \"Snowflake username\",
                        \"sensitive\": false,
                        \"value\": \"$SF_USERNAME\"
                    }
                },
                {
                    \"parameter\": {
                        \"name\": \"snowflake.role\",
                        \"description\": \"Snowflake role\",
                        \"sensitive\": false,
                        \"value\": \"$SF_ROLE\"
                    }
                },
                {
                    \"parameter\": {
                        \"name\": \"snowflake.warehouse\",
                        \"description\": \"Snowflake warehouse\",
                        \"sensitive\": false,
                        \"value\": \"$SF_WAREHOUSE\"
                    }
                },
                {
                    \"parameter\": {
                        \"name\": \"snowflake.database\",
                        \"description\": \"Snowflake database\",
                        \"sensitive\": false,
                        \"value\": \"$SF_DATABASE\"
                    }
                },
                {
                    \"parameter\": {
                        \"name\": \"snowflake.schema\",
                        \"description\": \"Snowflake schema\",
                        \"sensitive\": false,
                        \"value\": \"$SF_SCHEMA\"
                    }
                },
                {
                    \"parameter\": {
                        \"name\": \"snowflake.table.orders\",
                        \"description\": \"Orders table name\",
                        \"sensitive\": false,
                        \"value\": \"orders_staging\"
                    }
                },
                {
                    \"parameter\": {
                        \"name\": \"snowflake.table.order_items\",
                        \"description\": \"Order items table name\",
                        \"sensitive\": false,
                        \"value\": \"order_items_staging\"
                    }
                }
            ]
        }
    }")

PARAM_CONTEXT_ID=$(echo "$PARAM_CONTEXT" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
PARAM_CONTEXT_VERSION=$(echo "$PARAM_CONTEXT" | python3 -c "import sys, json; print(json.load(sys.stdin)['revision']['version'])")
echo "✅ Parameter context created: $PARAM_CONTEXT_ID"
echo ""

# Step 3: Upload RSA private key as asset
echo "Step 3: Uploading RSA private key..."
ASSET=$(curl -s -X POST \
    -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/octet-stream" \
    -H "filename: rsa_key.p8" \
    "${API_BASE}/parameter-contexts/${PARAM_CONTEXT_ID}/assets" \
    --data-binary "@${RSA_KEY_PATH}")

ASSET_ID=$(echo "$ASSET" | python3 -c "import sys, json; print(json.load(sys.stdin)['asset']['id'])")
ASSET_NAME=$(echo "$ASSET" | python3 -c "import sys, json; print(json.load(sys.stdin)['asset']['name'])")
echo "✅ RSA key uploaded as asset: $ASSET_ID"
echo ""

# Step 4: Update parameter context with RSA key reference
echo "Step 4: Updating parameter context with RSA key reference..."
UPDATED_CONTEXT=$(curl -s -X PUT -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/parameter-contexts/${PARAM_CONTEXT_ID}" \
    -d "{
        \"revision\": {\"version\": $PARAM_CONTEXT_VERSION},
        \"component\": {
            \"id\": \"$PARAM_CONTEXT_ID\",
            \"parameters\": [
                {
                    \"parameter\": {
                        \"name\": \"snowflake.account\",
                        \"description\": \"Snowflake account identifier\",
                        \"sensitive\": false,
                        \"value\": \"$SF_ACCOUNT\"
                    }
                },
                {
                    \"parameter\": {
                        \"name\": \"snowflake.username\",
                        \"description\": \"Snowflake username\",
                        \"sensitive\": false,
                        \"value\": \"$SF_USERNAME\"
                    }
                },
                {
                    \"parameter\": {
                        \"name\": \"snowflake.role\",
                        \"description\": \"Snowflake role\",
                        \"sensitive\": false,
                        \"value\": \"$SF_ROLE\"
                    }
                },
                {
                    \"parameter\": {
                        \"name\": \"snowflake.warehouse\",
                        \"description\": \"Snowflake warehouse\",
                        \"sensitive\": false,
                        \"value\": \"$SF_WAREHOUSE\"
                    }
                },
                {
                    \"parameter\": {
                        \"name\": \"snowflake.database\",
                        \"description\": \"Snowflake database\",
                        \"sensitive\": false,
                        \"value\": \"$SF_DATABASE\"
                    }
                },
                {
                    \"parameter\": {
                        \"name\": \"snowflake.schema\",
                        \"description\": \"Snowflake schema\",
                        \"sensitive\": false,
                        \"value\": \"$SF_SCHEMA\"
                    }
                },
                {
                    \"parameter\": {
                        \"name\": \"snowflake.table.orders\",
                        \"description\": \"Orders table name\",
                        \"sensitive\": false,
                        \"value\": \"orders_staging\"
                    }
                },
                {
                    \"parameter\": {
                        \"name\": \"snowflake.table.order_items\",
                        \"description\": \"Order items table name\",
                        \"sensitive\": false,
                        \"value\": \"order_items_staging\"
                    }
                },
                {
                    \"parameter\": {
                        \"name\": \"snowflake.private.key\",
                        \"description\": \"RSA private key for authentication\",
                        \"sensitive\": true,
                        \"value\": null,
                        \"referencedAssets\": [
                            {\"id\": \"$ASSET_ID\", \"name\": \"$ASSET_NAME\"}
                        ]
                    }
                }
            ]
        }
    }")
echo "✅ Parameter context updated with RSA key"
echo ""

# Step 5: Create process group
echo "Step 5: Creating process group..."
PROCESS_GROUP=$(curl -s -X POST -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${ROOT_PG_ID}/process-groups" \
    -d "{
        \"revision\": {\"version\": 0},
        \"component\": {
            \"name\": \"Orders Data Generator\",
            \"position\": {\"x\": 100.0, \"y\": 100.0}
        }
    }")

PG_ID=$(echo "$PROCESS_GROUP" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
PG_VERSION=$(echo "$PROCESS_GROUP" | python3 -c "import sys, json; print(json.load(sys.stdin)['revision']['version'])")
echo "✅ Process group created: $PG_ID"
echo ""

# Step 6: Bind parameter context to process group
echo "Step 6: Binding parameter context to process group..."
BOUND_PG=$(curl -s -X PUT -H "Authorization: Bearer $PAT" \
    -H "Content-Type: application/json" \
    "${API_BASE}/process-groups/${PG_ID}" \
    -d "{
        \"revision\": {\"version\": $PG_VERSION},
        \"component\": {
            \"id\": \"$PG_ID\",
            \"parameterContext\": {\"id\": \"$PARAM_CONTEXT_ID\"}
        }
    }")
echo "✅ Parameter context bound to process group"
echo ""

echo "================================================================================"
echo "Setup Complete!"
echo "================================================================================"
echo ""
echo "📊 Process Group ID: $PG_ID"
echo "🔑 Parameter Context ID: $PARAM_CONTEXT_ID"
echo "🔐 RSA Key Asset ID: $ASSET_ID"
echo ""
echo "🌐 NiFi UI: ${RUNTIME_URL}/nifi"
echo ""
echo "Next steps:"
echo "  1. Process group created with Snowflake connection parameters configured"
echo "  2. RSA private key uploaded and referenced in parameter context"
echo "  3. Ready to add processors (GenerateFlowFile, UpdateAttribute, etc.)"
echo ""
