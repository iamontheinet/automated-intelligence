import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from shared import get_session, show_header

show_header()
st.subheader("🏥 System Health")
st.divider()

session = get_session()

with st.expander("ℹ️ About System Health", expanded=False):
    st.markdown("""
    **What is System Health?**
    
    System Health provides operational monitoring of your Snowflake environment, complementing business metrics 
    with query performance, warehouse efficiency, and table-level insights.
    
    **Metrics Tracked:**
    - 📊 **Query Health**: Failures, retries, overload, blocking
    - 🏭 **Warehouse Performance**: Throughput, duration, spillage, errors
    - 📋 **Table Activity**: Most queried tables, failures, blocked queries
    
    **Data Source:**
    - Uses `SNOWFLAKE.ACCOUNT_USAGE` views (45-min to 3-hour latency)
    - Best for trend analysis and historical patterns
    
    **Purpose:**
    - Proactive monitoring of system health
    - Identify performance bottlenecks before users complain
    - Optimize warehouse sizing and query efficiency
    - Complement business intelligence with operational insights
    """)

days_filter = st.slider("Show data for last N days", 1, 30, 7, key="system_health_days")
st.info(f"📅 Showing data for the last **{days_filter} days**")

st.divider()

try:
    access_test_query = """
    SELECT COUNT(*) as query_count 
    FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY 
    WHERE START_TIME >= DATEADD('day', -1, CURRENT_TIMESTAMP())
    LIMIT 1
    """
    
    test_result = session.sql(access_test_query).collect()
    has_access = True
    
except Exception as e:
    has_access = False
    error_msg = str(e)

if not has_access:
    st.error("❌ **Access Required**: Cannot access SNOWFLAKE.ACCOUNT_USAGE views")
    
    st.markdown("""
    ### 🔐 Required Permissions
    
    To enable System Health monitoring, an **ACCOUNTADMIN** must grant the following:
    
    ```sql
    USE ROLE ACCOUNTADMIN;
    
    -- Grant access to SNOWFLAKE database (contains ACCOUNT_USAGE schema)
    GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE 
        TO ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;
    
    -- Verify access
    USE ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;
    SELECT COUNT(*) FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY LIMIT 1;
    ```
    
    ### 📋 What These Permissions Enable:
    - Query health metrics (failures, retries, overload, blocking)
    - Warehouse performance tracking (throughput, spillage, errors)
    - Table activity monitoring (most queried, failures, blocked queries)
    - Cost optimization insights (warehouse efficiency, query patterns)
    
    ### ⚠️ Important Notes:
    - `ACCOUNT_USAGE` views have 45-minute to 3-hour latency (not real-time)
    - Data is read-only and cannot be modified
    - Only queries for `AUTOMATED_INTELLIGENCE` database will be shown
    
    **Contact your Snowflake administrator to grant these permissions.**
    """)
    
    st.divider()
    
    with st.expander("🔍 Troubleshooting Access Issues"):
        st.markdown(f"""
        **Error Details:**
        ```
        {error_msg}
        ```
        
        **Common Issues:**
        1. **Missing IMPORTED PRIVILEGES**: Most common issue - run the GRANT command above
        2. **Wrong Role**: Ensure you're using a role with ACCOUNTADMIN or IMPORTED PRIVILEGES
        3. **Network Issues**: Check Snowflake connection status
        
        **Verification Steps:**
        ```sql
        -- Check current role
        SELECT CURRENT_ROLE();
        
        -- Check grants to role
        SHOW GRANTS TO ROLE SNOWFLAKE_INTELLIGENCE_ADMIN;
        
        -- Test direct query
        SELECT COUNT(*) FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY LIMIT 1;
        ```
        """)
    
    st.stop()

st.markdown("### 📊 Query Health Overview")
st.caption("Monitor overall query success rates and performance issues")

