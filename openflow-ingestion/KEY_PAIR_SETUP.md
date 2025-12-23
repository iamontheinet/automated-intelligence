# Openflow Key-Pair Authentication Setup

## Overview

This guide walks through setting up RSA key-pair authentication for the Openflow Kafka connector service user.

## Prerequisites

- OpenSSL installed on your machine
- Access to `openflow_kafka_user` in Snowflake with SECURITYADMIN or higher role

## Step 1: Generate RSA Key Pair

Run these commands in your terminal:

```bash
# 1. Generate 2048-bit RSA private key
openssl genrsa -out openflow_rsa_key.pem 2048

# 2. Extract public key from private key
openssl rsa -in openflow_rsa_key.pem -pubout -out openflow_rsa_key.pub

# 3. Convert private key to PKCS8 format (required by Snowflake)
openssl pkcs8 -topk8 -inform PEM -in openflow_rsa_key.pem \
  -outform PEM -nocrypt -out openflow_rsa_key.p8
```

**Output files:**
- `openflow_rsa_key.pem` - Original private key (keep secure, don't use directly)
- `openflow_rsa_key.pub` - Public key (for Snowflake)
- `openflow_rsa_key.p8` - PKCS8 private key (for Openflow connector)

## Step 2: Format Public Key for Snowflake

The public key needs to be formatted without headers/footers and newlines:

```bash
# Remove header, footer, and newlines
cat openflow_rsa_key.pub | \
  grep -v "BEGIN PUBLIC KEY" | \
  grep -v "END PUBLIC KEY" | \
  tr -d '\n' > openflow_rsa_key_formatted.txt

# View formatted key
cat openflow_rsa_key_formatted.txt
```

**Example output:**
```
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAy8Dbv8prpJ/0kKhlGeJYozo2t60EG8L0561g13R29LvMR5hyvGZlGJpmn65+A4xHXWUMud...
```

## Step 3: Set Public Key in Snowflake

```sql
USE ROLE ACCOUNTADMIN;

ALTER USER openflow_kafka_user 
SET RSA_PUBLIC_KEY = 'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAy8Dbv8prpJ/0kKhlGeJYozo2t60EG8L0561g13R29LvMR5hyvGZlGJpmn65+A4xHXWUMud...';
```

Replace the value with your actual formatted public key from Step 2.

## Step 4: Verify Key Setup

```sql
-- Check that RSA_PUBLIC_KEY_FP (fingerprint) is set
DESC USER openflow_kafka_user;

-- You should see RSA_PUBLIC_KEY_FP with a value like:
-- SHA256:vZ1j5kxMq8Y3Zw7y2X8L9a4bNc3dP5eQ6fR7gS8h9i0=
```

## Step 5: Store Private Key Securely

### Option A: AWS Secrets Manager (Recommended for BYOC on AWS)

```bash
# Store PKCS8 private key
aws secretsmanager create-secret \
  --name openflow/kafka/snowflake-private-key \
  --description "Private key for Openflow Kafka connector" \
  --secret-string file://openflow_rsa_key.p8 \
  --region us-east-1

# Optional: Store with key password if encrypted
aws secretsmanager create-secret \
  --name openflow/kafka/snowflake-credentials \
  --secret-string '{
    "private_key": "<paste-entire-pkcs8-key-here>",
    "private_key_password": "<password-if-encrypted>",
    "username": "openflow_kafka_user",
    "role": "openflow_kafka_role"
  }'
```

### Option B: Azure Key Vault (Recommended for BYOC on Azure)

```bash
# Store private key as secret
az keyvault secret set \
  --vault-name "openflow-keyvault" \
  --name "snowflake-private-key" \
  --file openflow_rsa_key.p8

# Or store as certificate
az keyvault certificate import \
  --vault-name "openflow-keyvault" \
  --name "openflow-snowflake-cert" \
  --file openflow_rsa_key.p8
```

### Option C: HashiCorp Vault

```bash
# Store in Vault
vault kv put secret/openflow/snowflake \
  private_key=@openflow_rsa_key.p8 \
  username=openflow_kafka_user \
  role=openflow_kafka_role
```

### Option D: File-Based (Development Only)

**⚠️ WARNING: Not recommended for production**

```bash
# Copy to secure location with restricted permissions
sudo cp openflow_rsa_key.p8 /etc/openflow/keys/
sudo chmod 600 /etc/openflow/keys/openflow_rsa_key.p8
sudo chown openflow:openflow /etc/openflow/keys/openflow_rsa_key.p8
```

## Step 6: Configure Openflow Connector

### Using Secrets Manager (Recommended)

1. **Configure Parameter Provider in Openflow UI:**
   - Navigate to hamburger menu → Controller Settings → Parameter Providers
   - Add AWS Secrets Manager / Azure Key Vault / HashiCorp Vault provider
   - Fetch parameters

2. **Reference in connector parameters:**
   ```
   Snowflake Private Key: #{aws_secrets:openflow/kafka/snowflake-credentials:private_key}
   Snowflake Private Key Password: #{aws_secrets:openflow/kafka/snowflake-credentials:private_key_password}
   ```

### Using Direct File Upload

1. In Openflow connector parameters:
   - Check "Reference asset" for "Snowflake Private Key File"
   - Upload `openflow_rsa_key.p8`
   - Leave "Snowflake Private Key" blank

2. Or paste key directly:
   - Copy entire contents of `openflow_rsa_key.p8` (including headers)
   - Paste into "Snowflake Private Key" parameter
   - Leave "Snowflake Private Key File" blank

**Example direct paste:**
```
-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDLwNu/ymukn/SQ
qGUZ4lijOja3rQQbwvTnrWDXdHb0u8xHmHK8ZmUYmmafrmYDjEddZQy51l1CtJpq
...
-----END PRIVATE KEY-----
```

## Step 7: Test Connection

### Test Script (Python)

```python
import snowflake.connector
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import serialization

# Load private key
with open("openflow_rsa_key.p8", "rb") as key_file:
    private_key = serialization.load_pem_private_key(
        key_file.read(),
        password=None,  # or b"password" if encrypted
        backend=default_backend()
    )

# Test connection
conn = snowflake.connector.connect(
    user='openflow_kafka_user',
    account='myorg-myaccount',
    private_key=private_key,
    role='openflow_kafka_role',
    warehouse='automated_intelligence_wh',
    database='automated_intelligence',
    schema='raw'
)

# Execute test query
cursor = conn.cursor()
cursor.execute("SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE()")
print(cursor.fetchone())

conn.close()
print("✅ Connection successful!")
```

### Test via SnowSQL

```bash
snowsql -a myorg-myaccount \
  -u openflow_kafka_user \
  --private-key-path openflow_rsa_key.p8 \
  -r openflow_kafka_role \
  -w automated_intelligence_wh \
  -d automated_intelligence \
  -s raw
```

## Step 8: Key Rotation (Optional)

To rotate keys without downtime:

```sql
-- 1. Generate new key pair (repeat Steps 1-2)

-- 2. Add second public key
ALTER USER openflow_kafka_user 
SET RSA_PUBLIC_KEY_2 = '<new-public-key>';

-- 3. Update Openflow connector to use new private key

-- 4. Test that new key works

-- 5. Remove old key
ALTER USER openflow_kafka_user 
UNSET RSA_PUBLIC_KEY;

-- 6. Promote key 2 to key 1
ALTER USER openflow_kafka_user 
SET RSA_PUBLIC_KEY = '<new-public-key>';

ALTER USER openflow_kafka_user 
UNSET RSA_PUBLIC_KEY_2;
```

## Security Best Practices

### ✅ DO

- **Use secrets manager** for production (AWS Secrets Manager, Azure Key Vault, HashiCorp Vault)
- **Restrict file permissions** to 600 (read/write owner only) if using files
- **Rotate keys regularly** (every 90-180 days)
- **Use encrypted private keys** with strong passwords in high-security environments
- **Store keys separately** from application code
- **Audit key usage** via Snowflake query history
- **Use dedicated service users** per integration

### ❌ DON'T

- **Never commit keys to git** (add to .gitignore)
- **Never share keys** via email or chat
- **Never hardcode keys** in application code
- **Never use same keys** across environments (dev/staging/prod)
- **Never store keys in plain text** on shared drives
- **Don't skip key rotation**
- **Don't reuse keys** across multiple services

## Troubleshooting

### Issue: "Invalid private key"

**Cause:** Key format incorrect or not PKCS8

**Solution:**
```bash
# Verify PKCS8 format
head -1 openflow_rsa_key.p8

# Should show:
# -----BEGIN PRIVATE KEY-----

# If shows "BEGIN RSA PRIVATE KEY", convert to PKCS8:
openssl pkcs8 -topk8 -inform PEM -in openflow_rsa_key.pem \
  -outform PEM -nocrypt -out openflow_rsa_key.p8
```

### Issue: "JWT token expired"

**Cause:** System clock skew or key mismatch

**Solution:**
1. Verify system time is synchronized
2. Confirm public key in Snowflake matches private key:
   ```bash
   # Extract public key from PKCS8
   openssl rsa -in openflow_rsa_key.p8 -pubout
   
   # Should match openflow_rsa_key.pub
   ```

### Issue: "User locked" or "Authentication failed"

**Cause:** Too many failed login attempts or wrong key

**Solution:**
```sql
-- Unlock user
ALTER USER openflow_kafka_user SET MINS_TO_UNLOCK = 0;

-- Verify RSA key is set
DESC USER openflow_kafka_user;

-- Reset key if needed
ALTER USER openflow_kafka_user 
SET RSA_PUBLIC_KEY = '<correct-public-key>';
```

### Issue: "Network error" during authentication

**Cause:** Cannot reach Snowflake account

**Solution:**
1. Verify account identifier format: `<org>-<account>`
2. Check network connectivity:
   ```bash
   curl https://<org>-<account>.snowflakecomputing.com
   ```
3. Verify no firewall blocking Snowflake endpoints

## Complete Example Configuration

**Openflow Connector Parameters:**
```yaml
# Snowflake Authentication
Snowflake Authentication Strategy: KEY_PAIR
Snowflake Account Identifier: myorg-myaccount
Snowflake Username: openflow_kafka_user
Snowflake Role: openflow_kafka_role
Snowflake Warehouse: automated_intelligence_wh

# Using Secrets Manager
Snowflake Private Key: #{aws_secrets:openflow/kafka/snowflake-credentials:private_key}
Snowflake Private Key Password: #{aws_secrets:openflow/kafka/snowflake-credentials:private_key_password}

# OR using direct file
Snowflake Private Key File: /etc/openflow/keys/openflow_rsa_key.p8
Snowflake Private Key Password: <leave-blank-if-not-encrypted>

# Destination
Destination Database: AUTOMATED_INTELLIGENCE
Destination Schema: RAW
```

## Cleanup Script

```bash
#!/bin/bash
# cleanup_keys.sh - Remove generated key files

# Remove local key files
rm -f openflow_rsa_key.pem
rm -f openflow_rsa_key.pub
rm -f openflow_rsa_key.p8
rm -f openflow_rsa_key_formatted.txt

echo "✅ Local key files removed"
echo "⚠️  Remember to remove keys from secrets manager if no longer needed"
```

## References

- [Snowflake Key-Pair Authentication](https://docs.snowflake.com/en/user-guide/key-pair-auth)
- [OpenSSL Documentation](https://www.openssl.org/docs/)
- [Openflow Secrets Management](https://docs.snowflake.com/en/user-guide/data-integration/openflow/setup-openflow-byoc)
