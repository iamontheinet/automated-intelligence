#!/usr/bin/env python3
"""
Fix missing parameters in Openflow parameter context
"""

import subprocess
import json
import sys

# Get Snowflake connection details
result = subprocess.run(
    ['snow', 'connection', 'list', '--format', 'json'],
    capture_output=True,
    text=True
)

connections = json.loads(result.stdout)
dash_conn = next(c for c in connections if c['connection_name'] == 'dash-builder-si')

print("Connection details:")
print(f"  User: {dash_conn['parameters']['user']}")
print(f"  Account: {dash_conn['parameters']['account']}")
print(f"  Host: {dash_conn['parameters']['host']}")
print(f"  Database: {dash_conn['parameters']['database']}")
print(f"  Schema: {dash_conn['parameters']['schema']}")
print(f"  Warehouse: {dash_conn['parameters']['warehouse']}")
print(f"  Role: {dash_conn['parameters']['role']}")

print("\n" + "="*60)
print("REQUIRED MANUAL STEPS:")
print("="*60)

print("\n1. Go to Openflow UI → Right-click 'Orders Data Generator' → Parameters")
print("\n2. Add/Update these parameters:")
print(f"   - snowflake.user = {dash_conn['parameters']['user']}")
print(f"   - snowflake.account = {dash_conn['parameters']['account']}")
print(f"   - snowflake.database = AUTOMATED_INTELLIGENCE")
print(f"   - snowflake.schema = STAGING (or analytics_iceberg if inserting directly)")
print(f"   - snowflake.warehouse = {dash_conn['parameters']['warehouse']}")
print(f"   - snowflake.role = {dash_conn['parameters']['role']}")
print(f"   - snowflake.password = [YOUR PASSWORD] (sensitive)")

print("\n3. Fix DBCPConnectionPool:")
print("   - Database Connection URL: jdbc:snowflake://sfsenorthamerica-gen_ai_hol.snowflakecomputing.com/?db=#{snowflake.database}&schema=#{snowflake.schema}&warehouse=#{snowflake.warehouse}&role=#{snowflake.role}")
print("   - Database User: #{snowflake.user}")
print("   - Password: #{snowflake.password}")

print("\n4. Delete or disable 'SnowflakeConnectionService_Native' (not needed for JDBC approach)")

print("\n5. Fix JsonRecordSetWriter:")
print("   - Schema Access Strategy: Change to 'Infer Schema' or 'Use String Fields'")