query_health_query = f"""
WITH hourly_stats AS (
    SELECT 
        DATE_TRUNC('hour', START_TIME) as hour,
        COUNT(*) as total_queries,
        SUM(CASE WHEN EXECUTION_STATUS = 'FAIL' THEN 1 ELSE 0 END) as failed_queries,
        SUM(CASE WHEN IS_CLIENT_GENERATED_STATEMENT = FALSE 
                 AND QUERY_TYPE != 'UNKNOWN' 
                 AND QUERY_ID IN (
                     SELECT QUERY_ID 
                     FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY qh2
                     WHERE qh2.START_TIME = QUERY_HISTORY.START_TIME
                       AND qh2.QUERY_ID != QUERY_HISTORY.QUERY_ID
                 )
            THEN 1 ELSE 0 END) as retried_queries,
        AVG(
            CASE WHEN TOTAL_ELAPSED_TIME > 0 
            THEN (QUEUED_OVERLOAD_TIME::FLOAT / TOTAL_ELAPSED_TIME) * 100 
            ELSE 0 END
        ) as avg_overload_pct,
        AVG(
            CASE WHEN TOTAL_ELAPSED_TIME > 0 
            THEN (TRANSACTION_BLOCKED_TIME::FLOAT / TOTAL_ELAPSED_TIME) * 100 
            ELSE 0 END
        ) as avg_blocked_pct
    FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
    WHERE START_TIME >= DATEADD('day', -{days_filter}, CURRENT_TIMESTAMP())
        AND DATABASE_NAME = 'AUTOMATED_INTELLIGENCE'
    GROUP BY DATE_TRUNC('hour', START_TIME)
)
SELECT 
    hour,
    total_queries,
    ROUND((failed_queries::FLOAT / NULLIF(total_queries, 0)) * 1000, 2) as failures_per_1k,
    ROUND((retried_queries::FLOAT / NULLIF(total_queries, 0)) * 1000, 2) as retries_per_1k,
    ROUND(avg_overload_pct, 2) as overload_pct,
    ROUND(avg_blocked_pct, 2) as blocked_pct
FROM hourly_stats
ORDER BY hour
"""

try:
    health_df = session.sql(query_health_query).to_pandas()
    
    if not health_df.empty:
        col1, col2, col3, col4 = st.columns(4)
        
        avg_failures = health_df['FAILURES_PER_1K'].mean()
        avg_retries = health_df['RETRIES_PER_1K'].mean()
        avg_overload = health_df['OVERLOAD_PCT'].mean()
        avg_blocked = health_df['BLOCKED_PCT'].mean()
        
        with col1:
            failure_color = "🟢" if avg_failures < 5 else "🟡" if avg_failures < 20 else "🔴"
            st.metric(f"{failure_color} Query Failures/1K", f"{avg_failures:.1f}")
        
        with col2:
            retry_color = "🟢" if avg_retries < 5 else "🟡" if avg_retries < 20 else "🔴"
            st.metric(f"{retry_color} Query Retries/1K", f"{avg_retries:.1f}")
        
        with col3:
            overload_color = "🟢" if avg_overload < 5 else "🟡" if avg_overload < 15 else "🔴"
            st.metric(f"{overload_color} Avg Overload %", f"{avg_overload:.1f}%")
        
        with col4:
            blocked_color = "🟢" if avg_blocked < 5 else "🟡" if avg_blocked < 15 else "🔴"
            st.metric(f"{blocked_color} Avg Blocked %", f"{avg_blocked:.1f}%")
        
        fig = go.Figure()
        
        fig.add_trace(go.Scatter(
            x=health_df['HOUR'], 
            y=health_df['FAILURES_PER_1K'],
            name='Failures/1K',
            line=dict(color='#ef5350', width=2)
        ))
        
        fig.add_trace(go.Scatter(
            x=health_df['HOUR'], 
            y=health_df['RETRIES_PER_1K'],
            name='Retries/1K',
            line=dict(color='#ffa726', width=2)
        ))
        
        fig.update_layout(
            height=300,
            xaxis_title='Time',
            yaxis_title='Rate per 1,000 queries',
            hovermode='x unified',
            legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1)
        )
        
        st.plotly_chart(fig, use_container_width=True)
        
        fig2 = go.Figure()
        
        fig2.add_trace(go.Scatter(
            x=health_df['HOUR'], 
            y=health_df['OVERLOAD_PCT'],
            name='Overload %',
            line=dict(color='#42a5f5', width=2),
            fill='tozeroy'
        ))
        
        fig2.add_trace(go.Scatter(
            x=health_df['HOUR'], 
            y=health_df['BLOCKED_PCT'],
            name='Blocked %',
            line=dict(color='#ab47bc', width=2),
            fill='tozeroy'
        ))
        
        fig2.update_layout(
            height=300,
            xaxis_title='Time',
            yaxis_title='Percentage of total runtime',
            hovermode='x unified',
            legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1)
        )
        
        st.plotly_chart(fig2, use_container_width=True)
        
    else:
        st.info(f"No query data available for the last {days_filter} days")
        
