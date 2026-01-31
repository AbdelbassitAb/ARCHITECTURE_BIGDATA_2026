"""
7_Promo_Planner - ML-Powered Promotion Planning Tool
Predicts promotion effectiveness and ROI before launch
"""

import streamlit as st
import pandas as pd
import numpy as np
import pickle
import os
import sys
from datetime import datetime, timedelta

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from _utils import run_query

st.set_page_config(page_title="Promo Planner", page_icon="🎯", layout="wide")

# Load models
@st.cache_resource
def load_models():
    """Load trained ML models"""
    model_dir = os.path.join(os.path.dirname(__file__), '..', 'ml_models', 'saved_models')
    
    try:
        with open(os.path.join(model_dir, 'promo_classifier.pkl'), 'rb') as f:
            clf = pickle.load(f)
        with open(os.path.join(model_dir, 'promo_regressor.pkl'), 'rb') as f:
            reg = pickle.load(f)
        with open(os.path.join(model_dir, 'label_encoders.pkl'), 'rb') as f:
            label_encoders = pickle.load(f)
        return clf, reg, label_encoders, None
    except FileNotFoundError as e:
        return None, None, None, str(e)

# Load historical baseline data
@st.cache_data(ttl=3600)
def get_baseline_data():
    """Get historical averages for baseline estimation"""
    query = """
    SELECT 
        REGION,
        PRODUCT_CATEGORY,
        AVG(AVG_TRANSACTION_VALUE) AS AVG_TRANSACTION,
        AVG(TOTAL_SALES / DURATION_DAYS) AS AVG_DAILY_SALES,
        AVG(TRANSACTIONS_COUNT / DURATION_DAYS) AS AVG_DAILY_TRANSACTIONS
    FROM ANALYTICS.ML_PROMO_EFFECTIVENESS
    GROUP BY REGION, PRODUCT_CATEGORY
    """
    return run_query(query)

# Main UI
st.title("🎯 Promo Planner")
st.markdown("**AI-Powered Promotion Planning** - Predict ROI before you launch")

# Load models
clf, reg, label_encoders, error = load_models()

if error:
    st.error("⚠️ Models not trained yet!")
    st.info("""
    **To train the models:**
    1. First, run the SQL script to create ML feature tables:
       - `sql/phase_3/2_ml_feature_tables.sql`
    2. Then run the training script:
       - `python streamlit/ml_models/promo_optimizer.py`
    3. Refresh this page
    """)
    st.stop()

st.success("✅ ML models loaded successfully!")

# Get baseline data
baseline_df = get_baseline_data()

# Sidebar - Input Form
st.sidebar.header("📝 Promotion Details")

with st.sidebar.form("promo_form"):
    st.subheader("Basic Info")
    
    # Get unique values from encoders
    product_categories = list(label_encoders['PRODUCT_CATEGORY'].classes_)
    promo_types = list(label_encoders['PROMOTION_TYPE'].classes_)
    regions = list(label_encoders['REGION'].classes_)
    
    product_category = st.selectbox("Product Category", product_categories)
    promo_type = st.selectbox("Promotion Type", promo_types)
    region = st.selectbox("Region", regions)
    
    st.subheader("Promotion Parameters")
    discount = st.slider("Discount %", min_value=5, max_value=50, value=15, step=5)
    duration = st.slider("Duration (days)", min_value=1, max_value=30, value=7)
    
    st.subheader("Timing")
    start_date = st.date_input("Start Date", value=datetime.now() + timedelta(days=7))
    
    st.subheader("Marketing Context")
    has_campaign = st.checkbox("Overlaps with marketing campaign")
    num_campaigns = st.number_input("Number of overlapping campaigns", min_value=0, max_value=5, value=1 if has_campaign else 0)
    
    submitted = st.form_submit_button("🔮 Predict ROI", use_container_width=True)

