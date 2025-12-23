"""
Quick Test - Minimal evaluation with just 2 queries
Tests business_insights_agent in ~30 seconds
"""

import os
import json
import requests
import urllib3
from snowflake.snowpark import Session

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

os.environ["TRULENS_OTEL_TRACING"] = "1"

def test_agent_simple():
    """Simple test without TruLens - just call the agent directly"""
    
    print("Connecting to Snowflake...")
    session = Session.builder.configs({
        "connection_name": "dash-builder-si"
    }).create()
    
    # Get auth token and account URL
    conn = session._conn._conn
    base_url = f"https://{conn.host}"
    auth_token = conn.rest.token
    
    print(f"✓ Connected as {session.get_current_role()}\n")
    
    # Create thread
    print("Creating conversation thread...")
    thread_response = requests.post(
        f"{base_url}/api/v2/cortex/threads",
        headers={
            'Authorization': f'Snowflake Token="{auth_token}"',
            'Content-Type': 'application/json'
        },
        json={'origin_application': 'quick_test'},
        verify=False
    )
    thread_response.raise_for_status()
    thread_id = thread_response.json()['thread_id']
    print(f"✓ Thread created: {thread_id}\n")
    
    # Test queries
    test_queries = [
        "What percentage of orders used discounts?",
        "What was the total revenue yesterday?"
    ]
    
    print("=" * 60)
    print("TESTING AGENT WITH 2 QUERIES")
    print("=" * 60)
    
    results = []
    
    for i, query in enumerate(test_queries, 1):
        print(f"\n[Query {i}/2] {query}")
        print("-" * 60)
        
        try:
            # Call agent with streaming
            response = requests.post(
                f"{base_url}/api/v2/databases/snowflake_intelligence/schemas/agents/agents/business_insights_agent:run",
                headers={
                    'Authorization': f'Snowflake Token="{auth_token}"',
                    'Content-Type': 'application/json'
                },
                json={
                    'thread_id': thread_id,
                    'parent_message_id': "0",
                    'messages': [{
                        'role': 'user',
                        'content': [{'type': 'text', 'text': query}]
                    }]
                },
                stream=True,
                timeout=90,
                verify=False
            )
            response.raise_for_status()
            
            # Parse streaming response (SSE)
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
            
            if answer:
                # Show first 200 chars of response
                preview = answer[:200] + "..." if len(answer) > 200 else answer
                print(f"Agent Response:\n{preview}\n")
                
                results.append({
                    'query': query,
                    'response': answer,
                    'status': 'success'
                })
            else:
                print(f"⚠️  No response from agent\n")
                results.append({
                    'query': query,
                    'response': "No response",
                    'status': 'no_response'
                })
                
        except requests.Timeout:
            print(f"❌ Request timeout (>90s)\n")
            results.append({
                'query': query,
                'response': "Timeout",
                'status': 'timeout'
            })
        except Exception as e:
            print(f"❌ Error: {type(e).__name__}: {e}\n")
            results.append({
                'query': query,
                'response': f"Error: {e}",
                'status': 'error'
            })
    
    print("=" * 60)
    print("RESULTS SUMMARY")
    print("=" * 60)
    
    success_count = sum(1 for r in results if r['status'] == 'success')
    print(f"\n✅ Successful: {success_count}/2")
    print(f"❌ Failed: {2 - success_count}/2")
    
    if success_count == 2:
        print("\n🎉 All queries successful!")
        print("   Your agent is responding correctly.")
        print("\nNext: Run full evaluation with 8 queries:")
        print("   python3.11 evaluate_cortex_agent.py")
    else:
        print("\n⚠️  Some queries failed.")
        print("   Check:")
        print("   1. Agent exists: snowflake_intelligence.agents.business_insights_agent")
        print("   2. You have USAGE privilege on the agent")
        print("   3. Dynamic tables have data")
    
    session.close()
    return results


if __name__ == "__main__":
    try:
        test_agent_simple()
    except Exception as e:
        print(f"\n❌ Test failed with error:")
        print(f"   {type(e).__name__}: {e}")
        print("\nTroubleshooting:")
        print("  1. Check connection: dash-builder-si")
        print("  2. Verify agent exists:")
        print("     SHOW AGENTS IN SCHEMA snowflake_intelligence.agents;")
        print("  3. Check privileges:")
        print("     SHOW GRANTS ON AGENT snowflake_intelligence.agents.business_insights_agent;")
        exit(1)
