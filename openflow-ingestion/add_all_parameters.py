#!/usr/bin/env python3
"""
Add all required Snowflake connection parameters to Openflow parameter context.
"""

import subprocess
import json
import sys

print("="*70)
print("PARAMETERS TO ADD MANUALLY IN OPENFLOW UI")
print("="*70)
print("\n1. Navigate to: https://of--sfsenorthamerica-gen-ai-hol.snowflakecomputing.app/dashing/")
print("2. Right-click 'Orders Data Generator' process group → Select 'Parameters'")
print("3. Add the following parameters (click + button for each):\n")

# Required parameters
params = [
    ("snowflake.user", "dash", False, "Snowflake username"),
    ("snowflake.password", "[YOUR_PASSWORD]", True, "Snowflake password"),
    ("snowflake.account", "sfsenorthamerica-gen_ai_hol", False, "Snowflake account identifier"),
    ("snowflake.database", "AUTOMATED_INTELLIGENCE", False, "Target database"),
    ("snowflake.schema", "analytics_iceberg", False, "Target schema"),
    ("snowflake.warehouse", "automated_intelligence_wh", False, "Compute warehouse"),
    ("snowflake.role", "snowflake_intelligence_admin", False, "Snowflake role"),
]

print("PARAMETERS TO ADD:")
print("-" * 70)
for name, value, sensitive, desc in params:
    sens_flag = "[SENSITIVE]" if sensitive else ""
    print(f"\n  Name: {name} {sens_flag}")
    print(f"  Value: {value}")
    print(f"  Description: {desc}")
    print(f"  Sensitive: {'Yes' if sensitive else 'No'}")

print("\n" + "="*70)
print("NOTE: The 'snowflake.jdbc.driver' parameter should already exist")
print("      (it references the uploaded JAR file asset)")
print("="*70)

print("\n\nAFTER ADDING ALL PARAMETERS:")
print("1. Click 'Apply' to save")
print("2. Go back to Controller Services")
print("3. Disable DBCPConnectionPool")
print("4. Edit and set 'database-driver-locations' to: #{snowflake.jdbc.driver}")
print("5. Enable DBCPConnectionPool")
print("6. All validation errors should be resolved ✓")
