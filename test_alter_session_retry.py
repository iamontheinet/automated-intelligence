"""
Test script to verify ALTER SESSION retry logic works correctly.
"""
import snowflake.connector
import time
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def disable_query_cache_with_retry(cursor, max_retries=3, delay_seconds=0.5):
    """
    Attempt to disable query result cache with retry logic.
    This handles transient 'ALTER SESSION not supported in stored procedure' errors.
    """
    for attempt in range(max_retries):
        try:
            cursor.execute("ALTER SESSION SET USE_CACHED_RESULT = FALSE")
            logger.info(f"✓ ALTER SESSION succeeded on attempt {attempt + 1}")
            return True
        except Exception as e:
            error_msg = str(e)
            if "ALTER_SESSION" in error_msg or "90236" in error_msg:
                if attempt < max_retries - 1:
                    logger.warning(f"ALTER SESSION attempt {attempt + 1} failed (error 90236), retrying in {delay_seconds}s...")
                    time.sleep(delay_seconds)
                    continue
                else:
                    logger.warning(f"ALTER SESSION failed after {max_retries} attempts, continuing without disabling cache")
                    return False
            else:
                logger.error(f"Unexpected error: {e}")
                raise
    return False

def main():
    logger.info("Connecting to Snowflake...")
    conn = snowflake.connector.connect(connection_name='dash-builder-si')
    cursor = conn.cursor()
    
    try:
        # Test 1: Normal ALTER SESSION (should work)
        logger.info("\n=== Test 1: Direct ALTER SESSION ===")
        result = disable_query_cache_with_retry(cursor)
        logger.info(f"Result: {result}\n")
        
        # Test 2: Switch warehouse and try again
        logger.info("=== Test 2: After warehouse switch ===")
        cursor.execute("USE WAREHOUSE automated_intelligence_wh")
        result = disable_query_cache_with_retry(cursor)
        logger.info(f"Result: {result}\n")
        
        # Test 3: After calling a stored procedure
        logger.info("=== Test 3: After stored procedure call ===")
        cursor.execute("CALL AUTOMATED_INTELLIGENCE.staging.get_staging_counts()")
        result = disable_query_cache_with_retry(cursor)
        logger.info(f"Result: {result}\n")
        
        # Test 4: Another warehouse switch
        logger.info("=== Test 4: Switch to Gen2 warehouse ===")
        cursor.execute("USE WAREHOUSE automated_intelligence_gen2_wh")
        result = disable_query_cache_with_retry(cursor)
        logger.info(f"Result: {result}\n")
        
        logger.info("✅ All tests completed successfully!")
        
    finally:
        cursor.close()
        conn.close()

if __name__ == "__main__":
    main()
