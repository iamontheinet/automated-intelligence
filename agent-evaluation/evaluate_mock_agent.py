"""
Mock Agent Evaluation - Simplified Approach
Create a simple mock agent to test AI Observability evaluation
"""

import os
import time
import random

# CRITICAL: Set before any TruLens imports
os.environ['TRULENS_OTEL_TRACING'] = '1'

from snowflake.snowpark import Session
from trulens.apps.custom import TruApp
from trulens.connectors.snowflake import SnowflakeConnector
from trulens.core.otel.instrument import instrument
from trulens.otel.semconv.trace import SpanAttributes
from trulens.core.app import RunConfig


class MockBusinessAgent:
    """Mock agent that simulates business insights responses"""
    
    @instrument(
        span_type=SpanAttributes.SpanType.RECORD_ROOT,
        attributes={
            SpanAttributes.RECORD_ROOT.INPUT: "query",
            SpanAttributes.RECORD_ROOT.OUTPUT: "return",
        }
    )
    def answer_query(self, query: str) -> str:
        """Main entry point - returns mock responses"""
        # Simulate processing time
        time.sleep(random.uniform(0.5, 1.5))
        
        # Return mock responses based on query keywords
        query_lower = query.lower()
        
        if 'revenue' in query_lower:
            return "Based on the data, total revenue for Q4 2024 is $2.5M, representing a 15% increase from the previous quarter."
        elif 'orders' in query_lower or 'order' in query_lower:
            return "There were 1,234 orders placed last month, with an average of 40 orders per day."
        elif 'average' in query_lower and 'value' in query_lower:
            return "The average order value is $125.50, calculated from 1,234 orders totaling $154,767."
        else:
            return f"I understand your question about '{query}'. Based on the available data, I can provide insights on revenue, orders, and customer metrics."


def run_mock_evaluation(connection_name: str = "dash-builder-si"):
    """Execute evaluation with mock agent"""
    
    print("=" * 70)
    print("MOCK AGENT EVALUATION - Testing AI Observability")
    print("=" * 70)
    
    # Step 1: Connect
    print("\n[1/7] Connecting to Snowflake...")
    session = Session.builder.configs({"connection_name": connection_name}).create()
    session.sql("USE DATABASE SNOWFLAKE_INTELLIGENCE").collect()
    session.sql("USE SCHEMA AGENTS").collect()
    print(f"✓ Connected as {session.get_current_role()}")
    
    # Step 2: Create connector
    print("\n[2/7] Creating SnowflakeConnector...")
    connector = SnowflakeConnector(snowpark_session=session)
    print("✓ Connector created")
    
    # Step 3: Create mock app
    print("\n[3/7] Creating mock agent...")
    app = MockBusinessAgent()
    print("✓ Mock agent created")
    
    # Step 4: Register app
    print("\n[4/7] Registering with AI Observability...")
    tru_app = TruApp(
        app=app,
        main_method=app.answer_query,
        app_name="mock_business_agent",
        app_version="v1.0",
        connector=connector
    )
    print("✓ App registered")
    
    # Step 5: Create dataset
    print("\n[5/7] Preparing evaluation dataset...")
    session.sql("""
        CREATE OR REPLACE TABLE EVAL_MOCK_QUERIES (
            query VARCHAR(500)
        )
    """).collect()
    
    session.sql("""
        INSERT INTO EVAL_MOCK_QUERIES (query)
        VALUES 
            ('What is the total revenue for Q4 2024?'),
            ('How many orders were placed last month?'),
            ('What is the average order value?')
    """).collect()
    print("✓ Dataset created with 3 queries")
    
    # Step 6: Create and start run
    print("\n[6/7] Creating evaluation run...")
    import datetime
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    
    run_config = RunConfig(
        run_name=f"mock_eval_{timestamp}",
        description="Mock agent evaluation to test AI Observability",
        label="mock",
        source_type="TABLE",
        dataset_name="SNOWFLAKE_INTELLIGENCE.AGENTS.EVAL_MOCK_QUERIES",
        dataset_spec={
            "RECORD_ROOT.INPUT": "QUERY"  # Column name must be uppercase
        },
        llm_judge_name="llama3.1-70b"
    )
    
    run = tru_app.add_run(run_config=run_config)
    print(f"✓ Run created: {run_config.run_name}")
    
    # Start the run
    print("\n  Starting run (invoking mock agent)...")
    start_time = time.time()
    try:
        run.start()
        elapsed = time.time() - start_time
        print(f"  ✓ run.start() completed ({elapsed:.1f}s)")
    except Exception as e:
        elapsed = time.time() - start_time
        print(f"  ✗ run.start() failed ({elapsed:.1f}s)")
        print(f"  Error: {str(e)[:300]}")
        import traceback
        traceback.print_exc()
        raise
    
    # Check status
    time.sleep(3)
    status = run.get_status()
    print(f"\n  Run Status: {status}")
    
    # Step 7: Compute metrics
    print("\n[7/7] Computing metrics...")
    if status.value in ['INVOCATION_COMPLETED', 'INVOCATION_PARTIALLY_COMPLETED']:
        print("  ✓ Invocations completed! Starting metrics computation...")
        run.compute_metrics(metrics=[
            "coherence",
            "answer_relevance"
        ])
        print("  ✓ Metrics computation triggered")
        
        # Wait for computation
        print("\n  Waiting for metrics computation...")
        for i in range(6):
            time.sleep(5)
            current_status = run.get_status()
            print(f"    Status check {i+1}: {current_status}")
            if current_status.value == 'COMPLETED':
                break
        
        final_status = run.get_status()
        print(f"\n  Final Status: {final_status}")
    else:
        print(f"  ⚠ Status is {status}, invocations did not complete")
        print("  This means run.start() did not successfully invoke the agent")
    
    print("\n" + "=" * 70)
    print("RESULTS")
    print("=" * 70)
    print(f"""
Run Name: {run_config.run_name}
App Name: mock_business_agent
Status: {status}

Check Snowsight:
  AI & ML > Evaluations > mock_business_agent > {run_config.run_name}

If status is INVOCATION_COMPLETED, you should see:
  - Trace data for 3 agent invocations
  - Metrics: coherence, answer_relevance
    """)
    
    session.close()
    return run_config.run_name


if __name__ == "__main__":
    run_name = run_mock_evaluation()
    print(f"\nCompleted: {run_name}")
