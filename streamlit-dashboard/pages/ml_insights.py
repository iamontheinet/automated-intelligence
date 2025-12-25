import streamlit as st
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots
from shared import get_session, show_header, format_number
import pandas as pd
from datetime import datetime

show_header()
st.subheader("🔮 Distributed ML")
st.divider()
st.markdown("Customer churn prediction powered by Ray distributed training. [Click here](https://app.snowflake.com/sfsenorthamerica/gen_ai_hol/#/notebooks/AUTOMATED_INTELLIGENCE.MODELS.CUSTOMER_CHURN_TRAINING) to view the training Snowflake notebook.")
st.info("📝 A customer is considered 'churned' if they haven't placed an order in 7+ days")
# Get Snowflake session
session = get_session()

# Create two tabs
tab1, tab2 = st.tabs(["📊 Model Performance", "🔮 Churn Predictions"])

with tab1:
    st.subheader("Model Metrics")
    
    try:
        # Query model metadata from registry
        model_query = """
        SELECT 
            model_name,
            model_version_name as version_name,
            comment,
            created_on
        FROM AUTOMATED_INTELLIGENCE.INFORMATION_SCHEMA.MODEL_VERSIONS
        WHERE model_name = 'CUSTOMER_CHURN_PREDICTOR'
        ORDER BY created_on DESC
        LIMIT 1
        """
        
        model_info_df = session.sql(model_query).to_pandas()
        
        if len(model_info_df) > 0:
            model_info = model_info_df.iloc[0]
            
            # Display model info in smaller format
            # Extract model type from comment
            comment = model_info['COMMENT']
            model_type = "XGBoost Classifier"
            if "XGBoost" in comment:
                model_type = "XGBoost Classifier"
            
            col1, col2, col3, col4 = st.columns(4)
            
            with col1:
                st.markdown("**Model Name:**")
                st.text(model_info['MODEL_NAME'])
            
            with col2:
                st.markdown("**Version:**")
                st.text(model_info['VERSION_NAME'])
            
            with col3:
                st.markdown("**Last Trained:**")
                created_date = model_info['CREATED_ON']
                if isinstance(created_date, pd.Timestamp):
                    st.text(created_date.strftime("%Y-%m-%d %H:%M"))
                else:
                    st.text(str(created_date))
            
            with col4:
                st.markdown("**Model Type:**")
                st.text(model_type)
            
            st.divider()
            
            # Extract ROC-AUC from comment
            if "ROC-AUC:" in comment:
                roc_auc_str = comment.split("ROC-AUC:")[1].strip().split()[0]
                try:
                    roc_auc = float(roc_auc_str)
                    
                    # Display ROC-AUC gauge
                    fig_gauge = go.Figure(go.Indicator(
                        mode="gauge+number",
                        value=roc_auc,
                        domain={'x': [0, 1], 'y': [0, 1]},
                        title={'text': "ROC-AUC Score"},
                        gauge={
                            'axis': {'range': [None, 1]},
                            'bar': {'color': "darkblue"},
                            'steps': [
                                {'range': [0, 0.5], 'color': "lightgray"},
                                {'range': [0.5, 0.7], 'color': "yellow"},
                                {'range': [0.7, 0.85], 'color': "lightgreen"},
                                {'range': [0.85, 1], 'color': "green"}
                            ],
                            'threshold': {
                                'line': {'color': "red", 'width': 4},
                                'thickness': 0.75,
                                'value': 0.85
                            }
                        }
                    ))
                    
                    fig_gauge.update_layout(height=300)
                    st.plotly_chart(fig_gauge, width='stretch')
                    
                    # Interpretation
                    if roc_auc >= 0.85:
                        st.success("✅ Excellent model performance! The model has strong discriminative ability.")
                    elif roc_auc >= 0.7:
                        st.info("✓ Good model performance. The model can distinguish churned vs active customers well.")
                    elif roc_auc >= 0.5:
                        st.warning("⚠️ Fair model performance. Consider feature engineering or model tuning.")
                    else:
                        st.error("❌ Poor model performance. Model needs significant improvements.")
                
                except ValueError:
                    st.warning("Could not parse ROC-AUC value from model metadata")
            
            st.divider()
            
            # Feature importance (mock data - in real implementation, this would be stored)
            st.subheader("🔍 Feature Importance")
            
            feature_importance_data = {
                'Feature': [
                    'CUSTOMER_TENURE_DAYS',
                    'AVG_ORDER_VALUE',
                    'TOTAL_SPENT',
                    'REVENUE_PER_ORDER',
                    'TOTAL_ORDERS',
                    'ORDER_FREQUENCY'
                ],
                'Importance': [0.90, 0.03, 0.02, 0.02, 0.02, 0.01]
            }
            
            fi_df = pd.DataFrame(feature_importance_data)
            
            fig_importance = px.bar(
                fi_df,
                x='Importance',
                y='Feature',
                orientation='h',
                title='Feature Importance for Churn Prediction',
                color='Importance',
                color_continuous_scale='Blues'
            )
            
            fig_importance.update_layout(
                showlegend=False,
                height=400,
                xaxis_title="Importance Score",
                yaxis_title=""
            )
            
            st.plotly_chart(fig_importance, width='stretch')
        
        else:
            st.warning("⚠️ No trained model found. Please run the Ray training notebook first.")
            st.markdown("""
            **To train the model:**
            1. Open `ray-ml-training/customer_churn_training.ipynb` in Snowflake Notebooks
            2. Run all cells to train the model
            3. Model will be saved to `AUTOMATED_INTELLIGENCE.MODELS` schema
            4. Refresh this page to see results
            """)
    
    except Exception as e:
        st.error(f"Error loading model information: {str(e)}")
        st.info("Make sure the model has been trained and saved to the registry.")

