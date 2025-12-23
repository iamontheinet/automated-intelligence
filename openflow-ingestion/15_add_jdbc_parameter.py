import json
import subprocess
import sys

API_BASE = "https://of--sfsenorthamerica-gen-ai-hol.snowflakecomputing.app/dashing/nifi-api"
PARAM_CONTEXT_ID = "0a9f168b-019b-1000-0000-00002778ece2"
ASSET_ID = "4d3bee4d-08f9-303a-85cc-bc1eee47f13f"

# Get current context
result = subprocess.run(
    f'curl -s -H "Authorization: Bearer $PAT" "{API_BASE}/parameter-contexts/{PARAM_CONTEXT_ID}"',
    shell=True, capture_output=True, text=True
)
context = json.loads(result.stdout)

# Build parameters list
params = []
for p in context['component']['parameters']:
    params.append(p)

# Add JDBC driver
params.append({
    "parameter": {
        "name": "snowflake.jdbc.driver",
        "sensitive": False,
        "description": "Snowflake JDBC Driver JAR file",
        "value": None,
        "referencedAssets": [{
            "id": ASSET_ID,
            "name": "snowflake-jdbc-3.19.1.jar"
        }]
    }
})

# Update context
payload = {
    "revision": {"version": context['revision']['version']},
    "component": {
        "id": PARAM_CONTEXT_ID,
        "parameters": params
    }
}

result = subprocess.run(
    f'curl -s -X PUT -H "Authorization: Bearer $PAT" -H "Content-Type: application/json" '
    f'"{API_BASE}/parameter-contexts/{PARAM_CONTEXT_ID}" -d \'{json.dumps(payload)}\'',
    shell=True, capture_output=True, text=True
)

response = json.loads(result.stdout)
print(f"✓ Parameter added (version: {response['revision']['version']})")
