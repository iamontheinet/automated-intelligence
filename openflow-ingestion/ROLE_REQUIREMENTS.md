# Role Requirements for Openflow Setup

## Summary

This document clarifies which Snowflake roles are required for each step of the Openflow setup.

**RECOMMENDED:** Use `snowflake_intelligence_admin` role for the entire setup if available. This role has all necessary privileges including:
- CREATE USER
- CREATE ROLE  
- CREATE DATABASE
- CREATE INTEGRATION
- MANAGE GRANTS

Only fall back to ACCOUNTADMIN if `snowflake_intelligence_admin` fails on any step.

## Role Requirements by Step

### Using snowflake_intelligence_admin (Recommended)

### Using snowflake_intelligence_admin (Recommended)

**All steps can use this single role:**

```sql
USE ROLE snowflake_intelligence_admin;

-- Step 1: Create service user
CREATE USER IF NOT EXISTS openflow_kafka_user TYPE = SERVICE;

-- Step 2: Create role
CREATE ROLE IF NOT EXISTS openflow_kafka_role;

-- Step 3: Grant privileges
GRANT USAGE ON DATABASE automated_intelligence TO ROLE openflow_kafka_role;
GRANT USAGE ON SCHEMA automated_intelligence.raw TO ROLE openflow_kafka_role;
GRANT CREATE TABLE ON SCHEMA automated_intelligence.raw TO ROLE openflow_kafka_role;
GRANT USAGE ON WAREHOUSE automated_intelligence_wh TO ROLE openflow_kafka_role;

-- Step 4: Assign role to user
GRANT ROLE openflow_kafka_role TO USER openflow_kafka_user;
ALTER USER openflow_kafka_user SET DEFAULT_ROLE = openflow_kafka_role;

-- Step 5: Create network rule and integration
CREATE OR REPLACE NETWORK RULE kafka_brokers_network_rule ...;
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION kafka_external_access_integration ...;
GRANT USAGE ON INTEGRATION kafka_external_access_integration TO ROLE openflow_kafka_role;

-- Step 6: Create monitoring views
CREATE OR REPLACE VIEW automated_intelligence.raw.openflow_ingestion_status AS ...;
```

**Why this works:** 
- `snowflake_intelligence_admin` has CREATE USER, CREATE ROLE, CREATE DATABASE, and **CREATE INTEGRATION** privileges
- This is the recommended approach for automated_intelligence project

---

### Alternative: Using Multiple Roles

If `snowflake_intelligence_admin` is not available:

### Step 1: Create Service User
**Required Role:** `SECURITYADMIN` or `USERADMIN`

```sql
USE ROLE SECURITYADMIN;  -- or USERADMIN

CREATE USER IF NOT EXISTS openflow_kafka_user
  TYPE = SERVICE
  COMMENT = 'Service user for Openflow Kafka connector';
```

**Why:** Creating users requires SECURITYADMIN or USERADMIN privileges.

---

### Step 2: Create Role
**Required Role:** `SECURITYADMIN` or higher

```sql
USE ROLE SECURITYADMIN;

CREATE ROLE IF NOT EXISTS openflow_kafka_role
  COMMENT = 'Role for Openflow Kafka ingestion';
```

**Why:** Creating roles requires SECURITYADMIN or ACCOUNTADMIN privileges.

---

### Step 3: Grant Database/Schema/Warehouse Privileges
**Required Role:** Role with **GRANT** privilege on those objects

```sql
USE ROLE SECURITYADMIN;  -- or role with MANAGE GRANTS privilege

GRANT USAGE ON DATABASE automated_intelligence TO ROLE openflow_kafka_role;
GRANT USAGE ON SCHEMA automated_intelligence.raw TO ROLE openflow_kafka_role;
GRANT CREATE TABLE ON SCHEMA automated_intelligence.raw TO ROLE openflow_kafka_role;
GRANT USAGE ON WAREHOUSE automated_intelligence_wh TO ROLE openflow_kafka_role;
```

