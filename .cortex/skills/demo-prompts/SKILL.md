---
name: demo-prompts
description: "Demo prompts for Cortex Code presentation. Use when: running demos, showing capabilities, presenting Cortex Code, walking through examples, showcasing features. Triggers: demo, presentation, show demo, run demo, start demo, prompt, walkthrough, showcase, show me the demo, let's demo, demo time."
---

# Cortex Code Demo Prompts

Run these prompts in order for a 5-7 minute demo.

## Project Root

**Always start from**: `/Users/ddesai/Apps/automated-intelligence`

## Connection & Database Context

**CRITICAL**: Always use the `AUTOMATED_INTELLIGENCE` database in all SQL queries.

### SQL Query Format Rules

**CORRECT** - Always use AUTOMATED_INTELLIGENCE.SCHEMA.TABLE format:
```sql
SELECT * FROM AUTOMATED_INTELLIGENCE.RAW.customers;
SELECT * FROM AUTOMATED_INTELLIGENCE.DBT_ANALYTICS.customer_lifetime_value;
```

**WRONG** - Never omit the database name:
```sql
-- NEVER DO THIS:
SELECT * FROM RAW.customers;
SELECT * FROM DBT_ANALYTICS.customer_lifetime_value;
```

Always use fully qualified names: `AUTOMATED_INTELLIGENCE.SCHEMA.TABLE`.

### Available Schemas & Tables

| Schema | Key Tables |
|--------|------------|
| `RAW` | `customers`, `orders`, `order_items`, `product_catalog`, `product_reviews`, `support_tickets` |
| `DYNAMIC_TABLES` | `enriched_orders`, `fact_orders`, `daily_business_metrics`, `product_performance_metrics` |
| `INTERACTIVE` | `customer_order_analytics`, `order_lookup` |
| `DBT_ANALYTICS` | `customer_lifetime_value`, `customer_segmentation`, `product_affinity`, `product_recommendations`, `monthly_cohorts` |

### dbt Model Paths (DO NOT search - use these exact paths)

**Staging models** (`models/staging/`):
- `models/staging/stg_customers.sql`
- `models/staging/stg_orders.sql`
- `models/staging/stg_order_items.sql`
- `models/staging/stg_products.sql`

**Mart models** (`models/marts/`):
- `models/marts/customer/customer_lifetime_value.sql` - CLV calculation
- `models/marts/customer/customer_segmentation.sql` - Behavioral segmentation
- `models/marts/product/product_affinity.sql` - Product co-purchase analysis
- `models/marts/product/product_recommendations.sql` - Recommendation engine
- `models/marts/cohort/monthly_cohorts.sql` - Cohort retention analysis

**For Prompt 2** (show churn risk model): Display model code without writing files
**For Prompt 3** (explain CLV): Read directly from `models/marts/customer/customer_lifetime_value.sql`

### Python File Paths (DO NOT search - use these exact paths)

**Snowpipe Streaming Python** (`snowpipe-streaming-python/src/`):
- `src/data_generator.py` - DataGenerator class for synthetic data
- `src/parallel_streaming_orchestrator.py` - Multi-threaded streaming coordinator
- `src/snowpipe_streaming_manager.py` - Snowpipe API wrapper
- `src/models.py` - Customer, Order, OrderItem dataclasses
- `src/config_manager.py` - Configuration loading
- `src/reconciliation_manager.py` - Data reconciliation logic

**For Prompt 4** (code review): Read `src/data_generator.py` directly
**For Prompt 5** (CLV dashboard): Generate Streamlit app using pattern from `streamlit-dashboard/shared.py`
**For Prompt 6** (retry logic): Read `src/parallel_streaming_orchestrator.py` directly

### Streamlit Connection Pattern (for Prompt 5)

**IMPORTANT**: Use `st.connection("snowflake")` for LOCAL development. The `get_active_session()` method ONLY works when deployed to Snowflake's native Streamlit environment.

**CORRECT - For local development (use this for demos):**
```python
import streamlit as st

# Connect to Snowflake (works locally via default connection)
conn = st.connection("snowflake")

# Query CLV data
df = conn.query("""
    SELECT customer_id, total_revenue, total_orders, 
           avg_order_value, value_tier, customer_status
    FROM AUTOMATED_INTELLIGENCE.DBT_ANALYTICS.customer_lifetime_value
    ORDER BY total_revenue DESC
""")
```

**WRONG - Only works when deployed to Snowflake Streamlit:**
```python
# DO NOT USE THIS FOR LOCAL DEMOS - will cause error:
# "SnowparkSessionException: No default Session is found"
from snowflake.snowpark.context import get_active_session
session = get_active_session()  # FAILS locally!
```

### Exact Column Names (use these exactly)

