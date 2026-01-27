# Snowflake Managed MCP Server

Exposes Snowflake Cortex services, ML models, and SQL execution as tools for external AI agents via the Model Context Protocol (MCP).

## Tools Exposed

| Tool | Type | Description |
|------|------|-------------|
| `product-reviews-search` | Cortex Search | Semantic search over product reviews |
| `support-tickets-search` | Cortex Search | Semantic search over support tickets |
| `business-insights` | Cortex Analyst | Natural language queries for business metrics |
| `product-recommendations` | Stored Procedure | ML-powered recommendations by customer segment |
| `execute-sql` | SQL Execution | Ad-hoc SQL queries |

## Setup

```bash
# 1. Create MCP server
snow sql -c <connection-name> -f setup_mcp_server.sql

# 2. Configure access control
snow sql -c <connection-name> -f setup_access_control.sql

# 3. (Optional) Setup OAuth for client authentication
snow sql -c <connection-name> -f setup_oauth.sql
```

## MCP Client Endpoint

```
https://<account_url>/api/v2/databases/AUTOMATED_INTELLIGENCE/schemas/SEMANTIC/mcp-servers/AI_GATEWAY
```

## Example: Tool Discovery

```json
POST /api/v2/databases/AUTOMATED_INTELLIGENCE/schemas/SEMANTIC/mcp-servers/AI_GATEWAY
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/list"
}
```

## Example: Search Product Reviews

```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/call",
  "params": {
    "name": "product-reviews-search",
    "arguments": {
      "query": "quality issues with boots",
      "limit": 5
    }
  }
}
```

## Example: Business Insights Query

```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "tools/call",
  "params": {
    "name": "business-insights",
    "arguments": {
      "message": "What is our total revenue by customer segment?"
    }
  }
}
```

## Example: Product Recommendations

```json
{
  "jsonrpc": "2.0",
  "id": 4,
  "method": "tools/call",
  "params": {
    "name": "product-recommendations",
    "arguments": {
      "num_customers": 3,
      "num_products": 5,
      "segment": "LOW_ENGAGEMENT"
    }
  }
}
```

## Security

- RBAC applies to MCP server and individual tools
- Row access policies still filter data (e.g., WEST_COAST_MANAGER sees regional data only)
- OAuth recommended for production client authentication

## Cleanup

```bash
snow sql -c <connection-name> -f cleanup.sql
```

## References

- [Snowflake MCP Server Docs](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-mcp)
- [MCP Quickstart](https://quickstarts.snowflake.com/guide/getting-started-with-snowflake-mcp-server/index.html)