**Options:**
1. **SECURITYADMIN** - Has MANAGE GRANTS privilege
2. **Role with OWNERSHIP** on the objects
3. **Custom role** with explicit GRANT privilege

**Why:** You need the ability to grant privileges on objects you don't own.

---

### Step 4: Assign Role to User
**Required Role:** `SECURITYADMIN` or higher

```sql
USE ROLE SECURITYADMIN;

GRANT ROLE openflow_kafka_role TO USER openflow_kafka_user;
ALTER USER openflow_kafka_user SET DEFAULT_ROLE = openflow_kafka_role;
```

**Why:** Granting roles to users requires SECURITYADMIN or ACCOUNTADMIN.

---

### Step 5: Network Rules and External Access Integration
**Required Role:** `ACCOUNTADMIN` ⚠️

```sql
USE ROLE ACCOUNTADMIN;

-- Create network rule
CREATE OR REPLACE NETWORK RULE kafka_brokers_network_rule
  TYPE = HOST_PORT
  MODE = EGRESS
  VALUE_LIST = ('kafka-broker-1.example.com:9092');

-- Create external access integration
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION kafka_external_access_integration
  ALLOWED_NETWORK_RULES = (kafka_brokers_network_rule)
  ENABLED = TRUE;

-- Grant integration to role
GRANT USAGE ON INTEGRATION kafka_external_access_integration TO ROLE openflow_kafka_role;
```

**Why:** 
- **Network Rules** can be created by ACCOUNTADMIN or custom role with `CREATE NETWORK RULE` privilege
- **External Access Integrations** **REQUIRE ACCOUNTADMIN** (cannot be delegated)
- **Granting integration usage** requires ACCOUNTADMIN or the integration owner

**This is the ONLY step that strictly requires ACCOUNTADMIN.**

---

### Step 6: Create Monitoring Views
**Required Role:** Role with `CREATE VIEW` privilege on the schema

```sql
-- Option 1: Custom role with appropriate privileges
USE ROLE your_custom_role;

-- Option 2: SYSADMIN (has CREATE VIEW by default on schemas it owns)
USE ROLE SYSADMIN;

-- Option 3: ACCOUNTADMIN (can do anything)
USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE VIEW automated_intelligence.raw.openflow_ingestion_status AS
SELECT ...;

GRANT SELECT ON VIEW openflow_ingestion_status TO ROLE openflow_kafka_role;
```

**Why:** Creating views requires CREATE VIEW privilege on the schema. Granting access requires appropriate grant privileges.

---

## Recommended Role Strategy

### Option A: Minimal Privilege Approach (Recommended)

Run the script in sections with different roles:

```sql
-- Part 1: User and role creation
USE ROLE SECURITYADMIN;
-- Run Steps 1-4

-- Part 2: Database/Schema/Warehouse grants
USE ROLE SECURITYADMIN;  -- or your custom role with MANAGE GRANTS
-- Run Step 3

-- Part 3: Network and integration setup (ONLY PART REQUIRING ACCOUNTADMIN)
USE ROLE ACCOUNTADMIN;
-- Run Step 5

-- Part 4: Monitoring views
USE ROLE SYSADMIN;  -- or your custom role
-- Run Step 6
```

### Option B: Simplified Approach

Use ACCOUNTADMIN for the entire script:

```sql
USE ROLE ACCOUNTADMIN;
-- Run all steps
```

**Pros:** Simple, guaranteed to work
**Cons:** Not following least privilege principle

---

## Alternative: Delegating Privileges

If you want to avoid using ACCOUNTADMIN where possible, you can create a custom role with specific privileges:

