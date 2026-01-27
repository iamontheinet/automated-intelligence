# Cortex Code Demo Script (5-7 min)

## Overview
A focused demo of Cortex Code for a mixed technical and non-technical audience. Showcases AI-powered development from natural language to production-ready code.

---

## Opening (30 sec)

> "Cortex Code is Snowflake's AI-powered development assistant. It understands your data, generates code from natural language, and executes directly against Snowflake. Let me show you how it accelerates development for both technical and business users."

---

## Demo Flow

### 1. Start with a Business Question (1 min)

```
> Show me top 10 customers by total spend
```

**Talk track:**
> "I simply ask a question in plain English. Cortex Code understands my schema, joins the right tables, and generates production-ready SQL. Notice it automatically found the customers and orders tables and created the proper aggregation."

*Let it generate and run the SQL*

---

### 2. Explore Data (1 min)

```
> What tables do I have available?
```
or
```
> Describe the orders table
```

**Talk track:**
> "For anyone unfamiliar with the data model, you can explore interactively. This is great for onboarding new team members or business analysts who want to self-serve."

---

### 3. Generate a dbt Model (1.5 min)

```
> Create a dbt model for customer churn risk
```

**Talk track:**
> "Now watch this—I'm asking for a dbt transformation model. Cortex Code generates the full SQL with CTEs, proper structure, and even documentation. For data engineers, this means faster development. For the business, it means faster time to insights."

*Show the generated model structure*

**Note:** This prompt is safe—it won't overwrite existing models. Existing models to avoid:
`customer_lifetime_value`, `customer_segmentation`, `monthly_cohorts`, `product_affinity`, `product_recommendations`

---

### 4. Ask an Analytical Question (1 min)

```
> What's the average order value by product category this quarter?
```

**Talk track:**
> "Whether you're a data analyst or a VP wanting a quick answer, you can ask questions naturally. No need to know the exact table names or SQL syntax."

---

### 5. Debug/Explain (1 min)

```
> Explain what this query does: [paste a complex query]
```
or
```
> Why might this query be slow?
```

**Talk track:**
> "Cortex Code isn't just for generation—it helps you understand existing code. Great for code reviews, debugging, or learning."

---

## Closing (30 sec)

> "What you've seen is AI-native development:
> - **Business users** can self-serve data questions
> - **Analysts** accelerate their SQL writing  
> - **Engineers** generate dbt models and debug faster
> 
> All within a single interface, directly connected to your Snowflake data."

---

## Key Points to Emphasize

| Audience | Value |
|----------|-------|
| **Non-technical** | Ask questions in plain English, get answers |
| **Analysts** | Write SQL faster, explore unfamiliar data |
| **Engineers** | Generate dbt models, debug code, automate tasks |

---

## Presenter Tips

- Keep queries simple and results visible
- Pause briefly after each generation to let audience absorb
- If something fails, show how to iterate ("Let me refine that...")
- End with: "One platform, from question to production code"

---

## Backup Prompts

If you need alternatives during the demo:

```
> How many orders were placed last week?
```

```
> Show me revenue trend by month for the past year
```

```
> What products have the highest return rate?
```

```
> Create a SQL query to find customers who haven't ordered in 90 days
```

### Safe dbt Model Prompts (won't overwrite existing)

```
> Create a dbt model for customer churn risk
```

```
> Create a dbt model for weekly sales summary
```

```
> Create a dbt model for order fulfillment metrics
```

```
> Create a dbt model for customer RFM scoring
```

---

## Existing dbt Models (DO NOT recreate)

These models already exist in `dbt-analytics/models/`:

| Model | Path |
|-------|------|
| `customer_lifetime_value` | marts/customer/ |
| `customer_segmentation` | marts/customer/ |
| `monthly_cohorts` | marts/cohort/ |
| `product_affinity` | marts/product/ |
| `product_recommendations` | marts/product/ |
| `stg_customers` | staging/ |
| `stg_orders` | staging/ |
| `stg_order_items` | staging/ |
| `stg_products` | staging/ |
