#!/usr/bin/env python3
"""
Openflow Data Generator Setup via REST API
Creates NiFi flow for generating orders and order_items data
"""

import json
import os
import requests
import time
import uuid
from typing import Dict, Any, Optional

# Configuration
RUNTIME_URL = "https://of--sfsenorthamerica-gen-ai-hol.snowflakecomputing.app/dashing"
API_BASE = f"{RUNTIME_URL}/nifi-api"
PAT_TOKEN = os.getenv("PAT")

if not PAT_TOKEN:
    raise ValueError("PAT environment variable not set")

HEADERS = {
    "Authorization": f"Bearer {PAT_TOKEN}",
    "Content-Type": "application/json"
}

# Snowflake Configuration
SNOWFLAKE_CONFIG = {
    "account": "sfsenorthamerica-gen_ai_hol",
    "username": "dash",
    "role": "snowflake_intelligence_admin",
    "warehouse": "automated_intelligence_wh",
    "database": "AUTOMATED_INTELLIGENCE",
    "schema": "STAGING",
    "rsa_key_path": "/Users/ddesai/Apps/Snova/automated-intelligence/snowpipe-streaming-java/rsa_key.p8"
}


class OpenflowClient:
    """Client for Openflow/NiFi REST API"""
    
    def __init__(self, base_url: str, headers: Dict[str, str]):
        self.base_url = base_url
        self.headers = headers
        self.root_pg_id = None
        
    def get_root_process_group(self) -> Dict[str, Any]:
        """Get root process group ID"""
        resp = requests.get(f"{self.base_url}/flow/process-groups/root", headers=self.headers)
        resp.raise_for_status()
        data = resp.json()
        self.root_pg_id = data["processGroupFlow"]["id"]
        return data
    
    def create_process_group(self, name: str, x: int, y: int) -> Dict[str, Any]:
        """Create a process group"""
        payload = {
            "revision": {"version": 0},
            "component": {
                "name": name,
                "position": {"x": x, "y": y}
            }
        }
        resp = requests.post(
            f"{self.base_url}/process-groups/{self.root_pg_id}/process-groups",
            headers=self.headers,
            json=payload
        )
        resp.raise_for_status()
        return resp.json()
    
    def create_processor(self, pg_id: str, proc_type: str, name: str, x: int, y: int, 
                        config: Optional[Dict] = None) -> Dict[str, Any]:
        """Create a processor"""
        payload = {
            "revision": {"version": 0},
            "component": {
                "type": proc_type,
                "name": name,
                "position": {"x": x, "y": y},
                "config": config or {}
            }
        }
        resp = requests.post(
            f"{self.base_url}/process-groups/{pg_id}/processors",
            headers=self.headers,
            json=payload
        )
        resp.raise_for_status()
        return resp.json()
    
    def create_parameter_context(self, name: str, description: str, 
                                 parameters: Dict[str, Dict]) -> Dict[str, Any]:
        """Create a parameter context with parameters"""
        payload = {
            "revision": {"version": 0},
            "component": {
                "name": name,
                "description": description,
                "parameters": [
                    {
                        "parameter": {
                            "name": param_name,
                            "description": param_data.get("description", ""),
                            "sensitive": param_data.get("sensitive", False),
                            "value": param_data.get("value", "")
                        }
                    }
                    for param_name, param_data in parameters.items()
                ]
            }
        }
        resp = requests.post(
            f"{self.base_url}/parameter-contexts",
            headers=self.headers,
            json=payload
        )
        resp.raise_for_status()
        return resp.json()
    
    def upload_asset(self, context_id: str, file_path: str) -> Dict[str, Any]:
        """Upload a file as an asset to a parameter context"""
        filename = os.path.basename(file_path)
        
        with open(file_path, 'rb') as f:
            file_content = f.read()
        
        headers = {
            "Authorization": self.headers["Authorization"],
            "Content-Type": "application/octet-stream",
            "filename": filename
        }
        
        resp = requests.post(
            f"{self.base_url}/parameter-contexts/{context_id}/assets",
            headers=headers,
            data=file_content
        )
        resp.raise_for_status()
        return resp.json()
    
    def update_parameter_context(self, context_id: str, version: int, 
                                 parameters: Dict[str, Any]) -> Dict[str, Any]:
        """Update parameter context with new parameters"""
        payload = {
            "revision": {"version": version},
            "component": {
                "id": context_id,
                "parameters": [
                    {
                        "parameter": {
                            "name": param_name,
                            "description": param_data.get("description", ""),
                            "sensitive": param_data.get("sensitive", False),
                            "value": param_data.get("value"),
                            "referencedAssets": param_data.get("referencedAssets")
                        }
                    }
                    for param_name, param_data in parameters.items()
                ]
            }
        }
        
        resp = requests.put(
            f"{self.base_url}/parameter-contexts/{context_id}",
            headers=self.headers,
            json=payload
        )
        resp.raise_for_status()
        return resp.json()
    
    def bind_parameter_context(self, pg_id: str, pg_version: int, context_id: str):
        """Bind a parameter context to a process group"""
        payload = {
            "revision": {"version": pg_version},
            "component": {
                "id": pg_id,
                "parameterContext": {"id": context_id}
            }
        }
        resp = requests.put(
            f"{self.base_url}/process-groups/{pg_id}",
            headers=self.headers,
            json=payload
        )
        resp.raise_for_status()
        return resp.json()
    
    def create_connection(self, source_id: str, source_type: str, dest_id: str, 
                         dest_type: str, relationships: list) -> Dict[str, Any]:
        """Create a connection between two components"""
        payload = {
            "revision": {"version": 0},
            "component": {
                "source": {"id": source_id, "type": source_type},
                "destination": {"id": dest_id, "type": dest_type},
                "selectedRelationships": relationships
            }
        }
        resp = requests.post(
            f"{self.base_url}/process-groups/{self.root_pg_id}/connections",
            headers=self.headers,
            json=payload
        )
        resp.raise_for_status()
        return resp.json()
    
    def start_processor(self, processor_id: str, version: int):
        """Start a processor"""
        payload = {
            "revision": {"version": version},
            "component": {"id": processor_id, "state": "RUNNING"}
        }
        resp = requests.put(
            f"{self.base_url}/processors/{processor_id}",
            headers=self.headers,
            json=payload
        )
        resp.raise_for_status()
        return resp.json()