```sql
USE ROLE ACCOUNTADMIN;

-- Create custom admin role for Openflow setup
CREATE ROLE openflow_admin;

-- Grant user/role management
GRANT CREATE USER ON ACCOUNT TO ROLE openflow_admin;
GRANT CREATE ROLE ON ACCOUNT TO ROLE openflow_admin;
GRANT MANAGE GRANTS ON ACCOUNT TO ROLE openflow_admin;

-- Grant network rule creation (optional - network rules can be created without ACCOUNTADMIN)
GRANT CREATE NETWORK RULE ON ACCOUNT TO ROLE openflow_admin;

-- NOTE: Cannot delegate CREATE INTEGRATION privilege
-- External Access Integrations ALWAYS require ACCOUNTADMIN

-- Assign to appropriate users
GRANT ROLE openflow_admin TO USER your_admin_user;
```

**With this approach:**
- Steps 1-4: Use `openflow_admin` role
- Step 5: **MUST use ACCOUNTADMIN** for integration
- Step 6: Use `openflow_admin` or appropriate role

---

## ACCOUNTADMIN Requirements Summary

**Objects that REQUIRE ACCOUNTADMIN:**
1. ✅ **External Access Integrations** - No way to delegate

**Objects that CAN use lower privileges:**
1. ❌ Users - SECURITYADMIN or USERADMIN
2. ❌ Roles - SECURITYADMIN
3. ❌ Grants - SECURITYADMIN or role with MANAGE GRANTS
4. ❌ Network Rules - ACCOUNTADMIN or custom role with CREATE NETWORK RULE
5. ❌ Views - Any role with CREATE VIEW privilege

---

## Best Practice Recommendations

### 1. For Production
- Create a custom `openflow_admin` role with delegated privileges
- Use ACCOUNTADMIN only for External Access Integration creation
- Document who has ACCOUNTADMIN access and audit usage

### 2. For Development/Testing
- Use ACCOUNTADMIN for simplicity
- Switch to least-privilege approach before production

### 3. Audit Trail
```sql
-- Check who created objects
SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY
WHERE QUERY_TEXT ILIKE '%kafka_external_access_integration%'
ORDER BY QUERY_START_TIME DESC;

-- Check current integration ownership
SHOW INTEGRATIONS LIKE 'kafka_external_access_integration';
```

---

## What If You Don't Have ACCOUNTADMIN?

If you don't have ACCOUNTADMIN access, you have two options:

### Option 1: Request ACCOUNTADMIN to Create Integration
Ask someone with ACCOUNTADMIN to run only Step 5:

```sql
USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE NETWORK RULE kafka_brokers_network_rule ...;
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION kafka_external_access_integration ...;
GRANT USAGE ON INTEGRATION kafka_external_access_integration TO ROLE openflow_kafka_role;
```

You can handle all other steps with SECURITYADMIN.

### Option 2: Use Openflow BYOC Instead of SPCS
- **BYOC deployment** doesn't require External Access Integrations
- Network connectivity handled at VPC level
- Still requires SECURITYADMIN for user/role setup

---

## Troubleshooting

### Error: "Insufficient privileges to operate on integration"
**Cause:** Trying to create/modify integration without ACCOUNTADMIN

**Solution:**
```sql
USE ROLE ACCOUNTADMIN;
-- Re-run integration creation
```

### Error: "Insufficient privileges to operate on user"
**Cause:** Trying to create user without SECURITYADMIN/USERADMIN

**Solution:**
```sql
USE ROLE SECURITYADMIN;  -- or USERADMIN
-- Re-run user creation
```

### Error: "Insufficient privileges to grant role"
**Cause:** Don't have SECURITYADMIN or role ownership

**Solution:**
```sql
USE ROLE SECURITYADMIN;
-- Re-run role grants
```

---

## References

- [Snowflake Access Control Privileges](https://docs.snowflake.com/en/user-guide/security-access-control-privileges)
- [External Access Integration](https://docs.snowflake.com/en/sql-reference/sql/create-external-access-integration)
- [Network Rules](https://docs.snowflake.com/en/sql-reference/sql/create-network-rule)
- [User Management](https://docs.snowflake.com/en/sql-reference/sql/create-user)
