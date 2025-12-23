"""
Super Simple Test - No TruLens, No Complex Setup
Just tests if business_insights_agent responds
"""

import sys
import urllib3
import json

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

def check_imports():
    """Check if required packages are available"""
    missing = []
    
    try:
        import snowflake.snowpark
    except ImportError:
        missing.append("snowflake-snowpark-python")
    
    try:
        import requests
    except ImportError:
        missing.append("requests")
    
    if missing:
        print(f"❌ Missing packages: {', '.join(missing)}")
        print("\nInstall with:")
        print(f"   pip install {' '.join(missing)}")
        sys.exit(1)

check_imports()

from snowflake.snowpark import Session
import requests

def test_agent():
    """Test business_insights_agent with 2 simple queries"""
    
    print("\n" + "="*60)
    print("CONNECTING TO SNOWFLAKE")
    print("="*60)
    
    try:
        session = Session.builder.configs({
            "connection_name": "dash-builder-si"
        }).create()
        print(f"✓ Connected as: {session.get_current_role()}")
    except Exception as e:
        print(f"❌ Connection failed: {e}")
        print("\nCheck:")
        print("  1. Connection 'dash-builder-si' exists")
        print("  2. Run: snow connection test dash-builder-si")
        sys.exit(1)
    
    conn = session._conn._conn
    base_url = f"https://{conn.host}"
    auth_token = conn.rest.token
    
    print("\n" + "="*60)
    print("CREATING CONVERSATION THREAD")
    print("="*60)
    
    try:
        thread_response = requests.post(
            f"{base_url}/api/v2/cortex/threads",
            headers={
                'Authorization': f'Snowflake Token="{auth_token}"',
                'Content-Type': 'application/json'
            },
            json={'origin_application': 'simple_test'},
            timeout=30,
            verify=False
        )
        thread_response.raise_for_status()
        thread_id = thread_response.json()['thread_id']
        print(f"✓ Thread ID: {thread_id}")
    except Exception as e:
        print(f"❌ Failed to create thread: {e}")
        sys.exit(1)
    
    test_queries = [
        "What percentage of orders used discounts?",
        "What was the total revenue yesterday?"
    ]
    
    print("\n" + "="*60)
    print("TESTING AGENT (2 QUERIES)")
    print("="*60)
    
    results = []
    
    for i, query in enumerate(test_queries, 1):
        print(f"\n[Query {i}/2]")
        print(f"Question: {query}")
        print("-"*60)
        
        try:
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
            
            if response.status_code == 200:
                agent_text = []
                final_answer = []
                in_final_answer = False
                
                for line in response.iter_lines():
                    if line:
                        line = line.decode('utf-8')
                        if line.startswith('data: '):
                            try:
                                data = json.loads(line[6:])
                                
                                if data.get('event') == 'response.text.delta':
                                    text = data.get('text', '')
                                    final_answer.append(text)
                                    in_final_answer = True
                                elif 'text' in data and not in_final_answer:
                                    agent_text.append(data['text'])
                            except:
                                pass
                
                answer = ''.join(final_answer) if final_answer else ''.join(agent_text)
                
                if answer:
                    print(f"Response: {answer}")
                    results.append({'query': query, 'status': 'success'})
                else:
                    print("⚠️  No text response from agent")
                    results.append({'query': query, 'status': 'no_response'})
                    
            else:
                print(f"❌ HTTP Error {response.status_code}")
                print(f"   {response.text[:200]}")
                results.append({'query': query, 'status': 'failed'})
                
        except requests.Timeout:
            print("❌ Request timeout (>90s)")
            results.append({'query': query, 'status': 'timeout'})
        except Exception as e:
            print(f"❌ Error: {type(e).__name__}: {e}")
            results.append({'query': query, 'status': 'error'})
    
    print("\n" + "="*60)
    print("RESULTS SUMMARY")
    print("="*60)
    
    success = sum(1 for r in results if r['status'] == 'success')
    failed = len(results) - success
    
    print(f"\n✅ Successful: {success}/2")
    print(f"❌ Failed: {failed}/2")
    
    if success == 2:
        print("\n🎉 SUCCESS! Your agent is working correctly.")
        print("\nNext steps:")
        print("  1. View agent in Snowsight:")
        print("     AI & ML > Snowflake Intelligence > business_insights_agent")
        print("")
        print("  2. Run full evaluation with quality metrics:")
        print("     python3.11 evaluate_cortex_agent.py")
    elif success > 0:
        print("\n⚠️  Partial success - some queries failed")
        print("   Review errors above for details")
    else:
        print("\n❌ All queries failed")
        print("\nTroubleshooting:")
        print("  1. Check agent exists in Snowsight")
        print("  2. Verify USAGE privilege on agent")
    
    session.close()
    return success == 2


if __name__ == "__main__":
    try:
        success = test_agent()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\n\n⚠️  Test interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Unexpected error: {type(e).__name__}: {e}")
        sys.exit(1)
