"""
Mock Agent Evaluation - Proper instrumentation without explicit RECORD_ROOT
"""

import os
import time
import random
import pandas as pd

os.environ['TRULENS_OTEL_TRACING'] = '1'

from snowflake.snowpark import Session
from trulens.apps.custom import TruApp
from trulens.connectors.snowflake import SnowflakeConnector
from trulens.core.otel.instrument import instrument
from trulens.otel.semconv.trace import SpanAttributes
from trulens.core.app import RunConfig


class MockBusinessAgent:
    """Mock agent with proper instrumentation"""
    
    @instrument(span_type=SpanAttributes.SpanType.RETRIEVAL)
    def retrieve_context(self, query: str) -> list:
        """Simulate context retrieval"""
        time.sleep(random.uniform(0.1, 0.3))
        return [
            f"Context 1 for: {query}",
            f"Context 2 for: {query}"
        ]
    
    @instrument(span_type=SpanAttributes.SpanType.GENERATION)
    def generate_response(self, query: str, context: list) -> str:
        """Simulate LLM response generation"""
        time.sleep(random.uniform(0.2, 0.5))
        
        query_lower = query.lower()
        if 'revenue' in query_lower:
            return "Total revenue for Q4 2024 is $2.5M, up 15% from Q3."
        elif 'orders' in query_lower:
            return "1,234 orders were placed last month, averaging 40 per day."
        elif 'average' in query_lower:
            return "Average order value is $125.50 based on 1,234 orders."
        else:
            return f"Analysis complete for: {query}"
    
    @instrument()  # Let TruLens assign RECORD_ROOT automatically
    def answer_query(self, query: str) -> str:
        """Main entry point - orchestrates retrieval and generation"""
        context = self.retrieve_context(query)
        response = self.generate_response(query, context)
        return response


def run_evaluation(connection_name: str = "dash-builder-si"):
    """Execute evaluation with proper instrumentation"""
    
    print("=" * 70)
    print("PROPERLY INSTRUMENTED MOCK AGENT EVALUATION")
    print("=" * 70)
    
    # Connect
    print("\n[1/6] Connecting...")
    session = Session.builder.configs({"connection_name": connection_name}).create()
    session.sql("USE DATABASE SNOWFLAKE_INTELLIGENCE").collect()
    session.sql("USE SCHEMA AGENTS").collect()
    print(f"✓ Connected as {session.get_current_role()}")
    
    # Create connector
    print("\n[2/6] Creating connector...")
    connector = SnowflakeConnector(snowpark_session=session)
    print("✓ Connector ready")
    
    # Create app
    print("\n[3/6] Creating agent...")
    app = MockBusinessAgent()
    print("✓ Agent created")
    
    # Register app
    print("\n[4/6] Registering app...")
    tru_app = TruApp(
        app=app,
        main_method=app.answer_query,
        app_name="mock_business_agent",
        app_version="v2.0_proper_instrumentation",
        connector=connector
    )
    print("✓ Registered")
    
    # Create dataset
    print("\n[5/6] Creating dataset...")
    input_df = pd.DataFrame({
        'query': [
            'What is the total revenue for Q4 2024?',
            'How many orders were placed last month?',
            'What is the average order value?'
        ]
    })
    print(f"✓ Dataset with {len(input_df)} queries")
    
    # Create and start run
    print("\n[6/6] Creating evaluation run...")
    import datetime
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    
    run_config = RunConfig(
        run_name=f"proper_inst_{timestamp}",
        description="Evaluation with proper instrumentation (no explicit RECORD_ROOT)",
        label="proper",
        source_type="DATAFRAME",
        dataset_name="mock_proper_dataset",
        dataset_spec={
            "RECORD_ROOT.INPUT": "query"
        },
        llm_judge_name="llama3.1-70b"
    )
    
    run = tru_app.add_run(run_config=run_config)
    print(f"✓ Run: {run_config.run_name}")
    
    print("\n  Starting run...")
    start_time = time.time()
    try:
        run.start(input_df=input_df)
        elapsed = time.time() - start_time
        print(f"  ✓ run.start() completed ({elapsed:.1f}s)")
    except Exception as e:
        elapsed = time.time() - start_time
        print(f"  ✗ Failed ({elapsed:.1f}s): {str(e)[:200]}")
        raise
    
    # Check status
    time.sleep(3)
    status = run.get_status()
    print(f"\n  Status: {status}")
    
    # Compute metrics if successful
    if status.value in ['INVOCATION_COMPLETED', 'INVOCATION_PARTIALLY_COMPLETED']:
        print("\n  ✓✓✓ SUCCESS! Invocations completed!")
        print("  Computing metrics...")
        run.compute_metrics(metrics=["coherence", "answer_relevance"])
        print("  ✓ Metrics triggered")
        
        # Wait for computation
        print("\n  Monitoring computation...")
        for i in range(6):
            time.sleep(5)
            current = run.get_status()
            print(f"    [{i+1}/6] {current}")
            if current.value == 'COMPLETED':
                print("  ✓✓✓ METRICS COMPUTED!")
                break
    else:
        print(f"\n  ✗ Status: {status} - invocations incomplete")
    
    print("\n" + "=" * 70)
    print("RESULTS")
    print("=" * 70)
    print(f"""
Run: {run_config.run_name}
App: mock_business_agent v2.0_proper_instrumentation
Status: {status}

Snowsight: AI & ML > Evaluations > mock_business_agent
    """)
    
    session.close()
    return run_config.run_name


if __name__ == "__main__":
    run_name = run_evaluation()
    print(f"\nDone: {run_name}")