with tab2:
    st.subheader("🔮 Customer Churn Predictions")
    
    try:
        # Query customer data with churn indicators
        churn_query = """
        WITH customer_metrics AS (
            SELECT 
                customer_id,
                total_orders,
                total_spent,
                avg_order_value,
                DATEDIFF('day', first_order_date, last_order_date) as customer_tenure_days,
                DATEDIFF('day', last_order_date, CURRENT_DATE()) as days_since_last_order,
                CASE 
                    WHEN DATEDIFF('day', last_order_date, CURRENT_DATE()) > 7 THEN 1 
                    ELSE 0 
                END as is_likely_churned
            FROM AUTOMATED_INTELLIGENCE.INTERACTIVE.CUSTOMER_ORDER_ANALYTICS
            WHERE total_orders > 0
        )
        SELECT 
            is_likely_churned,
            COUNT(*) as customer_count,
            AVG(total_spent) as avg_total_spent,
            AVG(total_orders) as avg_total_orders,
            AVG(days_since_last_order) as avg_days_since_last_order
        FROM customer_metrics
        GROUP BY is_likely_churned
        ORDER BY is_likely_churned
        """
        
        churn_summary_df = session.sql(churn_query).to_pandas()
        
        if len(churn_summary_df) > 0:
            # Display churn metrics
            total_customers = churn_summary_df['CUSTOMER_COUNT'].sum()
            active_customers = churn_summary_df[churn_summary_df['IS_LIKELY_CHURNED'] == 0]['CUSTOMER_COUNT'].values[0] if len(churn_summary_df[churn_summary_df['IS_LIKELY_CHURNED'] == 0]) > 0 else 0
            churned_customers = churn_summary_df[churn_summary_df['IS_LIKELY_CHURNED'] == 1]['CUSTOMER_COUNT'].values[0] if len(churn_summary_df[churn_summary_df['IS_LIKELY_CHURNED'] == 1]) > 0 else 0
            churn_rate = (churned_customers / total_customers * 100) if total_customers > 0 else 0
            
            col1, col2, col3, col4 = st.columns(4)
            
            with col1:
                st.metric("Total Customers", format_number(int(total_customers), include_decimals=False))
            
            with col2:
                st.metric("Active Customers", format_number(int(active_customers), include_decimals=False))
            
            with col3:
                st.metric("Churned Customers", format_number(int(churned_customers), include_decimals=False))
            
            with col4:
                st.metric("Churn Rate", f"{churn_rate:.1f}%")
            
            st.divider()
            
            st.subheader("🥧 Customer Churn Distribution")

            fig_pie = px.pie(
                churn_summary_df,
                values='CUSTOMER_COUNT',
                names=churn_summary_df['IS_LIKELY_CHURNED'].map({0: 'Active', 1: 'Churned'}),
                color=churn_summary_df['IS_LIKELY_CHURNED'].map({0: 'Active', 1: 'Churned'}),
                color_discrete_map={'Active': '#2E86AB', 'Churned': '#E63946'},
                height=600
            )
            
            fig_pie.update_traces(textposition='inside', textinfo='percent+label')
            
            st.plotly_chart(fig_pie, width="stretch")
            
            st.divider()
            
            # Comparison metrics
            st.subheader("📊 Active vs Churned Customer Comparison")
            
            # Prepare data for comparison
            comparison_data = []
            for _, row in churn_summary_df.iterrows():
                status = 'Active' if row['IS_LIKELY_CHURNED'] == 0 else 'Churned'
                comparison_data.append({
                    'Status': status,
                    'Metric': 'Avg Total Spent',
                    'Value': row['AVG_TOTAL_SPENT']
                })
                comparison_data.append({
                    'Status': status,
                    'Metric': 'Avg Total Orders',
                    'Value': row['AVG_TOTAL_ORDERS']
                })
                comparison_data.append({
                    'Status': status,
                    'Metric': 'Avg Days Since Last Order',
                    'Value': row['AVG_DAYS_SINCE_LAST_ORDER']
                })
            
            comparison_df = pd.DataFrame(comparison_data)
            
            # Create grouped bar chart
            fig_comparison = px.bar(
                comparison_df,
                x='Metric',
                y='Value',
                color='Status',
                barmode='group',
                title='Customer Behavior Comparison',
                color_discrete_map={'Active': '#2E86AB', 'Churned': '#E63946'}
            )
            
            fig_comparison.update_layout(height=400)
            st.plotly_chart(fig_comparison, width='stretch')
            
            st.divider()
                        
            at_risk_query = """
            SELECT 
                customer_id,
                total_orders,
                total_spent,
                avg_order_value,
                DATEDIFF('day', last_order_date, CURRENT_DATE()) as days_since_last_order,
                last_order_date
            FROM AUTOMATED_INTELLIGENCE.INTERACTIVE.CUSTOMER_ORDER_ANALYTICS
            WHERE DATEDIFF('day', last_order_date, CURRENT_DATE()) BETWEEN 5 AND 7
            ORDER BY total_spent DESC
            """
            
            at_risk_df = session.sql(at_risk_query).to_pandas()

            # At-risk customers table
            st.subheader(f"⚠️ High-Risk Customers ({format_number(len(at_risk_df), include_decimals=False)} found in the 5-7 day window)")

            if len(at_risk_df) > 0:
                st.dataframe(
                    at_risk_df.style.format({
                        'TOTAL_SPENT': '${:,.2f}',
                        'AVG_ORDER_VALUE': '${:,.2f}',
                        'TOTAL_ORDERS': '{:,.0f}',
                        'DAYS_SINCE_LAST_ORDER': '{:.0f}'
                    }),
                    width="stretch",
                    height=400
                )
                
                st.info("""
                **Recommended Actions:**
                - Send re-engagement emails to customers who haven't ordered in 5-7 days
                - Offer personalized discounts based on purchase history
                - Highlight new products in categories they've purchased before
                """)
            else:
                st.info("No high-risk customers found in the 5-7 day window.")
        
        else:
            st.warning("⚠️ No trained model found. Please run the Ray training notebook first.")
    
    except Exception as e:
        st.error(f"Error loading predictions: {str(e)}")

