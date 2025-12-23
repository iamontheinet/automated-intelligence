# Openflow Kafka Connector - Configuration Reference

## Connector Parameter Reference

This document provides detailed configuration parameters for all three Openflow Kafka connector variants.

## Common Parameters (All Variants)

### Snowflake Destination Parameters

| Parameter | Description | Required | Example |
|-----------|-------------|----------|---------|
| **Destination Database** | Database where data will be persisted. Case-sensitive, use uppercase for unquoted identifiers. | Yes | `AUTOMATED_INTELLIGENCE` |
| **Destination Schema** | Schema where data will be persisted. Case-sensitive, use uppercase for unquoted identifiers. | Yes | `RAW` |
| **Snowflake Authentication Strategy** | Authentication method. Use `KEY_PAIR` for service users or `Session Token Authentication` for SPCS runtimes. | Yes | `KEY_PAIR` |
| **Snowflake Account Identifier** | Account identifier in format `<org-name>-<account-name>`. Blank if using session token auth. | Yes | `myorg-myaccount` |
| **Snowflake Private Key** | RSA private key in PKCS8 format with PEM headers. Can use parameter instead of file. | No* | `-----BEGIN PRIVATE KEY-----...` |
| **Snowflake Private Key File** | Path to private key file. Select "Reference asset" to upload. | No* | `/path/to/openflow_rsa_key.p8` |
| **Snowflake Private Key Password** | Password for encrypted private key. Leave blank if not encrypted. | No | `mypassword` |
| **Snowflake Role** | Role to use for ingestion. For session token auth, use runtime role from Openflow UI. | Yes | `openflow_kafka_role` |
| **Snowflake Username** | Username for authentication. Blank if using session token auth. | Yes | `openflow_kafka_user` |
| **Snowflake Warehouse** | Warehouse for running queries. | Yes | `automated_intelligence_wh` |

*Either Private Key or Private Key File must be provided

### Kafka Source Parameters (SASL Authentication)

| Parameter | Description | Required | Example |
|-----------|-------------|----------|---------|
| **Kafka Security Protocol** | Security protocol for broker communication. | Yes | `SASL_SSL` or `SASL_PLAINTEXT` |
| **Kafka SASL Mechanism** | SASL mechanism for authentication. | Yes | `PLAIN`, `SCRAM-SHA-256`, or `SCRAM-SHA-512` |
| **Kafka SASL Username** | Username for Kafka authentication. | Yes | `kafka-user` |
| **Kafka SASL Password** | Password for Kafka authentication. | Yes | `kafka-password` |
| **Kafka Bootstrap Servers** | Comma-separated list of Kafka brokers with ports. | Yes | `kafka-1:9092,kafka-2:9092` |

### Kafka Ingestion Parameters

| Parameter | Description | Required | Example |
|-----------|-------------|----------|---------|
| **Kafka Topic Format** | Whether topics are specified as names or pattern. | Yes | `names` or `pattern` |
| **Kafka Topics** | Comma-separated list or regex pattern. | Yes | `orders-topic,order-items-topic` |
| **Kafka Group Id** | Consumer group ID. Must be unique. | Yes | `openflow-orders-consumer` |
| **Kafka Auto Offset Reset** | Offset behavior when no previous offset found. | Yes | `earliest` or `latest` |
| **Topic To Table Map** | Optional mapping of topics to table names. | No | `orders-topic:orders,order-items-topic:order_items` |

#### Topic To Table Map Examples

```
# Map specific topics to tables
orders-topic:orders,order-items-topic:order_items

# Use regex patterns
topic[0-4]:low_range,topic[5-9]:high_range

# Map all topics to single table
.*:destination_table
```

## Variant-Specific Parameters

### 1. Apache Kafka for JSON Data Format

**Additional Parameters:**

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| **Schema Evolution** | Automatically add new columns when JSON schema changes. | `true` | `true` or `false` |
| **Date Format** | Format for parsing date strings. | `yyyy-MM-dd` | `yyyy-MM-dd` |
| **Timestamp Format** | Format for parsing timestamp strings. | `yyyy-MM-dd'T'HH:mm:ss` | `yyyy-MM-dd HH:mm:ss` |
| **Null Value Handling** | How to handle null JSON values. | `INSERT_NULL` | `INSERT_NULL` or `SKIP_FIELD` |

**Message Format:**
- Messages must be valid JSON objects
- Top-level JSON object fields map to table columns
- Nested objects are flattened or stored as VARIANT
- Arrays stored as VARIANT columns

