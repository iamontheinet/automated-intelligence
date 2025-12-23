"""
Mock Agent Evaluation - Using DATAFRAME source
Test with explicit DataFrame instead of TABLE source
"""

import os
import time
import random
import pandas as pd

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
        print(f"  → Answering: {query[:50]}...")
        time.sleep(random.uniform(0.3, 0.7))
        
        query_lower = query.lower()
        if 'revenue' in query_lower:
            return "Total revenue for Q4 2024 is $2.5M, up 15% from Q3."
        elif 'orders' in query_lower:
            return "1,234 orders were placed last month, averaging 40 per day."
        elif 'average' in query_lower:
            return "Average order value is $125.50 based on 1,234 orders."
        else:
            return f"Analysis for query: {query}"


def run_dataframe_evaluation(connection_name: str = "dash-builder-si"):
    """Execute evaluation using DATAFRAME source"""
    
    print("=" * 70)
    print("DATAFRAME EVALUATION - Testing AI Observability")
    print("=" * 70)
    
    # Step 1: Connect
    print("\n[1/6] Connecting to Snowflake...")
    session = Session.builder.configs({"connection_name": connection_name}).create()
    session.sql("USE DATABASE SNOWFLAKE_INTELLIGENCE").collect()
    session.sql("USE SCHEMA AGENTS").collect()
    print(f"✓ Connected")
    
    # Step 2: Create connector
    print("\n[2/6] Creating connector...")
    connector = SnowflakeConnector(snowpark_session=session)
    print("✓ Connector created")
    
    # Step 3: Create app
    print("\n[3/6] Creating mock agent...")
    app = MockBusinessAgent()
    print("✓ Mock agent created")
    
    # Step 4: Register app
    print("\n[4/6] Registering app...")
    tru_app = TruApp(
        app=app,
        main_method=app.answer_query,
        app_name="mock_business_agent",
        app_version="v1.1_dataframe",
        connector=connector
    )
    print("✓ App registered")
    
    # Step 5: Create DataFrame with queries
    print("\n[5/6] Creating DataFrame dataset...")
    input_df = pd.DataFrame({
        'query': [
            'What is the total revenue for Q4 2024?',
            'How many orders were placed last month?',
            'What is the average order value?'
        ]
    })
    print(f"✓ DataFrame created with {len(input_df)} queries")
    print(f"  Columns: {input_df.columns.tolist()}")
    
    # Step 6: Create and start run
    print("\n[6/6] Creating and starting evaluation run...")
    import datetime
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    
    run_config = RunConfig(
        run_name=f"mock_df_{timestamp}",
        description="Mock agent evaluation with DATAFRAME source",
        label="mock_df",
        source_type="DATAFRAME",
        dataset_name="mock_dataframe_dataset",  # Still need a name even with DATAFRAME
        dataset_spec={
            "RECORD_ROOT.INPUT": "query"  # lowercase to match DataFrame column
        },
        llm_judge_name="llama3.1-70b"
    )
    
    run = tru_app.add_run(run_config=run_config)
    print(f"✓ Run created: {run_config.run_name}")
    
    # Start with DataFrame
    print("\n  Starting run with DataFrame input...")
    start_time = time.time()
    try:
        run.start(input_df=input_df)  # Pass DataFrame directly
        elapsed = time.time() - start_time
        print(f"  ✓ run.start() completed ({elapsed:.1f}s)")
    except Exception as e:
        elapsed = time.time() - start_time
        print(f"  ✗ run.start() failed ({elapsed:.1f}s)")
        print(f"  Error: {str(e)[:500]}")
        import traceback
        traceback.print_exc()
        raise
    
    # Check status
    time.sleep(2)
    status = run.get_status()
    print(f"\n  Run Status: {status}")
    
    # Compute metrics if successful
    if status.value in ['INVOCATION_COMPLETED', 'INVOCATION_PARTIALLY_COMPLETED']:
        print("\n  ✓✓✓ INVOCATIONS COMPLETED! ✓✓✓")
        print("  Starting metrics computation...")
        run.compute_metrics(metrics=["coherence", "answer_relevance"])
        print("  ✓ Metrics computation triggered")
        
        # Wait for completion
        for i in range(6):
            time.sleep(5)
            current_status = run.get_status()
            print(f"    Status: {current_status}")
            if current_status.value == 'COMPLETED':
                break
    else:
        print(f"\n  ✗ Status is {status} - invocations did not complete")
    
    print("\n" + "=" * 70)
    print("RESULTS")
    print("=" * 70)
    print(f"""
Run: {run_config.run_name}
App: mock_business_agent v1.1_dataframe
Status: {status}

Check in Snowsight:
  AI & ML > Evaluations > mock_business_agent
    """)
    
    session.close()
    return run_config.run_name


if __name__ == "__main__":
    run_name = run_dataframe_evaluation()
    print(f"\nDone: {run_name}")
