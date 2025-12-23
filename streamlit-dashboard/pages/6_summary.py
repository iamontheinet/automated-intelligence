import streamlit as st
import plotly.express as px
from shared import get_session, show_header

show_header()
st.subheader("📈 Summary")
st.divider()
st.info("📅 Showing **all-time** historical data")

session = get_session()
# All-time metrics row
col1, col2, col3, col4, col5 = st.columns(5)

alltime_orders_query = """
SELECT COUNT(*) as cnt FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS
"""
alltime_orders_result = session.sql(alltime_orders_query).collect()
alltime_orders = alltime_orders_result[0]['CNT']

alltime_items_query = """
SELECT COUNT(*) as cnt FROM AUTOMATED_INTELLIGENCE.RAW.ORDER_ITEMS
"""
alltime_items_result = session.sql(alltime_items_query).collect()
alltime_items = alltime_items_result[0]['CNT']

alltime_customers_query = """
SELECT COUNT(*) as cnt FROM AUTOMATED_INTELLIGENCE.RAW.CUSTOMERS
"""
alltime_customers_result = session.sql(alltime_customers_query).collect()
alltime_customers = alltime_customers_result[0]['CNT']

alltime_revenue_query = """
SELECT ROUND(SUM(total_amount), 2) as total_revenue
FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS
"""
alltime_revenue_result = session.sql(alltime_revenue_query).collect()
alltime_revenue = alltime_revenue_result[0]['TOTAL_REVENUE'] if alltime_revenue_result[0]['TOTAL_REVENUE'] is not None else 0

alltime_products_query = """
SELECT COUNT(DISTINCT product_id) as cnt 
FROM AUTOMATED_INTELLIGENCE.RAW.ORDER_ITEMS
"""
alltime_products_result = session.sql(alltime_products_query).collect()
alltime_products = alltime_products_result[0]['CNT']

col1.metric("Total Customers", f"{alltime_customers:,}")
col2.metric("Total Orders", f"{alltime_orders:,}")
col3.metric("Total Order Items", f"{alltime_items:,}")
col4.metric("Total Products", f"{alltime_products:,}")
col5.metric("Total Revenue", f"${alltime_revenue:,.2f}")

st.divider()

# All-time charts
col_left, col_right = st.columns(2)

with col_left:
    st.subheader("📊 Order Status Distribution")
    
    alltime_status_query = """
    SELECT 
        ORDER_STATUS,
        COUNT(*) as order_count
    FROM AUTOMATED_INTELLIGENCE.RAW.ORDERS
    GROUP BY ORDER_STATUS
    ORDER BY order_count DESC
    """
    
    alltime_status_df = session.sql(alltime_status_query).to_pandas()
    
    if not alltime_status_df.empty:
        fig = px.pie(alltime_status_df, values='ORDER_COUNT', names='ORDER_STATUS', height=400)
        fig.update_traces(textposition='inside', textinfo='percent+label')
        st.plotly_chart(fig, width='stretch')
    else:
        st.info("No orders available")

with col_right:
    st.subheader("📦 Product Category Revenue")
    
    alltime_categories_query = """
    SELECT 
        oi.product_category,
        SUM(oi.line_total) as total_revenue
    FROM AUTOMATED_INTELLIGENCE.RAW.ORDER_ITEMS oi
    GROUP BY oi.product_category
    ORDER BY total_revenue DESC
    """
    
    alltime_categories_df = session.sql(alltime_categories_query).to_pandas()
    
    if not alltime_categories_df.empty:
        fig = px.bar(alltime_categories_df, x='PRODUCT_CATEGORY', y='TOTAL_REVENUE',
                    labels={'PRODUCT_CATEGORY': 'Category', 'TOTAL_REVENUE': 'Revenue'},
                    height=400)
        st.plotly_chart(fig, width='stretch')
    else:
        st.info("No product data available")

st.divider()

# All-time stacked bar
st.subheader("📊 Product Category Sales by Order Size")

alltime_stacked_query = """
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

alltime_stacked_df = session.sql(alltime_stacked_query).to_pandas()

if not alltime_stacked_df.empty:
    fig = px.bar(alltime_stacked_df, x='ORDER_SIZE', y='REVENUE', color='PRODUCT_CATEGORY',
                labels={'ORDER_SIZE': 'Order Size', 'REVENUE': 'Revenue', 'PRODUCT_CATEGORY': 'Category'},
                height=500,
                barmode='stack')
    fig.update_layout(legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1))
    st.plotly_chart(fig, width='stretch')
else:
    st.info("No data available")