**Example JSON Message:**
```json
{
  "order_id": "550e8400-e29b-41d4-a716-446655440000",
  "customer_id": 12345,
  "order_date": "2025-12-09T10:30:00",
  "total_amount": 299.99,
  "status": "completed"
}
```

### 2. Apache Kafka for AVRO Data Format

**Additional Parameters:**

| Parameter | Description | Required | Example |
|-----------|-------------|----------|---------|
| **Schema Registry URL** | URL of Confluent Schema Registry. | Yes | `https://schema-registry:8081` |
| **Schema Registry Auth Type** | Authentication method for schema registry. | No | `BASIC` or `NONE` |
| **Schema Registry Username** | Username for schema registry (if BASIC auth). | No | `registry-user` |
| **Schema Registry Password** | Password for schema registry (if BASIC auth). | No | `registry-password` |
| **Schema Evolution** | Automatically handle schema evolution. | `true` | `true` or `false` |

**Message Format:**
- Messages must be AVRO-encoded binary
- Schema fetched from Confluent Schema Registry
- Strong typing enforced by AVRO schema
- Supports schema evolution (backward/forward compatibility)

**Example AVRO Schema:**
```json
{
  "type": "record",
  "name": "Order",
  "fields": [
    {"name": "order_id", "type": "string"},
    {"name": "customer_id", "type": "long"},
    {"name": "order_date", "type": "long", "logicalType": "timestamp-millis"},
    {"name": "total_amount", "type": "double"},
    {"name": "status", "type": "string"}
  ]
}
```

### 3. Apache Kafka with DLQ and Metadata

**Additional Parameters:**

| Parameter | Description | Required | Example |
|-----------|-------------|----------|---------|
| **DLQ Topic Name** | Dead letter queue topic for failed messages. | No | `orders-topic-dlq` |
| **DLQ Enabled** | Enable dead letter queue. | No | `true` or `false` |
| **Include Message Headers** | Store Kafka message headers as metadata. | No | `true` or `false` |
| **Include Offset** | Store Kafka offset in metadata column. | No | `true` or `false` |
| **Include Partition** | Store Kafka partition in metadata column. | No | `true` or `false` |
| **Include Timestamp** | Store Kafka timestamp in metadata column. | No | `true` or `false` |
| **Include Topic** | Store Kafka topic name in metadata column. | No | `true` or `false` |
| **Metadata Column Prefix** | Prefix for metadata column names. | No | `_kafka_` |
| **Schematization Mode** | How to handle schema. | No | `NONE`, `SNOWFLAKE_SCHEMA`, or `AVRO_SCHEMA` |
| **Iceberg Tables Enabled** | Use Iceberg table format. | No | `true` or `false` |

**Metadata Columns Created:**

When metadata options are enabled, additional columns are created:

```sql
_kafka_topic VARCHAR         -- Source topic name
_kafka_partition INTEGER     -- Partition number
_kafka_offset BIGINT         -- Message offset
_kafka_timestamp TIMESTAMP   -- Kafka message timestamp
_kafka_headers VARIANT       -- Message headers (if present)
```

**DLQ Table Schema:**

Failed messages are written to DLQ topic with structure:
```
{
  "original_message": <base64-encoded>,
  "error_reason": "SQL compilation error: ...",
  "source_topic": "orders-topic",
  "partition": 0,
  "offset": 12345,
  "timestamp": 1733765432000
}
```

## Authentication Options

### Option 1: SASL Authentication (All Brokers)

Covered in "Kafka Source Parameters" above. Most common for cloud Kafka services.

### Option 2: mTLS (Mutual TLS)

**Additional Controller Services Required:**
- `StandardSSLContextService`

**Parameters:**
```
Kafka Security Protocol: SSL
SSL Context Service: <name-of-ssl-context-service>
```

**SSL Context Service Configuration:**
```
Truststore Filename: /path/to/kafka.truststore.jks
Truststore Password: <truststore-password>
Truststore Type: JKS
Keystore Filename: /path/to/kafka.keystore.jks
Keystore Password: <keystore-password>
Keystore Type: JKS
Key Password: <key-password>
```

### Option 3: AWS MSK IAM Authentication

**Parameters:**
```
Kafka Security Protocol: SASL_SSL
Kafka SASL Mechanism: AWS_MSK_IAM
```

