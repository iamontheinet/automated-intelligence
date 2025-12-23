#!/usr/bin/env python3
"""
Fix the JDBC connection URL hostname to include underscore.
The error shows: sfsenorthamerica-gen-ai-hol (hyphen) 
Should be: sfsenorthamerica-gen_ai_hol (underscore)
"""

import snowflake.connector
import requests
import json
import sys

# Snowflake connection
conn = snowflake.connector.connect(
    connection_name='dash-builder-si'
)

try:
    # Get JWT token for Openflow API
    cursor = conn.cursor()
    cursor.execute("""
        SELECT SYSTEM$GENERATE_OPENFLOW_JWT(
            'https://of--sfsenorthamerica-gen-ai-hol.snowflakecomputing.app/dashing'
        )
    """)
    pat = cursor.fetchone()[0]
    print("✓ Generated Openflow JWT token")
    
    API_BASE = "https://of--sfsenorthamerica-gen-ai-hol.snowflakecomputing.app/dashing/nifi-api"
    DBCP_SERVICE_ID = "13b18417-019b-1000-ffff-ffffed76158c"
    
    headers = {
        "Authorization": f"Bearer {pat}",
        "Content-Type": "application/json"
    }
    
    # Step 1: Get current config
    print("\nStep 1: Getting current configuration...")
    resp = requests.get(f"{API_BASE}/controller-services/{DBCP_SERVICE_ID}", headers=headers)
    resp.raise_for_status()
    dbcp = resp.json()
    
    current_url = dbcp['component']['properties']['database-connection-url']
    current_state = dbcp['component']['state']
    
    print(f"Current URL: {current_url}")
    print(f"Current State: {current_state}")
    
    # Check if fix is needed
    if 'gen_ai_hol' in current_url:
        print("\n✓ URL already has correct hostname with underscore!")
        sys.exit(0)
    
    # Step 2: Disable service if enabled
    if current_state == 'ENABLED':
        print("\nStep 2: Disabling service...")
        disable_payload = {
            "revision": dbcp['revision'],
            "state": "DISABLED"
        }
        resp = requests.put(
            f"{API_BASE}/controller-services/{DBCP_SERVICE_ID}/run-status",
            headers=headers,
            json=disable_payload
        )
        resp.raise_for_status()
        print("✓ Service disabled")
        
        # Refresh revision
        resp = requests.get(f"{API_BASE}/controller-services/{DBCP_SERVICE_ID}", headers=headers)
        dbcp = resp.json()
    
    # Step 3: Update URL
    print("\nStep 3: Updating JDBC connection URL...")
    
    # Correct URL with underscore in hostname
    new_url = "jdbc:snowflake://sfsenorthamerica-gen_ai_hol.snowflakecomputing.com/?db=#{snowflake.database}&schema=#{snowflake.schema}&warehouse=#{snowflake.warehouse}&role=#{snowflake.role}"
    
    properties = dbcp['component']['properties'].copy()
    properties['database-connection-url'] = new_url
    
    update_payload = {
        "revision": dbcp['revision'],
        "component": {
            "id": DBCP_SERVICE_ID,
            "properties": properties
        }
    }
    
    resp = requests.put(
        f"{API_BASE}/controller-services/{DBCP_SERVICE_ID}",
        headers=headers,
        json=update_payload
    )
    resp.raise_for_status()
    result = resp.json()
    
    print(f"✓ URL updated to: {result['component']['properties']['database-connection-url']}")
    
    # Step 4: Re-enable service
    print("\nStep 4: Re-enabling service...")
    
    # Refresh revision
    resp = requests.get(f"{API_BASE}/controller-services/{DBCP_SERVICE_ID}", headers=headers)
    dbcp = resp.json()
    
    enable_payload = {
        "revision": dbcp['revision'],
        "state": "ENABLED"
    }
    
    resp = requests.put(
        f"{API_BASE}/controller-services/{DBCP_SERVICE_ID}/run-status",
        headers=headers,
        json=enable_payload
    )
    resp.raise_for_status()
    result = resp.json()
    
    state = result['component']['state']
    validation = result['component'].get('validationStatus', 'UNKNOWN')
    
    print(f"✓ Service state: {state}")
    print(f"✓ Validation status: {validation}")
    
    if validation == 'VALID':
        print("\n✅ JDBC URL successfully fixed and validated!")
        print("   The hostname now correctly uses underscore: gen_ai_hol")
    else:
        print(f"\n⚠️  Service enabled but validation status is: {validation}")
        print("   Check the Openflow UI for any validation errors")
    
finally:
    conn.close()