except Exception as e:
    st.error(f"Error fetching query health metrics: {str(e)}")

st.divider()

st.markdown("### 🏭 Warehouse Performance")
st.caption("Compare efficiency across warehouses")

warehouse_query = f"""
SELECT 
    WAREHOUSE_NAME,
    COUNT(*) as query_count,
    ROUND(MEDIAN(TOTAL_ELAPSED_TIME), 0) as median_duration_ms,
    ROUND(AVG(TOTAL_ELAPSED_TIME), 0) as avg_duration_ms,
    SUM(CASE WHEN EXECUTION_STATUS = 'FAIL' THEN 1 ELSE 0 END) as failures,
    ROUND(
        (SUM(CASE WHEN EXECUTION_STATUS = 'FAIL' THEN 1 ELSE 0 END)::FLOAT / NULLIF(COUNT(*), 0)) * 1000, 
        2
    ) as failures_per_1k,
    SUM(
        CASE WHEN BYTES_SPILLED_TO_LOCAL_STORAGE > 0 
             OR BYTES_SPILLED_TO_REMOTE_STORAGE > 0 
        THEN 1 ELSE 0 END
    ) as queries_with_spillage,
    ROUND(
        (SUM(CASE WHEN BYTES_SPILLED_TO_LOCAL_STORAGE > 0 
                   OR BYTES_SPILLED_TO_REMOTE_STORAGE > 0 
             THEN 1 ELSE 0 END)::FLOAT / NULLIF(COUNT(*), 0)) * 100,
        2
    ) as spillage_pct,
    ROUND(AVG(QUEUED_OVERLOAD_TIME), 0) as avg_queue_time_ms
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE START_TIME >= DATEADD('day', -{days_filter}, CURRENT_TIMESTAMP())
    AND DATABASE_NAME = 'AUTOMATED_INTELLIGENCE'
    AND WAREHOUSE_NAME IS NOT NULL
GROUP BY WAREHOUSE_NAME
ORDER BY query_count DESC
"""

try:
    wh_df = session.sql(warehouse_query).to_pandas()
    
    if not wh_df.empty:
        col1, col2 = st.columns(2)
        
        with col1:
            fig = px.bar(
                wh_df, 
                x='WAREHOUSE_NAME', 
                y='QUERY_COUNT',
                labels={'WAREHOUSE_NAME': 'Warehouse', 'QUERY_COUNT': 'Query Count'},
                color='QUERY_COUNT',
                color_continuous_scale='Blues',
                height=300
            )
            fig.update_layout(showlegend=False)
            st.plotly_chart(fig, use_container_width=True)
        
        with col2:
            fig = px.bar(
                wh_df, 
                x='WAREHOUSE_NAME', 
                y='MEDIAN_DURATION_MS',
                labels={'WAREHOUSE_NAME': 'Warehouse', 'MEDIAN_DURATION_MS': 'Median Duration (ms)'},
                color='MEDIAN_DURATION_MS',
                color_continuous_scale='Oranges',
                height=300
            )
            fig.update_layout(showlegend=False)
            st.plotly_chart(fig, use_container_width=True)
        
        st.dataframe(
            wh_df[[
                'WAREHOUSE_NAME', 'QUERY_COUNT', 'MEDIAN_DURATION_MS', 
                'FAILURES_PER_1K', 'SPILLAGE_PCT', 'AVG_QUEUE_TIME_MS'
            ]].rename(columns={
                'WAREHOUSE_NAME': 'Warehouse',
                'QUERY_COUNT': 'Queries',
                'MEDIAN_DURATION_MS': 'Median Duration (ms)',
                'FAILURES_PER_1K': 'Failures/1K',
                'SPILLAGE_PCT': 'Spillage %',
                'AVG_QUEUE_TIME_MS': 'Avg Queue Time (ms)'
            }),
            use_container_width=True,
            hide_index=True
        )
    else:
        st.info(f"No warehouse data available for the last {days_filter} days")
        
except Exception as e:
    st.error(f"Error fetching warehouse metrics: {str(e)}")

st.divider()

st.markdown("### 📋 Top Tables by Activity")
st.caption("Identify most queried tables and potential bottlenecks")

