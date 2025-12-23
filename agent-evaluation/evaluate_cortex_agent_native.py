"""
Cortex Agent Evaluation - Native Snowflake AI Observability
Evaluates the business_insights_agent using native Snowflake AI Observability
"""

import os
import pandas as pd
import json
import requests
import time

# CRITICAL: Set TRULENS_OTEL_TRACING before any TruLens imports
os.environ['TRULENS_OTEL_TRACING'] = '1'

from snowflake.snowpark import Session
from trulens.apps.custom import TruApp
from trulens.connectors.snowflake import SnowflakeConnector
from trulens.core.otel.instrument import instrument
from trulens.otel.semconv.trace import SpanAttributes
from trulens.core.app import RunConfig

# Enable OTEL tracing
os.environ["TRULENS_OTEL_TRACING"] = "1"


class CortexAgentApp:
    """
    Wrapper for Cortex Agent API calls with proper OTEL instrumentation
    """
    
    def __init__(self, session: Session, agent_config: dict):
        self.session = session
        self.agent_name = agent_config['agent_name']
        self.database = agent_config['database']
        self.schema = agent_config['schema']
        self.base_url = self._get_account_url()
        self.auth_token = self._get_auth_token()
        # Create thread once during initialization
        self.thread_id = self._create_thread()
        
    def _get_account_url(self) -> str:
        """Get Snowflake account URL from session"""
        conn = self.session._conn._conn
        return f"https://{conn.host}"
    
    def _get_auth_token(self) -> str:
        """Get authentication token from session"""
        conn = self.session._conn._conn
        return conn.rest.token
    
    def _create_thread(self) -> str:
        """Create a conversation thread"""
        import urllib3
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
        
        url = f"{self.base_url}/api/v2/cortex/threads"
        headers = {
            'Authorization': f'Snowflake Token="{self.auth_token}"',
            'Content-Type': 'application/json'
        }
        payload = {
            'origin_application': 'ai_obs_eval'
        }
        
        response = requests.post(url, headers=headers, json=payload, verify=False, timeout=30)
        response.raise_for_status()
        return response.json()['thread_id']
    
    @instrument(
        span_type=SpanAttributes.SpanType.RECORD_ROOT,
        attributes={
            SpanAttributes.RECORD_ROOT.INPUT: "user_query",
            SpanAttributes.RECORD_ROOT.OUTPUT: "return",
        }
    )
    def answer_query(self, user_query: str) -> str:
        """
        Main entry point - queries the agent and returns response
        """
        import urllib3
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
        
        url = f"{self.base_url}/api/v2/databases/{self.database}/schemas/{self.schema}/agents/{self.agent_name}:run"
        headers = {
            'Authorization': f'Snowflake Token="{self.auth_token}"',
            'Content-Type': 'application/json'
        }
        payload = {
            'thread_id': self.thread_id,
            'parent_message_id': "0",
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
        
        agent_text = []
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
                        elif 'text' in data:
                            agent_text.append(data['text'])
                    except:
                        pass
        
        answer = ''.join(final_answer) if final_answer else ''.join(agent_text)
        return answer if answer else 'No response from agent'


def create_evaluation_dataset() -> pd.DataFrame:
    """
    Create evaluation dataset for business_insights_agent
    """
    return pd.DataFrame({
        'user_query': [  # Column name must match method parameter name
            "What's the distribution of order sizes (small, medium, large, extra large)?",
            "What percentage of orders used discounts?",
            "Compare revenue from discounted vs non-discounted orders"
        ]
    })


def run_native_evaluation(connection_name: str = "dash-builder-si"):
    """
    Execute AI Observability evaluation using native Snowflake approach
    """
    
    print("=" * 70)
    print("NATIVE SNOWFLAKE AI OBSERVABILITY - business_insights_agent")
    print("=" * 70)
    
    print("\n[1/7] Connecting to Snowflake...")
    session = Session.builder.configs({
        "connection_name": connection_name
    }).create()
    print(f"✓ Connected as {session.get_current_role()}")
    
    print("\n[2/7] Setting up storage location...")
    session.sql("USE DATABASE SNOWFLAKE_INTELLIGENCE").collect()
    session.sql("USE SCHEMA AGENTS").collect()
    print("✓ Using SNOWFLAKE_INTELLIGENCE.AGENTS")
    
    print("\n[3/7] Creating SnowflakeConnector...")
    connector = SnowflakeConnector(snowpark_session=session)
    print("✓ Connector initialized")
    
    print("\n[4/7] Creating Cortex Agent application instance...")
    agent_config = {
        'agent_name': 'business_insights_agent',
        'database': 'snowflake_intelligence',
        'schema': 'agents'
    }
    test_app = CortexAgentApp(session, agent_config)
    print("✓ Agent app created")
    
    print("\n[5/7] Registering app with AI Observability...")
    tru_app = TruApp(
        app=test_app,
        main_method=test_app.answer_query,
        app_name="business_insights_agent",
        app_version="v2.0_native",
        connector=connector
    )
    print("✓ App registered - EXTERNAL AGENT will be created on first run")
    
    print("\n[6/7] Creating and configuring run...")
    
    # Create dataset
    input_df = create_evaluation_dataset()
    print(f"✓ Dataset created with {len(input_df)} queries")
    
    import datetime
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    
    run_config = RunConfig(
        run_name=f"eval_run_{timestamp}",
        description="Initial evaluation of business insights agent",
        label="baseline",
        source_type="DATAFRAME",
        dataset_name="business_queries_dataset",
        dataset_spec={
            "RECORD_ROOT.INPUT": "user_query"  # Must match dataframe column name
        },
        llm_judge_name="llama3.1-70b"
    )
    
    run = tru_app.add_run(run_config=run_config)
    print("✓ Run created")
    print(f"  Run name: {run_config.run_name}")
    print(f"  LLM Judge: {run_config.llm_judge_name}")
    
    print("\n[7/7] Executing run...")
    print("  - Invoking agent for each query...")
    print("  - This will take 1-2 minutes...")
    
    print(f"\n  DEBUG: Input DataFrame columns: {input_df.columns.tolist()}")
    print(f"  DEBUG: Input DataFrame shape: {input_df.shape}")
    print(f"  DEBUG: First row: {input_df.iloc[0].to_dict()}")
    
    # run.start() will automatically invoke test_app.answer_query for each row
    import time as time_mod
    start_time = time_mod.time()
    try:
        print(f"  DEBUG: Calling run.start()...")
        run.start(input_df=input_df)
        elapsed = time_mod.time() - start_time
        print(f"\n  DEBUG: run.start() completed without exception (took {elapsed:.1f}s)")
    except Exception as e:
        elapsed = time_mod.time() - start_time
        print(f"\n  DEBUG: run.start() raised exception after {elapsed:.1f}s: {type(e).__name__}: {str(e)[:300]}")
    print("\n✓ Invocation complete!")
    print(f"  Status: {run.get_status()}")
    
    print("\n  - Computing evaluation metrics...")
    run.compute_metrics(metrics=[
        "coherence",
        "answer_relevance"
    ])
    
    print("✓ Metrics computation started (runs asynchronously)")
    
    print("\n" + "=" * 70)
    print("EVALUATION COMPLETE")
    print("=" * 70)
    print(f"""
App: {agent_config['database']}.{agent_config['schema']}.{agent_config['agent_name']}
Run: {run_config.run_name}
Queries: {len(input_df)}
Metrics: coherence, answer_relevance

VIEW RESULTS IN SNOWSIGHT:
1. Navigate to Snowsight
2. Go to AI & ML > Evaluations
3. Select 'business_insights_agent'
4. Select run '{run_config.run_name}'
5. View aggregated metrics and individual traces

Note: Metric computation runs asynchronously. Results will appear 
in Snowsight within 1-2 minutes.
    """)
    
    session.close()
    return run


if __name__ == "__main__":
    run_native_evaluation()
