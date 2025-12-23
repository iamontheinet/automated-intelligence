"""
Agent Evaluation Framework for Automated Intelligence
Evaluates RAG-based analytics on streaming order data using AI Observability
"""

import os
import pandas as pd
from snowflake.snowpark import Session
from trulens.core import TruSession
from trulens.apps.basic import TruBasicApp
from trulens.connectors.snowflake import SnowflakeConnector
from trulens.providers.cortex.provider import Cortex
from trulens.core.feedback import Feedback

os.environ["TRULENS_OTEL_TRACING"] = "1"


class OrderAnalyticsRAG:
    """
    RAG application for querying order analytics
    Combines data retrieval + LLM generation for insights
    """
    
    def __init__(self, session: Session, config: dict):
        self.session = session
        self.database = config.get('database', 'AUTOMATED_INTELLIGENCE')
        self.schema = config.get('schema', 'DYNAMIC_TABLES')
        
    def retrieve_order_context(self, query: str) -> list:
        """
        Retrieve relevant order data using SQL queries
        In production, this would use Cortex Search service
        """
        sql = f"""
        SELECT 
            ORDER_DATE,
            CUSTOMER_ID,
            ORDER_TOTAL,
            ORDER_STATUS
        FROM {self.database}.{self.schema}.FACT_ORDERS
        WHERE ORDER_DATE >= DATEADD(day, -30, CURRENT_DATE())
        ORDER BY ORDER_DATE DESC
        LIMIT 100
        """
        
        try:
            results = self.session.sql(sql).collect()
            contexts = [str(row.as_dict()) for row in results]
            return contexts
        except Exception as e:
            print(f"Warning: Context retrieval failed: {e}")
            return []
    
    def generate_answer(self, query: str, contexts: list) -> str:
        """Generate answer using Cortex Complete LLM"""
        context_text = "\n".join(contexts[:5])
        
        prompt = f"""You are an order analytics assistant. Answer the question based on the provided order data.

Order Data Context:
{context_text}

Question: {query}

Provide a concise, data-driven answer."""
        
        try:
            result = self.session.sql(f"""
                SELECT SNOWFLAKE.CORTEX.COMPLETE(
                    'llama3.1-70b',
                    '{prompt.replace("'", "''")}'
                ) as answer
            """).collect()
            
            return result[0]['ANSWER'] if result else "Unable to generate answer"
        except Exception as e:
            return f"Error generating answer: {e}"
    
    def __call__(self, input_text: str) -> str:
        """Main RAG pipeline - called by TruLens instrumentation"""
        contexts = self.retrieve_order_context(input_text)
        answer = self.generate_answer(input_text, contexts)
        return answer


def create_evaluation_dataset() -> pd.DataFrame:
    """
    Create evaluation dataset with test queries
    Maps to AI Observability required attributes
    """
    return pd.DataFrame({
        'RECORD_ROOT.INPUT': [
            'What is the total revenue from orders in the last 30 days?',
            'How many orders were placed yesterday?',
            'What is the average order value this week?',
            'Which customer has the highest total order value?',
            'What is the order completion rate for the last quarter?'
        ],
        
        'RECORD_ROOT.GROUND_TRUTH_OUTPUT': [
            'Total revenue in the last 30 days is $1,234,567.89',
            '2,345 orders were placed yesterday',
            'Average order value this week is $156.78',
            'Customer ID 10543 has the highest total at $45,678.90',
            'Order completion rate for Q4 is 94.2%'
        ],
        
        'RETRIEVAL.QUERY_TEXT': [
            'revenue 30 days',
            'orders yesterday count',
            'average order value week',
            'top customer order value',
            'completion rate quarter'
        ],
        
        'RECORD_ROOT.INPUT_ID': [
            'query_001',
            'query_002', 
            'query_003',
            'query_004',
            'query_005'
        ]
    })


def setup_evaluation_privileges(session: Session):
    """
    Setup required privileges for AI Observability
    Must be run by ACCOUNTADMIN or role with grant privileges
    """
    setup_sql = """
    GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER 
        TO ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;
    
    GRANT APPLICATION ROLE SNOWFLAKE.AI_OBSERVABILITY_EVENTS_LOOKUP 
        TO ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;
    
    GRANT CREATE EXTERNAL AGENT ON SCHEMA AUTOMATED_INTELLIGENCE.RAW 
        TO ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;
    
    GRANT CREATE TASK ON SCHEMA AUTOMATED_INTELLIGENCE.RAW 
        TO ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;
    
    GRANT EXECUTE TASK ON ACCOUNT 
        TO ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;
    """
    
    try:
        for statement in setup_sql.split(';'):
            if statement.strip():
                session.sql(statement).collect()
        print("✓ Privileges granted successfully")
    except Exception as e:
        print(f"⚠ Privilege setup failed (may need ACCOUNTADMIN): {e}")