tables_query = f"""
WITH table_activity AS (
    SELECT 
        TABLES_SCANNED,
        QUERY_ID,
        EXECUTION_STATUS,
        TOTAL_ELAPSED_TIME,
        TRANSACTION_BLOCKED_TIME
    FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
    WHERE START_TIME >= DATEADD('day', -{days_filter}, CURRENT_TIMESTAMP())
        AND DATABASE_NAME = 'AUTOMATED_INTELLIGENCE'
        AND QUERY_TYPE IN ('SELECT', 'INSERT', 'UPDATE', 'DELETE', 'MERGE')
        AND TABLES_SCANNED IS NOT NULL
),
table_stats AS (
    SELECT 
        t.value:name::STRING as table_name,
        COUNT(*) as query_count,
        ROUND(MEDIAN(ta.TOTAL_ELAPSED_TIME), 0) as median_duration_ms,
        SUM(CASE WHEN ta.EXECUTION_STATUS = 'FAIL' THEN 1 ELSE 0 END) as failures,
        ROUND(
            (SUM(CASE WHEN ta.EXECUTION_STATUS = 'FAIL' THEN 1 ELSE 0 END)::FLOAT / NULLIF(COUNT(*), 0)) * 1000,
            2
        ) as failures_per_1k,
        SUM(CASE WHEN ta.TRANSACTION_BLOCKED_TIME > 0 THEN 1 ELSE 0 END) as blocked_queries,
        ROUND(
            (SUM(CASE WHEN ta.TRANSACTION_BLOCKED_TIME > 0 THEN 1 ELSE 0 END)::FLOAT / NULLIF(COUNT(*), 0)) * 1000,
            2
        ) as blocked_per_1k
    FROM table_activity ta,
    LATERAL FLATTEN(input => PARSE_JSON(ta.TABLES_SCANNED)) t
    GROUP BY table_name
)
SELECT *
FROM table_stats
WHERE table_name LIKE 'AUTOMATED_INTELLIGENCE%'
ORDER BY query_count DESC
LIMIT 20
"""

try:
    tables_df = session.sql(tables_query).to_pandas()
    
    if not tables_df.empty:
        tables_df['TABLE_NAME'] = tables_df['TABLE_NAME'].str.replace('AUTOMATED_INTELLIGENCE.', '')
        
        fig = px.bar(
            tables_df.head(10),
            x='QUERY_COUNT',
            y='TABLE_NAME',
            orientation='h',
            labels={'TABLE_NAME': 'Table', 'QUERY_COUNT': 'Query Count'},
            color='MEDIAN_DURATION_MS',
            color_continuous_scale='Viridis',
            height=400
        )
        fig.update_layout(
            yaxis={'categoryorder': 'total ascending'},
            coloraxis_colorbar=dict(title="Median<br>Duration (ms)")
        )
        st.plotly_chart(fig, use_container_width=True)
        
        col1, col2 = st.columns(2)
        
        with col1:
            st.markdown("**🔴 Tables with Most Failures**")
            failures_df = tables_df[tables_df['FAILURES'] > 0].nlargest(5, 'FAILURES_PER_1K')
            if not failures_df.empty:
                st.dataframe(
                    failures_df[['TABLE_NAME', 'QUERY_COUNT', 'FAILURES', 'FAILURES_PER_1K']].rename(columns={
                        'TABLE_NAME': 'Table',
                        'QUERY_COUNT': 'Queries',
                        'FAILURES': 'Failures',
                        'FAILURES_PER_1K': 'Failures/1K'
                    }),
                    use_container_width=True,
                    hide_index=True
                )
            else:
                st.success("No failures detected")
        
        with col2:
            st.markdown("**🔒 Tables with Most Blocked Queries**")
            blocked_df = tables_df[tables_df['BLOCKED_QUERIES'] > 0].nlargest(5, 'BLOCKED_PER_1K')
            if not blocked_df.empty:
                st.dataframe(
                    blocked_df[['TABLE_NAME', 'QUERY_COUNT', 'BLOCKED_QUERIES', 'BLOCKED_PER_1K']].rename(columns={
                        'TABLE_NAME': 'Table',
                        'QUERY_COUNT': 'Queries',
                        'BLOCKED_QUERIES': 'Blocked',
                        'BLOCKED_PER_1K': 'Blocked/1K'
                    }),
                    use_container_width=True,
                    hide_index=True
                )
            else:
                st.success("No blocking detected")
        
    else:
        st.info(f"No table activity data available for the last {days_filter} days")
        
except Exception as e:
    st.error(f"Error fetching table metrics: {str(e)}")