# Main content - Predictions
if submitted:
    # Calculate temporal features
    start_month = start_date.month
    start_quarter = (start_month - 1) // 3 + 1
    start_dow = start_date.weekday()  # 0=Monday
    is_holiday_season = 1 if start_month in [11, 12] else 0
    starts_on_weekend = 1 if start_dow in [5, 6] else 0
    
    # Get baseline for selected region/product_category
    baseline_row = baseline_df[
        (baseline_df['REGION'] == region) & 
        (baseline_df['PRODUCT_CATEGORY'] == product_category)
    ]
    
    if len(baseline_row) > 0:
        baseline_avg_transaction = float(baseline_row['AVG_TRANSACTION'].values[0])
        baseline_daily_sales = float(baseline_row['AVG_DAILY_SALES'].values[0])
        baseline_daily_transactions = float(baseline_row['AVG_DAILY_TRANSACTIONS'].values[0])
    else:
        # Use global average if no match
        baseline_avg_transaction = float(baseline_df['AVG_TRANSACTION'].mean())
        baseline_daily_sales = float(baseline_df['AVG_DAILY_SALES'].mean())
        baseline_daily_transactions = float(baseline_df['AVG_DAILY_TRANSACTIONS'].mean())
    
    # Encode categorical variables
    product_category_encoded = label_encoders['PRODUCT_CATEGORY'].transform([product_category])[0]
    promo_type_encoded = label_encoders['PROMOTION_TYPE'].transform([promo_type])[0]
    region_encoded = label_encoders['REGION'].transform([region])[0]
    
    # Create feature vector (matching training script order)
    features = np.array([[
        product_category_encoded,
        discount,
        promo_type_encoded,
        region_encoded,
        duration,
        baseline_avg_transaction,
        baseline_daily_transactions,
        baseline_daily_sales,
        1 if has_campaign else 0,
        num_campaigns,
        start_month,
        start_quarter,
        start_dow,
        is_holiday_season,
        starts_on_weekend
    ]])
    
    # Make predictions
    success_prob = clf.predict_proba(features)[0][1]
    predicted_lift = reg.predict(features)[0]
    
    # Calculate financial estimates
    predicted_daily_sales = baseline_daily_sales * (1 + predicted_lift)
    predicted_total_sales = predicted_daily_sales * duration
    baseline_total_sales = baseline_daily_sales * duration
    incremental_sales = predicted_total_sales - baseline_total_sales
    
    estimated_cost = predicted_total_sales * (discount / 100.0)
    estimated_roi = (incremental_sales / estimated_cost) if estimated_cost > 0 else 0
    
    # Display predictions in columns
    st.markdown("---")
    st.header("📊 Prediction Results")
    
    col1, col2, col3 = st.columns(3)
    
    with col1:
        st.metric(
            "Success Probability", 
            f"{success_prob:.1%}",
            help="Likelihood that promotion will beat baseline sales"
        )
        if success_prob >= 0.7:
            st.success("🎉 High chance of success!")
        elif success_prob >= 0.5:
            st.warning("⚠️ Moderate chance - consider adjustments")
        else:
            st.error("❌ Low chance - reconsider this promo")
    
    with col2:
        st.metric(
            "Predicted Sales Lift", 
            f"{predicted_lift:+.1%}",
            help="Expected increase vs baseline"
        )
    
    with col3:
        st.metric(
            "Estimated ROI", 
            f"{estimated_roi:.2f}x",
            help="Return on investment (incremental sales / promo cost)"
        )
    
    # Detailed breakdown
    st.markdown("---")
    st.subheader("💰 Financial Breakdown")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.markdown("**Sales Estimates**")
        st.write(f"• Baseline (no promo): ${baseline_total_sales:,.0f}")
        st.write(f"• With promotion: ${predicted_total_sales:,.0f}")
        st.write(f"• Incremental sales: ${incremental_sales:,.0f}")
    
    with col2:
        st.markdown("**Cost & ROI**")
        st.write(f"• Estimated promo cost: ${estimated_cost:,.0f}")
        st.write(f"• Net benefit: ${incremental_sales - estimated_cost:,.0f}")
        st.write(f"• ROI: {estimated_roi:.2f}x")
    
    # Recommendations
    st.markdown("---")
    st.subheader("💡 Recommendations")
    
    if success_prob >= 0.7 and estimated_roi >= 2.0:
        st.success("""
        ✅ **Strong Recommendation: GO**
        - High success probability
        - Excellent ROI
        - Good timing and parameters
        """)
    elif success_prob >= 0.5 or estimated_roi >= 1.5:
        st.warning("""
        ⚠️ **Consider Optimizing:**
        - Try adjusting discount percentage
        - Consider different timing (holiday season typically performs better)
        - Add campaign support if possible
        - Test in a smaller region first
        """)
    else:
        st.error("""
        ❌ **Not Recommended:**
        - Low predicted success rate
        - Poor ROI outlook
        - Consider alternative marketing tactics
        - Review category/region selection
        """)
    
    # What-if analysis
    st.markdown("---")
    st.subheader("🔧 What-If Analysis")
    st.info("**Quick Tip:** Try different discount levels to find the optimal balance between sales lift and cost")
    
    # Show comparison table for different discounts
    discount_options = [10, 15, 20, 25, 30]
    comparison_data = []
    
    for disc in discount_options:
        features_test = features.copy()
        features_test[0][2] = disc  # Update discount
        
        prob = clf.predict_proba(features_test)[0][1]
        lift = reg.predict(features_test)[0]
        pred_sales = baseline_daily_sales * (1 + lift) * duration
        cost = pred_sales * (disc / 100.0)
        inc_sales = pred_sales - baseline_total_sales
        roi = (inc_sales / cost) if cost > 0 else 0
        
        comparison_data.append({
            'Discount %': disc,
            'Success Prob': f"{prob:.1%}",
            'Sales Lift': f"{lift:+.1%}",
            'Total Sales': f"${pred_sales:,.0f}",
            'Promo Cost': f"${cost:,.0f}",
            'ROI': f"{roi:.2f}x"
        })
    
    comparison_df = pd.DataFrame(comparison_data)
    st.dataframe(comparison_df, use_container_width=True, hide_index=True)