def run_evaluation(connection_name: str = "dash-builder-si"):
    """
    Execute AI Observability evaluation run
    
    This will:
    1. Connect to Snowflake
    2. Register EXTERNAL AGENT automatically via TruLens
    3. Create instrumented RAG app
    4. Run evaluation with LLM-as-judge metrics
    5. Store results in SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS
    """
    
    print("=" * 60)
    print("AI OBSERVABILITY EVALUATION - Order Analytics RAG")
    print("=" * 60)
    
    print("\n[1/6] Connecting to Snowflake...")
    session = Session.builder.configs({
        "connection_name": connection_name
    }).create()
    print(f"✓ Connected as {session.get_current_role()}")
    
    print("\n[2/6] Initializing AI Observability framework...")
    connector = SnowflakeConnector(
        snowpark_session=session,
        database_name="AUTOMATED_INTELLIGENCE",
        schema_name="RAW"
    )
    tru = TruSession(connector=connector)
    print("✓ TruLens initialized")
    
    print("\n[3/6] Creating Order Analytics RAG application...")
    config = {
        'database': 'AUTOMATED_INTELLIGENCE',
        'schema': 'DYNAMIC_TABLES'
    }
    rag_app = OrderAnalyticsRAG(session, config)
    
    tru_app = TruBasicApp(
        app=rag_app,
        app_name="order_analytics_rag",
        app_version="v1.0_baseline"
    )
    print("✓ EXTERNAL AGENT 'order_analytics_rag' registered")
    
    print("\n[4/6] Loading evaluation dataset...")
    dataset = create_evaluation_dataset()
    print(f"✓ Loaded {len(dataset)} test queries")
    
    print("\n[5/6] Configuring evaluation metrics...")
    cortex_provider = Cortex(
        snowpark_session=session,
        model_engine="llama3.1-70b"
    )
    
    feedbacks = [
        Feedback(
            cortex_provider.context_relevance,
            name="context_relevance"
        ).on(input="RETRIEVAL.QUERY_TEXT")
         .on(output="RETRIEVAL.RETRIEVED_CONTEXTS"),
        
        Feedback(
            cortex_provider.groundedness,
            name="groundedness"
        ).on(output="RECORD_ROOT.OUTPUT")
         .on(context="RETRIEVAL.RETRIEVED_CONTEXTS"),
        
        Feedback(
            cortex_provider.answer_relevance,
            name="answer_relevance"
        ).on(input="RECORD_ROOT.INPUT")
         .on(output="RECORD_ROOT.OUTPUT"),
        
        Feedback(
            cortex_provider.correctness,
            name="correctness"
        ).on(input="RECORD_ROOT.INPUT")
         .on(output="RECORD_ROOT.OUTPUT")
         .on(ground_truth="RECORD_ROOT.GROUND_TRUTH_OUTPUT"),
    ]
    print(f"✓ Configured {len(feedbacks)} evaluation metrics")
    
    print("\n[6/6] Executing evaluation run...")
    run = tru.create_run(
        app=tru_app,
        dataset=dataset,
        run_name="baseline_evaluation_run",
        run_description="Baseline evaluation of order analytics RAG v1.0",
        labels=["baseline", "v1.0", "order-analytics"],
        feedbacks=feedbacks
    )
    
    print(f"✓ Run created: {run.run_id}")
    print("  - Starting invocation phase...")
    run.start()
    
    print("  - Waiting for completion...")
    run.wait_for_completion()
    
    print("\n" + "=" * 60)
    print("EVALUATION RESULTS")
    print("=" * 60)
    
    results = run.get_results()
    print(f"""
    Run ID: {run.run_id}
    Status: {run.status}
    
    Quality Metrics (0-1 scale, higher is better):
    ------------------------------------------------
    Context Relevance:  {results['context_relevance'].mean():.3f} ± {results['context_relevance'].std():.3f}
    Groundedness:       {results['groundedness'].mean():.3f} ± {results['groundedness'].std():.3f}
    Answer Relevance:   {results['answer_relevance'].mean():.3f} ± {results['answer_relevance'].std():.3f}
    Correctness:        {results['correctness'].mean():.3f} ± {results['correctness'].std():.3f}
    
    Performance Metrics:
    ------------------------------------------------
    Avg Latency:        {results['latency_ms'].mean():.0f} ms
    Total Cost:         ${results['cost_usd'].sum():.4f}
    
    View detailed results in Snowsight:
    AI & ML > Evaluations > order_analytics_rag
    """)
    
    print("\n" + "=" * 60)
    print("DATA STORAGE")
    print("=" * 60)
    print("""
    All traces and metrics stored in:
    Database: SNOWFLAKE
    Schema:   LOCAL
    Table:    AI_OBSERVABILITY_EVENTS
    
    Query traces with:
    SELECT * FROM SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS
    WHERE APPLICATION_NAME = 'order_analytics_rag'
    ORDER BY TIMESTAMP DESC;
    """)
    
    session.close()
    return run


if __name__ == "__main__":
    run_evaluation()