# About section - only show if model exists
try:
    model_exists_query = """
    SELECT COUNT(*) as model_count
    FROM AUTOMATED_INTELLIGENCE.INFORMATION_SCHEMA.MODEL_VERSIONS
    WHERE model_name = 'CUSTOMER_CHURN_PREDICTOR'
    """
    model_exists_result = session.sql(model_exists_query).to_pandas()
    model_exists = model_exists_result.iloc[0]['MODEL_COUNT'] > 0
    
    if model_exists:
        st.divider()
        
        with st.expander("ℹ️ About This ML Model", expanded=False):
            st.markdown("""
            **Model Architecture:**
            - Algorithm: XGBoost Classifier with sklearn Pipeline
            - Training: Distributed training using Ray on Snowflake
            - Features: 6 customer behavior metrics (frequency, monetary, tenure)
            - Target: Binary classification (churned vs active)
            - Class Imbalance: Uses `scale_pos_weight` to handle 27:1 imbalance ratio
            - Data Leakage Prevention: Excludes recency features that directly reveal the target
            
            **Ray Distributed Training:**
            - **Ray Cluster:** 4-node cluster (1 head + 3 workers)
            - **Resources:** 24 CPUs, 72GB RAM total
            - **Distribution:** Ray automatically distributes XGBoost training across nodes
            - **Monitoring:** Ray Dashboard tracks task distribution and resource usage
            - **Scaling:** `scale_cluster()` API for dynamic node scaling
            - **Performance:** Faster training on large datasets vs single-node
            
            **Definition of Churn:**
            A customer is considered "churned" if they haven't placed an order in 7+ days.
            
            **Note:** 7-day threshold is used for demo purposes to ensure balanced training data. In production, this would typically be 30-90 days depending on business context.
            
            **Training Process:**
            1. Initialize Ray cluster in Snowflake Notebook (Container Runtime)
            2. Scale to 4 nodes for distributed compute
            3. Load data from Interactive Tables via Snowpark
            4. Feature engineering: RFM analysis + derived metrics
            5. Train sklearn Pipeline (StandardScaler + XGBoost) with Ray
            6. Save to Snowflake Model Registry with version tracking
            7. Scale down cluster to free resources
            
            **Ray Benefits:**
            - Elastic distributed compute: Scale from 1 to N nodes
            - GPU support: Can train on GPU-accelerated instances
            - Framework agnostic: Works with PyTorch, TensorFlow, XGBoost, scikit-learn
            - Native Snowflake integration: No data movement required
            - Cost efficient: Pay only for compute time used
            """)
except Exception:
    pass