else:
    # Initial state - show instructions
    st.info("""
    👈 **Get Started:**
    1. Fill in the promotion details in the sidebar
    2. Click "Predict ROI" to see AI-powered predictions
    3. Review the recommendations
    4. Adjust parameters to optimize your promotion
    """)
    
    # Show model stats
    st.markdown("---")
    st.subheader("📈 Model Performance")
    
    # Get model metrics from training data
    query = """
    SELECT 
        COUNT(*) AS total_promos,
        SUM(IS_SUCCESSFUL) AS successful_promos,
        AVG(SALES_LIFT_RATIO) AS avg_lift,
        AVG(ROI_PROXY) AS avg_roi
    FROM ANALYTICS.ML_PROMO_EFFECTIVENESS
    """
    stats = run_query(query)
    
    col1, col2, col3, col4 = st.columns(4)
    with col1:
        st.metric("Training Samples", f"{stats['TOTAL_PROMOS'].values[0]:,}")
    with col2:
        st.metric("Success Rate", f"{stats['SUCCESSFUL_PROMOS'].values[0] / stats['TOTAL_PROMOS'].values[0]:.1%}")
    with col3:
        st.metric("Avg Sales Lift", f"{stats['AVG_LIFT'].values[0]:+.1%}")
    with col4:
        st.metric("Avg ROI", f"{stats['AVG_ROI'].values[0]:.2f}x")
    
    st.markdown("---")
    st.markdown("""
    **How it works:**
    - 🤖 **Classification Model**: Predicts if promotion will be successful (beat baseline)
    - 📊 **Regression Model**: Predicts the exact sales lift percentage
    - 💰 **ROI Calculator**: Estimates financial return based on predictions
    - 🎯 **Trained on**: Historical promotion data from 2010-2023
    """)
