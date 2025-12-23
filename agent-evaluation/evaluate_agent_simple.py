"""
Simplified Cortex Agent Evaluation using SQL-based invocation
Following the developer_workflow.txt guidance - keep it simple!
"""

import os
import time

# CRITICAL: Set before any TruLens imports
os.environ['TRULENS_OTEL_TRACING'] = '1'

from snowflake.snowpark import Session
from trulens.apps.custom import TruApp
from trulens.connectors.snowflake import SnowflakeConnector
from trulens.core.otel.instrument import instrument
from trulens.otel.semconv.trace import SpanAttributes
from trulens.core.app import RunConfig


class SimpleCortexAgent:
    """Simple wrapper that uses SQL to call Cortex Agent"""
    
    def __init__(self, session, agent_name: str):
        self.session = session
        self.agent_name = agent_name
    
    @instrument(
        span_type=SpanAttributes.SpanType.RECORD_ROOT,
        attributes={
            SpanAttributes.RECORD_ROOT.INPUT: "query",
            SpanAttributes.RECORD_ROOT.OUTPUT: "return",
        }
    )
    def answer_query(self, query: str) -> str:
        """Main entry point - queries agent via SQL"""
        # Use SQL to call the agent
        sql = f"""
        SELECT SNOWFLAKE.CORTEX.SEND_MESSAGE(
            {self.agent_name},
            '{query.replace("'", "''")}'
        ) as response
        """
        
        result = self.session.sql(sql).collect()
        if result and len(result) > 0:
            return result[0]['RESPONSE']
        return "No response"


def run_evaluation(connection_name: str = "dash-builder-si"):
    """Execute evaluation with simplified approach"""
    
    print("=" * 70)
    print("SIMPLIFIED CORTEX AGENT EVALUATION")
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
    
    # Step 3: Create app instance
    print("\n[3/7] Creating agent wrapper...")
    app = SimpleCortexAgent(
        session=session,
        agent_name="snowflake_intelligence.agents.business_insights_agent"
    )
    print("✓ Agent wrapper created")
    
    # Step 4: Register app
    print("\n[4/7] Registering with AI Observability...")
    tru_app = TruApp(
        app=app,
        main_method=app.answer_query,
        app_name="business_insights_agent",
        app_version="v3.0_simple",
        connector=connector
    )
    print("✓ App registered")
    
    # Step 5: Create test dataset table
    print("\n[5/7] Preparing evaluation dataset...")
    session.sql("""
        CREATE OR REPLACE TABLE EVAL_SIMPLE_QUERIES (
            USER_QUERY VARCHAR(500)
        )
    """).collect()
    
    session.sql("""
        INSERT INTO EVAL_SIMPLE_QUERIES (USER_QUERY)
        VALUES 
            ('What is the total revenue?'),
            ('How many orders were placed?'),
            ('What is the average order value?')
    """).collect()
    print("✓ Dataset created with 3 queries")
    
    # Step 6: Create and start run
    print("\n[6/7] Creating evaluation run...")
    import datetime
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    
    run_config = RunConfig(
        run_name=f"simple_eval_{timestamp}",
        description="Simplified evaluation using SQL invocation",
        label="simple",
        source_type="TABLE",
        dataset_name="SNOWFLAKE_INTELLIGENCE.AGENTS.EVAL_SIMPLE_QUERIES",
        dataset_spec={
            "RECORD_ROOT.INPUT": "USER_QUERY"  # MUST be uppercase to match table
        },
        llm_judge_name="llama3.1-70b"
    )
    
    run = tru_app.add_run(run_config=run_config)
    print(f"✓ Run created: {run_config.run_name}")
    
    # Start the run
    print("\n  Starting run (invoking agent for each query)...")
    start_time = time.time()
    try:
        run.start()
        elapsed = time.time() - start_time
        print(f"  ✓ run.start() completed ({elapsed:.1f}s)")
    except Exception as e:
        elapsed = time.time() - start_time
        print(f"  ✗ run.start() failed ({elapsed:.1f}s)")
        print(f"  Error: {str(e)[:300]}")
        raise
    
    # Check status
    time.sleep(3)
    status = run.get_status()
    print(f"\n  Run Status: {status}")
    
    # Step 7: Compute metrics if invocation completed
    print("\n[7/7] Computing metrics...")
    if status.value in ['INVOCATION_COMPLETED', 'INVOCATION_PARTIALLY_COMPLETED']:
        print("  Starting metrics computation...")
        run.compute_metrics(metrics=[
            "coherence",
            "answer_relevance"
        ])
        print("  ✓ Metrics computation triggered")
        
        # Wait and check final status
        time.sleep(5)
        final_status = run.get_status()
        print(f"  Final Status: {final_status}")
    else:
        print(f"  ⚠ Status is {status}, cannot compute metrics")
        print("  Check dataset and instrumentation")
    
    print("\n" + "=" * 70)
    print("RESULTS")
    print("=" * 70)
    print(f"""
Run Name: {run_config.run_name}
Status: {status}

Check Snowsight:
  AI & ML > Evaluations > business_insights_agent > {run_config.run_name}
    """)
    
    session.close()
    return run_config.run_name


if __name__ == "__main__":
    run_name = run_evaluation()
    print(f"\nCompleted: {run_name}")
