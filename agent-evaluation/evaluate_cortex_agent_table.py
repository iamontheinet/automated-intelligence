"""
Cortex Agent Evaluation - Using TABLE source instead of DATAFRAME
"""

import os
import time

# CRITICAL: Set TRULENS_OTEL_TRACING before any TruLens imports
os.environ['TRULENS_OTEL_TRACING'] = '1'

from snowflake.snowpark import Session
from trulens.apps.custom import TruApp
from trulens.connectors.snowflake import SnowflakeConnector
from trulens.core.otel.instrument import instrument
from trulens.otel.semconv.trace import SpanAttributes
from trulens.core.app import RunConfig
import requests
import json


class CortexAgentApp:
    """Wrapper for Cortex Agent with instrumentation"""
    
    def __init__(self, session, agent_config):
        self.session = session
        self.agent_name = agent_config['agent_name']
        self.database = agent_config['database']
        self.schema = agent_config['schema']
        account = session.get_current_account().strip('"')
        self.base_url = f"https://{account}.snowflakecomputing.com"
        self.auth_token = self._get_token()
    
    def _get_token(self) -> str:
        """Get auth token from session"""
        conn = self.session._conn._conn
        return conn.rest.token
    
    @instrument(
        span_type=SpanAttributes.SpanType.RECORD_ROOT,
        attributes={
            SpanAttributes.RECORD_ROOT.INPUT: "user_query",
            SpanAttributes.RECORD_ROOT.OUTPUT: "return",
        }
    )
    def answer_query(self, user_query: str) -> str:
        """Main entry point - queries the agent and returns response"""
        import urllib3
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
        
        # Correct endpoint: /api/v2/databases/{db}/schemas/{schema}/agents/{name}:run
        url = f"{self.base_url}/api/v2/databases/{self.database}/schemas/{self.schema}/agents/{self.agent_name}:run"
        headers = {
            'Authorization': f'Snowflake Token="{self.auth_token}"',
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        }
        payload = {
            'parent_message_id': '0',
            'messages': [
                {
                    'role': 'user',
                    'content': [
                        {
                            'type': 'text',
                            'text': user_query
                        }
                    ]
                }
            ]
        }
        
        response = requests.post(url, headers=headers, json=payload, stream=True, verify=False, timeout=90)
        response.raise_for_status()
        
        final_answer = []
        for line in response.iter_lines():
            if line:
                line = line.decode('utf-8')
                if line.startswith('data: '):
                    try:
                        data = json.loads(line[6:])
                        if data.get('event') == 'response.text.delta':
                            text = data.get('text', '')
                            final_answer.append(text)
                    except:
                        pass
        
        return ''.join(final_answer) if final_answer else "No response"


def run_table_evaluation(connection_name: str = "dash-builder-si"):
    """Execute AI Observability evaluation using TABLE source"""
    
    print("=" * 70)
    print("TABLE-BASED EVALUATION - business_insights_agent")
    print("=" * 70)
    
    # Connect to Snowflake
    print("\n[1/6] Connecting to Snowflake...")
    session = Session.builder.configs({
        "connection_name": connection_name
    }).create()
    print(f"✓ Connected as {session.get_current_role()}")
    
    # Setup location
    print("\n[2/6] Setting up storage location...")
    session.sql("USE DATABASE SNOWFLAKE_INTELLIGENCE").collect()
    session.sql("USE SCHEMA AGENTS").collect()
    print("✓ Using SNOWFLAKE_INTELLIGENCE.AGENTS")
    
    # Create connector
    print("\n[3/6] Creating SnowflakeConnector...")
    connector = SnowflakeConnector(snowpark_session=session)
    print("✓ Connector initialized")
    
    # Create app
    print("\n[4/6] Creating Cortex Agent application instance...")
    agent_config = {
        'agent_name': 'business_insights_agent',
        'database': 'snowflake_intelligence',
        'schema': 'agents'
    }
    test_app = CortexAgentApp(session, agent_config)
    print("✓ Agent app created")
    
    # Register app
    print("\n[5/6] Registering app with AI Observability...")
    tru_app = TruApp(
        app=test_app,
        main_method=test_app.answer_query,
        app_name="business_insights_agent",
        app_version="v2.1_table",
        connector=connector
    )
    print("✓ App registered")
    
    # Create run with TABLE source
    print("\n[6/6] Creating and executing run with TABLE source...")
    
    import datetime
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    
    run_config = RunConfig(
        run_name=f"eval_table_{timestamp}",
        description="Evaluation using TABLE source",
        label="table_test",
        source_type="TABLE",
        dataset_name="SNOWFLAKE_INTELLIGENCE.AGENTS.EVAL_TEST_QUERIES",
        dataset_spec={
            "RECORD_ROOT.INPUT": "USER_QUERY"  # Column name must be UPPERCASE
        },
        llm_judge_name="llama3.1-70b"
    )
    
    run = tru_app.add_run(run_config=run_config)
    print(f"✓ Run created: {run_config.run_name}")
    
    # Start the run
    print(f"\n  Starting run (this will read from table)...")
    start_time = time.time()
    try:
        run.start()  # No input_df needed for TABLE source
        elapsed = time.time() - start_time
        print(f"  ✓ run.start() completed ({elapsed:.1f}s)")
    except Exception as e:
        elapsed = time.time() - start_time
        print(f"  ✗ run.start() failed ({elapsed:.1f}s): {str(e)[:200]}")
        raise
    
    # Check status
    time.sleep(3)
    status = run.get_status()
    print(f"\n  Run Status: {status}")
    
    # Compute metrics
    if status.value in ['INVOCATION_COMPLETED', 'INVOCATION_PARTIALLY_COMPLETED']:
        print("\n  Computing metrics...")
        run.compute_metrics(metrics=[
            "coherence",
            "answer_relevance"
        ])
        print("  ✓ Metrics computation started")
    else:
        print(f"\n  ⚠ Status is {status}, cannot compute metrics yet")
    
    print("\n" + "=" * 70)
    print("RESULTS")
    print("=" * 70)
    print(f"""
Run Name: {run_config.run_name}
Status: {status}
Table: SNOWFLAKE_INTELLIGENCE.AGENTS.EVAL_TEST_QUERIES

Check Snowsight:
  AI & ML > Evaluations > business_insights_agent > {run_config.run_name}
    """)
    
    session.close()
    return run_config.run_name


if __name__ == "__main__":
    run_name = run_table_evaluation()
    print(f"\nRun completed: {run_name}")
