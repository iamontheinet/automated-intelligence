"""
Cortex Agent Evaluation - business_insights_agent
Evaluates the existing Snowflake Cortex Agent using AI Observability
"""

import os
import pandas as pd
import json
import requests
from snowflake.snowpark import Session
from trulens.core import TruSession, Select
from trulens.apps.custom import TruCustomApp
from trulens.connectors.snowflake import SnowflakeConnector
from trulens.providers.cortex.provider import Cortex
from trulens.core.feedback import Feedback
from trulens.core.instruments import instrument

os.environ["TRULENS_OTEL_TRACING"] = "1"


class CortexAgentWrapper:
    """
    Wrapper for Cortex Agent API calls to enable TruLens instrumentation
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
        # Use the actual host from connection (handles all account formats correctly)
        return f"https://{conn.host}"
    
    def _get_auth_token(self) -> str:
        """Get authentication token from session"""
        # Use Snowpark session's connection for auth
        # This uses the same PAT/credentials as the session
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
            'origin_application': 'ai_obs_eval'  # Max 16 bytes
        }
        
        response = requests.post(url, headers=headers, json=payload, verify=False, timeout=30)
        if response.status_code != 200:
            print(f"Thread creation failed: {response.status_code}")
            print(f"Response: {response.text}")
        response.raise_for_status()
        return response.json()['thread_id']
    
    @instrument
    def retrieve_context(self, query: str) -> list:
        """
        Simulate context retrieval for metrics
        In practice, this is done internally by Cortex Analyst
        """
        # This is a placeholder - actual context is retrieved by the agent
        return [f"Query: {query}"]
    
    @instrument
    def query_agent(self, user_input: str, parent_message_id: str = "0") -> dict:
        """
        Query the Cortex Agent via REST API (streaming)
        Returns full response with message content
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
            'parent_message_id': parent_message_id,
            'messages': [
                {
                    'role': 'user',
                    'content': [
                        {
                            'type': 'text',
                            'text': user_input
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
        
        return {
            'message_id': self.thread_id,
            'text': answer if answer else 'No response from agent',
            'raw_response': {'text': answer}
        }
    
    def __call__(self, input_text: str) -> str:
        """
        Main entry point for TruLens instrumentation
        """
        # Retrieve context (for metrics)
        contexts = self.retrieve_context(input_text)
        
        # Query agent
        response = self.query_agent(input_text)
        
        return response['text']


def create_evaluation_dataset() -> pd.DataFrame:
    """
    Create evaluation dataset for business_insights_agent
    Based on the agent's documented example questions
    """
    return pd.DataFrame({
        # Input prompts
        'RECORD_ROOT.INPUT': [
            "What's the distribution of order sizes (small, medium, large, extra large)?",
            "What percentage of orders used discounts?",
            "Compare revenue from discounted vs non-discounted orders"
        ],
        
        # Ground truth (expected insights - adjust based on your data)
        'RECORD_ROOT.GROUND_TRUTH_OUTPUT': [
            "Order size distribution shows: Small (X%), Medium (Y%), Large (Z%), Extra Large (W%)",
            "Approximately X% of orders used discount codes",
            "Discounted orders: $X revenue, Non-discounted: $Y revenue"
        ],
        
        # Query text for retrieval metrics
        'RETRIEVAL.QUERY_TEXT': [
            "order size distribution",
            "discount usage percentage",
            "discounted vs non-discounted revenue"
        ],
        
        # Unique identifiers
        'RECORD_ROOT.INPUT_ID': [
            'biz_query_001',
            'biz_query_002',
            'biz_query_003'
        ]
    })


def run_cortex_agent_evaluation(connection_name: str = "dash-builder-si"):
    """
    Execute AI Observability evaluation for business_insights_agent
    
    This evaluates the ACTUAL Cortex Agent deployed in Snowflake,
    not a custom Python RAG application.
    """
    
    print("=" * 70)
    print("CORTEX AGENT EVALUATION - business_insights_agent")
    print("=" * 70)
    
    print("\n[1/6] Connecting to Snowflake...")
    session = Session.builder.configs({
        "connection_name": connection_name
    }).create()
    print(f"✓ Connected as {session.get_current_role()}")
    
    print("\n[2/6] Configuring Cortex Agent wrapper...")
    agent_config = {
        'agent_name': 'business_insights_agent',
        'database': 'snowflake_intelligence',
        'schema': 'agents'
    }
    
    # Create agent wrapper BEFORE changing database context
    agent_wrapper = CortexAgentWrapper(session, agent_config)
    print(f"✓ Wrapped Cortex Agent: {agent_config['database']}.{agent_config['schema']}.{agent_config['agent_name']}")
    
    print("\n[3/6] Initializing AI Observability framework...")
    # Now set database/schema for TruLens storage
    print("  - Setting database to AUTOMATED_INTELLIGENCE...")
    session.sql("USE DATABASE AUTOMATED_INTELLIGENCE").collect()
    print("  - Setting schema to RAW...")
    session.sql("USE SCHEMA RAW").collect()
    
    print("  - Creating SnowflakeConnector...")
    connector = SnowflakeConnector(
        snowpark_session=session
    )
    print("  - Creating TruSession...")
    tru = TruSession(connector=connector)
    print("✓ TruLens initialized")
    
    print("\n[4/6] Loading evaluation dataset...")
    dataset = create_evaluation_dataset()
    print(f"✓ Loaded {len(dataset)} business insight queries")
    print("\nSample queries:")
    for i, query in enumerate(dataset['RECORD_ROOT.INPUT'].head(3), 1):
        print(f"  {i}. {query}")
    
    print("\n[5/6] Configuring evaluation metrics...")
    print("  - Creating Cortex provider...")
    
    # Disable SSL warnings for Cortex endpoint
    import urllib3
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    
    # Monkey patch requests to disable SSL verification
    import requests
    original_request = requests.Session.request
    def patched_request(self, *args, **kwargs):
        kwargs['verify'] = False
        return original_request(self, *args, **kwargs)
    requests.Session.request = patched_request
    
    cortex_provider = Cortex(
        snowpark_session=session,
        model_engine="llama3.1-70b"
    )
    
    print("  - Setting up feedback functions...")
    feedbacks = [
        # Question-Answer Relevance: Is the agent's response relevant to the question?
        Feedback(
            cortex_provider.qs_relevance,
            name="qs_relevance"
        ).on(
            prompt=Select.RecordInput,
            response=Select.RecordOutput
        ),
        
        # Coherence: Is the response well-structured?
        Feedback(
            cortex_provider.coherence,
            name="coherence"
        ).on(
            text=Select.RecordOutput
        ),
    ]
    print(f"✓ Configured {len(feedbacks)} evaluation metrics")
    
    # Register with TruLens for tracking
    print("  - Registering agent with TruLens...")
    tru_app = TruCustomApp(
        app=agent_wrapper,
        app_name="business_insights_agent",
        app_version="v1.0_cortex",
        feedbacks=feedbacks
    )
    print("✓ EXTERNAL AGENT 'business_insights_agent' registered for evaluation")
    
    print("\n[6/6] Executing evaluation run...")
    print("⚠️  This will make live API calls to business_insights_agent")
    print("    Each query will be processed by the agent...")
    print()
    
    # Process each query with the agent
    for i, row in dataset.iterrows():
        query = row['RECORD_ROOT.INPUT']
        print(f"  [{i+1}/{len(dataset)}] {query[:60]}...")
        
        try:
            with tru_app as recording:
                response = agent_wrapper(query)
            print(f"      ✓ Response received ({len(response)} chars)")
        except Exception as e:
            print(f"      ❌ Error: {e}")
    
    print("\n  - Evaluation complete, running feedback functions...")
    print("  - Waiting for feedback execution (this may take 1-2 minutes)...")
    
    # Wait for records to be written
    import time
    time.sleep(5)
    
    # Feedbacks should run automatically in background via TruLens
    # Just wait for them to complete
    print("  - Feedbacks are running in background...")
    
    # Get results from TruLens - will include feedback results when ready
    records_df = tru.get_leaderboard(app_ids=[tru_app.app_id])
    
    # Wait a bit more if feedbacks haven't completed
    max_wait = 60  # max 60 seconds
    waited = 0
    while waited < max_wait and ('qs_relevance' not in records_df.columns or records_df['qs_relevance'].isna().all()):
        print(f"  - Waiting for feedback results... ({waited}s)")
        time.sleep(10)
        waited += 10
        records_df = tru.get_leaderboard(app_ids=[tru_app.app_id])
    
    print("  - Feedback execution complete")
    
    print("\n" + "=" * 70)
    print("EVALUATION RESULTS")
    print("=" * 70)
    
    if len(records_df) > 0:
        print(f"""
    Agent: snowflake_intelligence.agents.business_insights_agent
    Records: {len(records_df)}
    """)
        
        # Check what columns are available
        print("Available columns:", list(records_df.columns))
        
        # Display metrics if available
        metric_columns = [col for col in records_df.columns if not col.startswith('_') and records_df[col].dtype in ['float64', 'int64']]
        
        if metric_columns:
            print("\nQuality Metrics (0-1 scale, higher is better):")
            print("-" * 48)
            for col in metric_columns:
                if records_df[col].notna().any():
                    print(f"    {col:20s} {records_df[col].mean():.3f} ± {records_df[col].std():.3f}")
        
        print("""
    View detailed results in Snowsight:
    → AI & ML > Evaluations > business_insights_agent
    """)
    
    print("\n" + "=" * 70)
    print("IMPROVEMENT RECOMMENDATIONS")
    print("=" * 70)
    
    # Analyze results and provide recommendations
    low_relevance = records_df[records_df['qs_relevance'] < 0.7] if 'qs_relevance' in records_df.columns else pd.DataFrame()
    low_coherence = records_df[records_df['coherence'] < 0.7] if 'coherence' in records_df.columns else pd.DataFrame()
    
    if len(low_relevance) > 0:
        print(f"\n⚠️  {len(low_relevance)} queries with low relevance (<0.7)")
        print("   Recommendation: Improve orchestration instructions")
        print("   → Make instructions more specific about expected answer format")
    
    if len(low_coherence) > 0:
        print(f"\n⚠️  {len(low_coherence)} queries with low coherence (<0.7)")
        print("   Recommendation: Improve response instructions")
        print("   → Add formatting guidelines (e.g., use bullet points)")
        print("   → Request structured output format")
    
    if len(low_relevance) == 0 and len(low_coherence) == 0:
        print("\n✅ All metrics above 0.7 threshold - Agent performing well!")
        print("   Next steps:")
        print("   → Deploy to production")
        print("   → Schedule regular evaluations")
        print("   → Monitor for data drift")
    
    print("\n" + "=" * 70)
    print("ITERATION WORKFLOW")
    print("=" * 70)
    print("""
    1. Review low-scoring queries in Snowsight (AI & ML > Evaluations)
    2. Update agent configuration:
       - Modify orchestration instructions
       - Adjust response formatting
       - Update semantic view if data mappings are incorrect
    3. Re-run evaluation:
       python evaluate_cortex_agent.py
    4. Compare runs side-by-side in Snowsight
    5. Deploy improved version if metrics increase by >10%
    """)
    
    session.close()
    return records_df


if __name__ == "__main__":
    run_cortex_agent_evaluation()