**Additional Configuration:**
- Attach IAM role to Openflow runtime (BYOC) or compute pool (SPCS)
- IAM role must have permissions:
  ```json
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "kafka-cluster:Connect",
          "kafka-cluster:DescribeCluster",
          "kafka-cluster:ReadData",
          "kafka-cluster:DescribeTopic"
        ],
        "Resource": "*"
      }
    ]
  }
  ```

## Secrets Management

**Recommended Approach:** Use secrets manager instead of hardcoding credentials.

### AWS Secrets Manager Integration

1. **Store secrets in AWS Secrets Manager:**
   ```bash
   aws secretsmanager create-secret \
     --name openflow/kafka/credentials \
     --secret-string '{
       "username": "kafka-user",
       "password": "kafka-password",
       "private_key": "-----BEGIN PRIVATE KEY-----..."
     }'
   ```

2. **Configure Parameter Provider in Openflow:**
   - Navigate to hamburger menu → Controller Settings → Parameter Providers
   - Add AWS Secrets Manager Parameter Provider
   - Configure IAM role for Openflow runtime

3. **Reference secrets in parameters:**
   ```
   Kafka SASL Password: #{aws_secrets:openflow/kafka/credentials:password}
   Snowflake Private Key: #{aws_secrets:openflow/kafka/credentials:private_key}
   ```

### Azure Key Vault Integration

1. **Store secrets in Azure Key Vault**
2. **Configure Parameter Provider for Key Vault**
3. **Reference with:** `#{azure_keyvault:<vault-name>:<secret-name>}`

### HashiCorp Vault Integration

1. **Store secrets in Vault**
2. **Configure Parameter Provider for Vault**
3. **Reference with:** `#{vault:<path>:<key>}`

## Performance Tuning

### Connector Performance Parameters

| Parameter | Description | Default | Recommendation |
|-----------|-------------|---------|----------------|
| **Max Poll Records** | Max records per Kafka poll. | 500 | 1000-5000 for high throughput |
| **Max Poll Interval (ms)** | Max time between polls. | 300000 | Increase if processing is slow |
| **Session Timeout (ms)** | Consumer session timeout. | 10000 | Default is usually fine |
| **Batch Size** | Records per Snowflake batch. | 1000 | 5000-10000 for bulk loads |
| **Buffer Memory (bytes)** | Producer buffer size. | 33554432 | Increase for high throughput |

### Snowflake Warehouse Sizing

| Data Volume | Recommended Warehouse Size |
|-------------|---------------------------|
| < 100 MB/min | X-SMALL |
| 100-500 MB/min | SMALL |
| 500 MB - 2 GB/min | MEDIUM |
| 2-10 GB/min | LARGE |
| > 10 GB/min | X-LARGE or multi-cluster |

### Compute Pool Sizing (SPCS)

| Runtime Load | Node Count | Node Size |
|--------------|-----------|-----------|
| Light (< 1 topic) | 1 | SMALL |
| Medium (2-5 topics) | 2-3 | MEDIUM |
| Heavy (5+ topics) | 3-5 | LARGE |

## Monitoring and Alerting

### Key Metrics to Monitor

1. **Throughput**
   - Records/second ingested
   - Bytes/second ingested
   - Kafka consumer lag

2. **Latency**
   - Time from Kafka publish to Snowflake insert
   - End-to-end latency (source → Snowflake)

3. **Errors**
   - Failed records in DLQ
   - Connection failures to Kafka/Snowflake
   - Schema evolution errors

### Openflow UI Monitoring

Access monitoring at: `https://<runtime-url>/nifi`

**Key Views:**
- **Summary**: Overall throughput, queued data
- **Provenance**: Data lineage and event history
- **Bulletins**: Errors and warnings
- **Processors**: Per-component statistics

### Snowflake Monitoring Queries

```sql
-- Check ingestion volume
SELECT 
  DATE_TRUNC('hour', _kafka_timestamp) as hour,
  COUNT(*) as records,
  SUM(LENGTH(TO_JSON(*))) as bytes
FROM automated_intelligence.raw.orders
GROUP BY hour
ORDER BY hour DESC;

-- Check ingestion lag
SELECT 
  DATEDIFF('minute', MAX(_kafka_timestamp), CURRENT_TIMESTAMP()) as lag_minutes
FROM automated_intelligence.raw.orders;

-- Check DLQ records (if using DLQ connector)
SELECT COUNT(*), error_reason
FROM automated_intelligence.raw.orders_dlq
GROUP BY error_reason;
```

## Troubleshooting

### Common Issues