**RAW.customers:**
```
customer_id INT, first_name VARCHAR, last_name VARCHAR, email VARCHAR, phone VARCHAR, 
address VARCHAR, city VARCHAR, state VARCHAR(2), zip_code VARCHAR, registration_date DATE, 
customer_segment VARCHAR  -- NOTE: column is "customer_segment" NOT "segment"
```

**customer_segment values (CASE-SENSITIVE):** `'Premium'`, `'Standard'`, `'Basic'`

**RAW.orders:**
```
order_id VARCHAR, customer_id INT, order_date TIMESTAMP, order_status VARCHAR,  -- NOTE: "order_status" NOT "status"
total_amount DECIMAL, discount_percent DECIMAL, shipping_cost DECIMAL  -- NOTE: "discount_percent" NOT "discount_amount"
```

**order_status values (CASE-SENSITIVE):** `'Completed'`, `'Pending'`, `'Shipped'`, `'Cancelled'`, `'Processing'`
- Use `'Completed'` NOT `'completed'`
- Use `'Pending'` NOT `'pending'`

**RAW.order_items:**
```
order_item_id VARCHAR, order_id VARCHAR, product_id INT, product_name VARCHAR, 
product_category VARCHAR, quantity INT, unit_price DECIMAL, line_total DECIMAL
```

**product_category values (CASE-SENSITIVE):** `'Skis'`, `'Snowboards'`, `'Boots'`, `'Accessories'`

**product_name values:** `'Powder Skis'`, `'All-Mountain Skis'`, `'Freestyle Snowboard'`, `'Freeride Snowboard'`, `'Ski Boots'`, `'Snowboard Boots'`, `'Ski Poles'`, `'Ski Goggles'`, `'Snowboard Bindings'`, `'Ski Helmet'`

**state values:** `'CO'`, `'UT'`, `'WY'`, `'CA'`, `'WA'`, `'OR'`, `'MT'`, `'ID'`, `'NV'`, `'BC'`

**DBT_ANALYTICS.customer_lifetime_value:**
```
customer_id, total_revenue, total_orders, avg_order_value, customer_status, value_tier
```

**value_tier values (lowercase):** `'high_value'`, `'medium_value'`, `'low_value'`, `'no_purchases'`

**customer_status values (lowercase):** `'active'`, `'at_risk'`, `'churned'`, `'never_purchased'`

**DBT_ANALYTICS.customer_segmentation:**
```
customer_id, behavioral_segment, segment_priority, recommended_action
```

**behavioral_segment values (lowercase):** `'champions'`, `'loyal_customers'`, `'potential_loyalists'`, `'promising'`, `'at_risk'`, `'cant_lose_them'`, `'hibernating_high_value'`, `'lost'`, `'new_customers'`, `'needs_attention'`

## Prompt List

| # | Persona | Prompt | Working Directory |
|---|---------|--------|-------------------|
| 1 | Data Analyst | Generate a SQL query for the top 10 customers by total spend and save to demo-output/ | (root) |
| 2 | Data Engineer | Generate a dbt model for customer churn risk and save to demo-output/ | `dbt-analytics/` |
| 3 | Data Engineer | Explain models/marts/customer/customer_lifetime_value.sql | `dbt-analytics/` |
| 4 | Developer | Review src/data_generator.py and identify any edge cases or potential bugs | `snowpipe-streaming-python/` |
| 5 | Developer | Generate a Streamlit app for CLV dashboard using AUTOMATED_INTELLIGENCE.DBT_ANALYTICS.customer_lifetime_value and save to demo-output/ | `streamlit-dashboard/` |
| 6 | Developer | Generate retry logic with exponential backoff for parallel_streaming_orchestrator.py and save to demo-output/ | `snowpipe-streaming-python/` |

## Directory Mapping

Before executing each prompt, **automatically change to the correct directory**:

| Prompt | Directory | Full Path |
|--------|-----------|-----------|
| 1 | Project root | `/Users/ddesai/Apps/automated-intelligence` |
| 2 | dbt-analytics | `/Users/ddesai/Apps/automated-intelligence/dbt-analytics` |
| 3 | dbt-analytics | `/Users/ddesai/Apps/automated-intelligence/dbt-analytics` |
| 4 | snowpipe-streaming-python | `/Users/ddesai/Apps/automated-intelligence/snowpipe-streaming-python` |
| 5 | streamlit-dashboard | `/Users/ddesai/Apps/automated-intelligence/streamlit-dashboard` |
| 6 | snowpipe-streaming-python | `/Users/ddesai/Apps/automated-intelligence/snowpipe-streaming-python` |

## Demo Output Directory

**For code-generating prompts**, save files to: `/Users/ddesai/Apps/automated-intelligence/demo-output/`

This folder is safe to write to - it contains only demo-generated files and can be cleaned up after the demo.

| Prompt | Output File |
|--------|-------------|
| 1 | `demo-output/top_customers_query.sql` |
| 2 | `demo-output/customer_churn_risk.sql` |
| 5 | `demo-output/clv_dashboard.py` |
| 6 | `demo-output/retry_logic_example.py` |

