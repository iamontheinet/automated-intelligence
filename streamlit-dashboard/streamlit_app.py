import streamlit as st
import time
from shared import IS_SIS, load_custom_css

# Page configuration
st.set_page_config(
    page_title="The Dash Board",
    page_icon="assets/dash_snowboard_512.png",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Load custom CSS
load_custom_css()

# Define pages with explicit URL paths to avoid conflicts
live_ingestion_page = st.Page("pages/2_live_ingestion.py", title="Live Ingestion", icon="📊", url_path="live_ingestion")
pipeline_health_page = st.Page("pages/3_pipeline_health.py", title="Pipeline Health", icon="🏥", url_path="pipeline_health")
system_health_page = st.Page("pages/7_system_health.py", title="System Health", icon="🔍", url_path="system_health")
query_performance_page = st.Page("pages/4_query_performance.py", title="Interactive vs Standard", icon="⚡", url_path="query_performance")
warehouse_performance_page = st.Page("pages/1_data_pipeline.py", title="Gen 1 vs Gen 2", icon="🚀", url_path="warehouse_performance")
ml_insights_page = st.Page("pages/5_ml_insights.py", title="Distributed ML", icon="🔮", url_path="ml_insights")
customer_product_analytics_page = st.Page("pages/8_customer_product_analytics.py", title="Customer & Product Analytics", icon="📈", url_path="customer_product_analytics")
summary_page = st.Page("pages/6_summary.py", title="Summary", icon="📋", url_path="summary")

# Create navigation with default page
pg = st.navigation([live_ingestion_page, pipeline_health_page, system_health_page, query_performance_page, warehouse_performance_page, ml_insights_page, customer_product_analytics_page, summary_page])

# Auto-refresh controls in sidebar
with st.sidebar:
    st.divider()
    st.header("⚙️ Settings")
    auto_refresh_enabled = st.checkbox("Enable auto-refresh", value=False)
    refresh_interval = st.slider("Refresh interval (seconds)", 10, 30, 15, disabled=not auto_refresh_enabled)

# Run the selected page
pg.run()

# Auto-refresh 
if auto_refresh_enabled:
    time.sleep(refresh_interval)
    st.rerun()