#### Issue: Consumer Not Advancing
**Symptoms:** Kafka consumer lag increasing, no data in Snowflake

**Solutions:**
1. Check Kafka credentials and connectivity
2. Verify consumer group ID is unique
3. Check Openflow processor status (should be green)
4. Review bulletins for errors

#### Issue: Schema Evolution Failures
**Symptoms:** DLQ records with "incompatible schema" errors

**Solutions:**
1. Enable schema evolution in connector parameters
2. Check that new fields are nullable or have defaults
3. Review AVRO schema compatibility (backward/forward)

#### Issue: Network Connectivity Failures
**Symptoms:** "Unable to connect" errors in bulletins

**Solutions (SPCS):**
1. Verify network rules include ALL Kafka broker endpoints
2. Check external access integration is granted to role
3. Test connectivity from Snowflake:
   ```sql
   SELECT SYSTEM$VERIFY_EXTERNAL_ACCESS('<integration-name>');
   ```

#### Issue: Performance Degradation
**Symptoms:** Increasing lag, slow ingestion

**Solutions:**
1. Scale up Snowflake warehouse
2. Increase batch size in connector
3. Add more Openflow runtime nodes
4. Check Kafka broker performance

## Configuration Examples

### Example 1: Simple JSON Ingestion (Development)

```
=== Snowflake Destination ===
Destination Database: DEV_DATABASE
Destination Schema: RAW
Snowflake Auth: KEY_PAIR
Snowflake Account: myorg-dev
Snowflake Username: openflow_dev_user
Snowflake Role: openflow_dev_role
Snowflake Warehouse: DEV_WH

=== Kafka Source ===
Security Protocol: SASL_PLAINTEXT
SASL Mechanism: PLAIN
SASL Username: dev-user
SASL Password: ********
Bootstrap Servers: localhost:9092

=== Ingestion ===
Topic Format: names
Topics: orders-dev,order-items-dev
Group ID: openflow-dev-consumer
Auto Offset Reset: earliest
Topic Map: orders-dev:orders,order-items-dev:order_items
```

### Example 2: Production AVRO with DLQ

```
=== Snowflake Destination ===
Destination Database: PROD_DATABASE
Destination Schema: RAW
Snowflake Auth: KEY_PAIR
Snowflake Account: myorg-prod
Snowflake Username: openflow_prod_user
Snowflake Role: openflow_prod_role
Snowflake Warehouse: PROD_WH

=== Kafka Source ===
Security Protocol: SASL_SSL
SASL Mechanism: SCRAM-SHA-512
SASL Username: #{aws_secrets:prod/kafka:username}
SASL Password: #{aws_secrets:prod/kafka:password}
Bootstrap Servers: kafka-1.prod:9093,kafka-2.prod:9093,kafka-3.prod:9093

=== Ingestion ===
Topic Format: pattern
Topics: orders.*
Group ID: openflow-prod-orders
Auto Offset Reset: latest

=== DLQ & Metadata ===
DLQ Enabled: true
DLQ Topic: orders-dlq
Include Offset: true
Include Timestamp: true
Include Topic: true
Metadata Prefix: _kafka_

=== AVRO ===
Schema Registry URL: https://schema-registry.prod:8081
Schema Registry Auth: BASIC
Schema Registry User: #{aws_secrets:prod/schema-registry:username}
Schema Registry Pass: #{aws_secrets:prod/schema-registry:password}
```

### Example 3: AWS MSK with IAM Auth

```
=== Kafka Source (MSK) ===
Security Protocol: SASL_SSL
SASL Mechanism: AWS_MSK_IAM
Bootstrap Servers: b-1.msk.us-east-1.amazonaws.com:9098,b-2.msk.us-east-1.amazonaws.com:9098

=== Network Rule (SPCS) ===
CREATE NETWORK RULE msk_brokers
  TYPE = HOST_PORT
  MODE = EGRESS
  VALUE_LIST = (
    'b-1.msk.us-east-1.amazonaws.com:9098',
    'b-2.msk.us-east-1.amazonaws.com:9098'
  );
```

## Additional Resources

- [Openflow Documentation](https://docs.snowflake.com/user-guide/data-integration/openflow/about)
- [Apache NiFi Documentation](https://nifi.apache.org/docs.html)
- [Kafka Connector Setup Guide](https://docs.snowflake.com/user-guide/data-integration/openflow/connectors/kafka/setup)
- [Snowflake Support Portal](https://community.snowflake.com/)