Prompts 3 and 4 are read/explain tasks - no output file needed.

## Follow-Up Options

After completing each prompt, offer relevant follow-up actions:

| Prompt | Follow-Up Question | Action |
|--------|-------------------|--------|
| 1 | "Run it" or "Execute" | Execute the SQL query against Snowflake and show results |
| 2 | "Run it" or "Execute" | Execute the dbt model SQL against Snowflake to preview results |
| 5 | "Run it" or "Start it" | Execute `streamlit run demo-output/clv_dashboard.py` |

**Example flow:**
1. User: "prompt 1"
2. You: Generate SQL, save to file, show code
3. You: "Would you like me to **run it** against Snowflake?"
4. User: "run it"
5. You: Execute query, display results

**Follow-up triggers**: "run it", "execute", "run", "try it", "run tests", "yes"

## Instructions

**SAFE DEMO**: Only write to the `demo-output/` folder. NEVER modify existing source files.

1. **Change to correct directory FIRST** - Before executing any prompt, silently change to the directory specified in the Directory Mapping table above. Do not announce the directory change.

2. **Display the persona introduction**:
   > **As a/an [persona], I can ask: "[prompt]"**

3. **Suppress intermediate output** - Do NOT show:
   - Tool call progress or status messages
   - Intermediate SQL queries being built
   - Multiple query attempts or iterations
   - Debugging or exploratory queries
   - Directory change announcements
   
   **ONLY show**:
   - The persona introduction
   - The final SQL query (in a code block) or final code/output
   - Confirmation that file was saved (e.g., "Saved to `demo-output/top_customers_query.sql`")
   - A brief 1-2 sentence interpretation
   - **Follow-up offer** (if applicable): "Would you like me to **run it**?"

4. **After completing each prompt**, ALWAYS show the full prompt list table again with the **next prompt highlighted in bold** using `**` markers around that row's content. Example after completing prompt 1:

   | # | Persona | Prompt |
   |---|---------|--------|
   | ~~1~~ | ~~Data Analyst~~ | ~~Generate SQL query for top 10 customers~~ |
   | **2** | **Data Engineer** | **Generate dbt model for customer churn risk** |
   | 3 | Data Engineer | Explain the CLV dbt model |
   | 4 | Developer | Review data_generator.py for edge cases/bugs |
   | 5 | Developer | Generate Streamlit CLV dashboard |
   | 6 | Developer | Generate retry logic with exponential backoff |

5. Use ~~strikethrough~~ for completed prompts and **bold** for the next prompt

6. When user says "prompt 1", "prompt 2", etc., run that specific prompt

7. When user says "next prompt" or "next", run the next prompt in sequence

8. Keep responses concise and demo-friendly

9. **ALWAYS use AUTOMATED_INTELLIGENCE database prefix** - Use fully qualified names in all SQL queries.

10. **SQL format is AUTOMATED_INTELLIGENCE.SCHEMA.TABLE** - Examples:
    - `AUTOMATED_INTELLIGENCE.RAW.customers` (correct)
    - `AUTOMATED_INTELLIGENCE.RAW.orders` (correct)
    - `AUTOMATED_INTELLIGENCE.DBT_ANALYTICS.customer_lifetime_value` (correct)
    - `RAW.customers` (WRONG - never do this)

---

## Developer Capabilities Reference

*Internal reference only - not for display during demos. Use when audience asks "what else can you do?"*

### Code Analysis & Review
- Review code for bugs, edge cases, security vulnerabilities
- Explain complex code or unfamiliar codebases
- Identify performance bottlenecks
- Check for OWASP top 10 vulnerabilities

### Code Generation
- Write new functions, classes, modules
- Generate unit tests and integration tests
- Create API endpoints, data models, schemas
- Build CLI tools, scripts, automation

### Refactoring & Optimization
- Refactor code for readability or performance
- Migrate code between frameworks/languages
- Add type hints, error handling, logging
- Implement design patterns

### Debugging
- Trace through error messages and stack traces
- Identify root causes of bugs
- Fix failing tests
- Debug SQL queries, API calls, data pipelines

### Data Engineering (Snowflake-specific)
- Write and optimize SQL queries
- Create dbt models, dynamic tables, streams
- Build Snowpipe streaming pipelines
- Design data models and schemas

### DevOps & Infrastructure
- Write Dockerfiles, CI/CD configs
- Create shell scripts, automation
- Debug deployment issues
- Set up testing frameworks

### Example Prompts for Ad-Hoc Demos
- "Review this file for security issues"
- "Write unit tests for the data_generator module"
- "Refactor this function to use async/await"
- "Why is this query slow?"
- "Add error handling to this API endpoint"
- "Explain how this codebase handles authentication"
- "Find all TODO comments in the project"