def create_orders_generator_flow(client: OpenflowClient):
    """Create the orders data generator flow"""
    
    print("Creating orders data generator flow...")
    
    # 1. Create parameter context for Snowflake connection
    print("Creating parameter context...")
    param_context = client.create_parameter_context(
        name="Snowflake Connection - Orders",
        description="Snowflake connection parameters for orders data generator",
        parameters={
            "snowflake.account": {
                "value": SNOWFLAKE_CONFIG["account"],
                "description": "Snowflake account identifier"
            },
            "snowflake.username": {
                "value": SNOWFLAKE_CONFIG["username"],
                "description": "Snowflake username"
            },
            "snowflake.role": {
                "value": SNOWFLAKE_CONFIG["role"],
                "description": "Snowflake role"
            },
            "snowflake.warehouse": {
                "value": SNOWFLAKE_CONFIG["warehouse"],
                "description": "Snowflake warehouse"
            },
            "snowflake.database": {
                "value": SNOWFLAKE_CONFIG["database"],
                "description": "Snowflake database"
            },
            "snowflake.schema": {
                "value": SNOWFLAKE_CONFIG["schema"],
                "description": "Snowflake schema"
            },
            "snowflake.table": {
                "value": "orders_staging",
                "description": "Target table name"
            }
        }
    )
    context_id = param_context["id"]
    context_version = param_context["revision"]["version"]
    
    print(f"Parameter context created: {context_id}")
    
    # 2. Upload RSA private key as asset
    print("Uploading RSA private key...")
    asset = client.upload_asset(context_id, SNOWFLAKE_CONFIG["rsa_key_path"])
    asset_id = asset["asset"]["id"]
    asset_name = asset["asset"]["name"]
    
    print(f"RSA key uploaded as asset: {asset_id}")
    
    # 3. Update parameter context with RSA key reference
    print("Updating parameter context with RSA key reference...")
    updated_context = client.update_parameter_context(
        context_id,
        context_version,
        {
            "snowflake.account": {
                "value": SNOWFLAKE_CONFIG["account"],
                "description": "Snowflake account identifier"
            },
            "snowflake.username": {
                "value": SNOWFLAKE_CONFIG["username"],
                "description": "Snowflake username"
            },
            "snowflake.role": {
                "value": SNOWFLAKE_CONFIG["role"],
                "description": "Snowflake role"
            },
            "snowflake.warehouse": {
                "value": SNOWFLAKE_CONFIG["warehouse"],
                "description": "Snowflake warehouse"
            },
            "snowflake.database": {
                "value": SNOWFLAKE_CONFIG["database"],
                "description": "Snowflake database"
            },
            "snowflake.schema": {
                "value": SNOWFLAKE_CONFIG["schema"],
                "description": "Snowflake schema"
            },
            "snowflake.table": {
                "value": "orders_staging",
                "description": "Target table name"
            },
            "snowflake.private.key": {
                "description": "RSA private key for authentication",
                "sensitive": True,
                "referencedAssets": [{"id": asset_id, "name": asset_name}]
            }
        }
    )
    
    print("Parameter context updated with RSA key")
    
    # 4. Create process group for orders
    print("Creating process group...")
    pg = client.create_process_group("Orders Data Generator", 100, 100)
    pg_id = pg["id"]
    
    print(f"Process group created: {pg_id}")
    
    # 5. Bind parameter context to process group
    print("Binding parameter context to process group...")
    client.bind_parameter_context(pg_id, pg["revision"]["version"], context_id)
    
    print("\n✅ Orders data generator flow created successfully!")
    print(f"\nNext steps:")
    print(f"1. Add processors to process group: {pg_id}")
    print(f"2. Configure processor properties to reference parameters")
    print(f"3. Create connections between processors")
    print(f"4. Start the flow")
    
    return {
        "process_group_id": pg_id,
        "parameter_context_id": context_id
    }


def main():
    """Main execution"""
    print("=" * 80)
    print("Openflow Data Generator Setup")
    print("=" * 80)
    print()
    
    # Initialize client
    client = OpenflowClient(API_BASE, HEADERS)
    
    # Get root process group
    print("Connecting to Openflow runtime...")
    root = client.get_root_process_group()
    print(f"✅ Connected to runtime: {client.root_pg_id}")
    print()
    
    # Create orders generator flow
    result = create_orders_generator_flow(client)
    
    print()
    print("=" * 80)
    print("Setup Complete!")
    print("=" * 80)
    print(f"\n📊 Process Group ID: {result['process_group_id']}")
    print(f"🔑 Parameter Context ID: {result['parameter_context_id']}")
    print(f"\n🌐 NiFi UI: {RUNTIME_URL}/nifi")


if __name__ == "__main__":
    main()
