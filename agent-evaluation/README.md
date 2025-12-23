# Cortex Agent Evaluation for business_insights_agent

Evaluate the deployed `business_insights_agent` Cortex Agent using Snowflake's AI Observability framework (TruLens).

## Quick Start

### Simple Test (Quick Verification)
```bash
cd automated-intelligence/agent-evaluation
python3.11 simple_test.py
```

Quick smoke test - verifies agent responds correctly  
Runtime: ~30 seconds | Queries: 2

### Full Evaluation (Complete Quality Metrics)
```bash
cd automated-intelligence/agent-evaluation
python3.11 evaluate_cortex_agent.py
```

Comprehensive evaluation with AI-based quality metrics  
Runtime: 3-5 minutes | Queries: 8

**Quality Metrics (0-1 scale, higher is better):**
- `qs_relevance` - Question-answer relevance
- `correctness` - Response accuracy vs ground truth
- `coherence` - Response structure quality

## What Gets Evaluated

Tests the agent's ability to answer business questions:

1. What's the distribution of order sizes (small, medium, large, extra large)?
2. What percentage of orders used discounts?
3. Compare revenue from discounted vs non-discounted orders
4. What's the average discount percentage for orders that used discounts?
5. Show me revenue by day of week
6. What's the 7-day moving average of daily revenue?
7. What was the total revenue yesterday?
8. How many unique customers placed orders in the last 7 days?

## View Results

### Snowsight Dashboard
After running `evaluate_cortex_agent.py`:
1. Go to Snowsight
2. Navigate to: **AI & ML > Evaluations > business_insights_agent**
3. View individual traces, quality scores, response times, token usage

### SQL Query
```sql
USE DATABASE AUTOMATED_INTELLIGENCE;
USE SCHEMA RAW;

-- View evaluation records
SELECT * FROM TRULENS_RECORDS 
WHERE APP_NAME = 'business_insights_agent'
ORDER BY TIMESTAMP DESC;

-- View aggregated metrics
SELECT * FROM TRULENS_LEADERBOARD
WHERE APP_NAME = 'business_insights_agent';
```

## Architecture

**Agent Under Test:**
- Full Name: `snowflake_intelligence.agents.business_insights_agent`
- Model: Claude 4 Sonnet
- Tool: Cortex Analyst (text-to-SQL)
- Data Source: `automated_intelligence.dynamic_tables.business_insights_semantic_view`

**Evaluation Framework:**
- Framework: Snowflake AI Observability (TruLens)
- Evaluation Model: llama3.1-70b
- Storage: AUTOMATED_INTELLIGENCE.RAW
- Connection: dash-builder-si (SNOWFLAKE_INTELLIGENCE_ADMIN)

## Requirements

- **Python**: 3.9-3.12 (TruLens requirement)
- **Connection**: dash-builder-si with SNOWFLAKE_INTELLIGENCE_ADMIN role
- **Packages**: See requirements.txt

## Improvement Workflow

### Step 1: Run Evaluation
```bash
python3.11 evaluate_cortex_agent.py
```

### Step 2: Analyze Results
Check Snowsight or query TRULENS_LEADERBOARD for scores:
- `qs_relevance < 0.7` → Question misunderstood
- `correctness < 0.7` → Wrong answer
- `coherence < 0.7` → Unclear response

### Step 3: Improve Agent

**Low Answer Relevance (<0.7)**

Problem: Agent not addressing the specific question

Fix in `create_agent.sql`:
```sql
"orchestration": "Use the business_metrics tool for ALL queries about revenue, orders, discounts, and customer behavior. Extract specific metrics mentioned in the question. If the user asks for a comparison, provide both values side-by-side."
```

**Low Correctness (<0.7)**

Problem: Agent's answers don't match expected insights

Fixes:
1. Update ground truth in evaluation dataset if data changed
2. Fix semantic view if mappings are incorrect
3. Verify dynamic table freshness:
```sql
SELECT REFRESH_MODE, REFRESH_STATUS, DATA_TIMESTAMP
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(
    NAME_PREFIX => 'AUTOMATED_INTELLIGENCE.DYNAMIC_TABLES'
))
ORDER BY DATA_TIMESTAMP DESC;
```

**Low Coherence (<0.7)**

Problem: Responses are confusing or poorly structured

Fix in `create_agent.sql`:
```sql
"response": "Structure responses as:
1. Direct answer to the question
2. Supporting data points
3. Key insight (one sentence)

Use bullet points for lists. Format numbers with $ and % symbols. Keep responses under 3 paragraphs."
```

### Step 4: Redeploy and Re-evaluate
```bash
# Redeploy agent with improvements
snowsql -f create_agent.sql

# Re-evaluate
python3.11 evaluate_cortex_agent.py
```

### Step 5: Compare Runs
1. Go to AI & ML > Evaluations > business_insights_agent
2. Select both runs
3. Click "Compare"
4. See side-by-side metric improvements

## Iteration Example

**Iteration 1: Baseline**
```bash
python3.11 evaluate_cortex_agent.py
```
Results: Answer Relevance 0.75, Correctness 0.68

**Iteration 2: Improve Instructions**

Edit `create_agent.sql`:
```sql
"orchestration": "For discount questions, always show both discount and non-discount metrics for comparison."
```

Redeploy and re-evaluate:
```bash
snowsql -f create_agent.sql
python3.11 evaluate_cortex_agent.py
```
Results: Answer Relevance 0.82, Correctness 0.79 ✅ (+11%)

**Iteration 3: Compare in Snowsight**
1. Go to AI & ML > Evaluations > business_insights_agent
2. Select both runs
3. See side-by-side improvements

## Files

- `evaluate_cortex_agent.py` - Full evaluation with TruLens (MAIN)
- `simple_test.py` - Quick smoke test without TruLens
- `quick_test.py` - Alternative quick test
- `quick_test.sh` - Shell wrapper with auto-setup
- `requirements.txt` - Python dependencies
- `create_agent.sql` - Agent definition (reference)

## Troubleshooting

### Python Version Error
```
ERROR: Could not find a version that satisfies the requirement trulens-connectors-snowflake
```
**Fix**: Use Python 3.11 (not 3.13)
```bash
python3.11 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### 401 Unauthorized
**Issue**: Authentication error  
**Fix**: Script uses session token with `Snowflake Token="{token}"` header format

### SSL Certificate Error
**Issue**: SSL hostname mismatch  
**Fix**: Script disables SSL verification for testing (`verify=False`)

## Best Practices

✅ **Do:**
- Run simple_test.py first before full evaluation
- Run baseline evaluation before making changes
- Keep ground truth aligned with actual data
- Change one thing at a time (instructions, semantic view, etc.)
- Compare runs in Snowsight to measure improvements
- Set deployment thresholds (all metrics >0.75, improvement >10%)

❌ **Don't:**
- Run with Python 3.13+ (incompatible with TruLens)
- Modify connection role during evaluation
- Change database context during evaluation
- Make multiple changes simultaneously
