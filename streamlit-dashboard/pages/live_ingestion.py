import streamlit as st
import plotly.express as px
from shared import get_session, show_header

show_header()
st.subheader("📊 Live Ingestion")
st.divider()
# Time range filter (specific to this page)
days_filter = st.slider("Show data for last N days", 7, 30, 7, key="days_filter")
st.info(f"📅 Showing data for the last **{days_filter} days**")

session = get_session()

# Query current row counts (filtered by time range)
orders_count_query = f"""
SELECT COUNT(*) as cnt FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS
WHERE ORDER_DATE >= DATEADD('day', -{days_filter}, CURRENT_TIMESTAMP())
"""
orders_result = session.sql(orders_count_query).collect()
total_orders = orders_result[0]['CNT']

order_items_count_query = f"""
SELECT COUNT(*) as cnt 
FROM AUTOMATED_INTELLIGENCE.RAW.ORDER_ITEMS oi
JOIN AUTOMATED_INTELLIGENCE.RAW.ORDERS o ON oi.order_id = o.order_id
WHERE o.ORDER_DATE >= DATEADD('day', -{days_filter}, CURRENT_TIMESTAMP())
"""
items_result = session.sql(order_items_count_query).collect()
total_items = items_result[0]['CNT']

st.markdown(f"#### 📊 Total Orders: {total_orders:,}  |  📦 Total Order Items: {total_items:,}")

st.divider()

# Ingestion trend (filtered by time range)
st.markdown("#### 📈 Ingestion Trend")

trend_query = f"""
SELECT 
    DATE_TRUNC('hour', ORDER_DATE) as hour,
    COUNT(*) as order_count
FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS
WHERE ORDER_DATE >= DATEADD('day', -{days_filter}, CURRENT_TIMESTAMP())
GROUP BY DATE_TRUNC('hour', ORDER_DATE)
ORDER BY hour
"""

trend_df = session.sql(trend_query).to_pandas()

if not trend_df.empty:
    fig = px.line(trend_df, x="HOUR", y="ORDER_COUNT", height=400)
    fig.update_xaxes(title="Date/Time")
    fig.update_yaxes(title="Order Count")
    fig.update_layout(hovermode='x unified')
    st.plotly_chart(fig, width='stretch')
else:
    fallback_query = """
    SELECT 
        DATE_TRUNC('day', ORDER_DATE) as day,
        COUNT(*) as order_count
    FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS
    WHERE ORDER_DATE >= (SELECT MAX(ORDER_DATE) - INTERVAL '30 days' FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS)
    GROUP BY DATE_TRUNC('day', ORDER_DATE)
    ORDER BY day
    """
    fallback_df = session.sql(fallback_query).to_pandas()
    if not fallback_df.empty:
        st.warning(f"⚠️ No data available for the last {days_filter} days. Showing all-time trend...")
        st.line_chart(fallback_df, x="DAY", y="ORDER_COUNT", height=300)
    else:
        st.warning("⚠️ No data available. Stream data first using Snowpipe Streaming.")

st.divider()

# Order Status Distribution (filtered)
st.markdown("#### 🥧 Order Status Distribution")

status_query = f"""
SELECT 
    ORDER_STATUS,
    COUNT(*) as order_count
FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS
WHERE ORDER_DATE >= DATEADD('day', -{days_filter}, CURRENT_TIMESTAMP())
GROUP BY ORDER_STATUS
ORDER BY order_count DESC
"""

status_df = session.sql(status_query).to_pandas()

if not status_df.empty:
    fig = px.pie(status_df, values='ORDER_COUNT', names='ORDER_STATUS', height=600)
    fig.update_traces(textposition='inside', textinfo='percent+label')
    st.plotly_chart(fig, width='stretch')
else:
    st.info("No orders available")

st.divider()

# Product Categories by Order Value (Stacked Bar) - filtered
st.markdown("#### 📊 Product Category Sales by Order Size")

stacked_query = f"""
SELECT 
    CASE
        WHEN o.total_amount < 100 THEN 'Small (<$100)'
        WHEN o.total_amount < 500 THEN 'Medium ($100-$500)'
        WHEN o.total_amount < 2000 THEN 'Large ($500-$2K)'
        ELSE 'Extra Large (>$2K)'
    END AS order_size,
    oi.product_category,
    SUM(oi.line_total) as revenue
FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS o
JOIN AUTOMATED_INTELLIGENCE.RAW.ORDER_ITEMS oi ON o.order_id = oi.order_id
WHERE o.ORDER_DATE >= DATEADD('day', -{days_filter}, CURRENT_TIMESTAMP())
GROUP BY order_size, oi.product_category
ORDER BY 
    CASE order_size
        WHEN 'Small (<$100)' THEN 1
        WHEN 'Medium ($100-$500)' THEN 2
        WHEN 'Large ($500-$2K)' THEN 3
        WHEN 'Extra Large (>$2K)' THEN 4
    END,
    oi.product_category
"""

stacked_df = session.sql(stacked_query).to_pandas()

if not stacked_df.empty:
    fig = px.bar(stacked_df, x='ORDER_SIZE', y='REVENUE', color='PRODUCT_CATEGORY',
                labels={'ORDER_SIZE': 'Order Size', 'REVENUE': 'Revenue', 'PRODUCT_CATEGORY': 'Category'},
                height=500,
                barmode='stack')
    fig.update_layout(legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1))
    st.plotly_chart(fig, width='stretch')
else:
    st.info("No data available")
