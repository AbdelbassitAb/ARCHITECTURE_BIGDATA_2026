# 🤖 Machine Learning Use Cases Proposal
## AnyCompany Food & Beverage - Marketing Analytics

**Date:** January 31, 2026  
**Context:** Phase 3 - Data Product & ML Implementation

---

## 📊 Current Data Overview

### Available Data Sources (SILVER Schema)

| Table | Volume | Key Columns | Time Range |
|-------|--------|-------------|------------|
| **FINANCIAL_TRANSACTIONS_CLEAN** | ~5,000 | transaction_id, date, type, amount, region | 2010-2023 |
| **PROMOTIONS_CLEAN** | ~10,000 | promotion_id, category, region, discount%, dates | Multi-year |
| **MARKETING_CAMPAIGNS_CLEAN** | ~1,000+ | campaign_id, budget, reach, conversion_rate, dates | Multi-year |
| **CUSTOMER_DEMOGRAPHICS_CLEAN** | ~5,000 | customer_id, age, gender, income, region, marital_status | Snapshot |
| **PRODUCT_REVIEWS_CLEAN** | ~1,000+ | product_id, rating (1-5), reviewer_id, date | Multi-year |
| **CUSTOMER_SERVICE_INTERACTIONS_CLEAN** | ~3,000 | interaction_id, type, satisfaction_rating, date | Multi-year |
| **LOGISTICS_AND_SHIPPING_CLEAN** | ~1,000+ | shipment_id, ship_date, delivery_date, status, cost | Multi-year |
| **INVENTORY_CLEAN** | ~1,000+ | product_id, category, region, stock levels, restock dates | Snapshot |

### Existing ANALYTICS Tables (Phase 3)

1. **SALES_ENRICHED**: Sales with promo/campaign flags, temporal features (~1,000 rows)
2. **ACTIVE_PROMOTIONS**: Promotions with duration metrics
3. **CUSTOMERS_ENRICHED**: Demographics + income segmentation

---

## 🎯 Business Problems Identified (from Phase 2)

### Critical Issues:
1. **High Sales Volatility**: Monthly sales vary 5k-65k (13x variation) with no clear growth trend
2. **Low Promotion Impact**: Only 4% of sales occur during promotions (~37 sales vs 947 total)
3. **Weak Campaign ROI**: Budget doesn't correlate with performance; ROI varies 6-12x
4. **Market Share Loss**: Dropped from 28% → 22% in 8 months (-6 points)
5. **Budget Constraint**: Marketing budget reduced by 30%

### Goal:
**Regain +10 points market share** (22% → 32%) by T4 2025 with data-driven marketing.

---

## 🧠 Proposed ML Use Cases

---

## ✅ Use Case 1: Sales Forecasting with Promotion/Campaign Impact
**Priority:** 🔴 HIGH | **Complexity:** 🟡 MEDIUM | **Expected Impact:** +15-25% forecast accuracy

### Problem Statement
Sales are highly volatile (5k-65k monthly) with no clear pattern. Teams cannot:
- Plan inventory effectively (risk of stockouts or overstock)
- Time campaigns optimally
- Allocate marketing budget proactively

### ML Solution: Time Series Forecasting + Exogenous Variables

#### Model Type
- **Algorithm:** Prophet (Facebook) or SARIMAX or LightGBM (for regression)
- **Target:** Daily or Weekly sales amount
- **Horizon:** 4-8 weeks ahead

#### Features (Predictors)
**Temporal:**
- Day of week, month, quarter
- Lag features (sales_t-1, sales_t-7, sales_t-30)
- Rolling averages (7-day, 30-day)
- Seasonality indicators

**Exogenous (Marketing):**
- `nb_active_promos`: Count of active promotions
- `avg_discount_active`: Average discount percentage
- `nb_active_campaigns`: Count of active campaigns
- `total_campaign_budget`: Total budget deployed
- `is_holiday`: Holiday flag (to engineer)

**Contextual:**
- `region`: Categorical feature
- `product_category`: From promotions/inventory

#### Data Preparation (SQL)
```sql
CREATE OR REPLACE TABLE ANALYTICS.ML_SALES_FORECAST_FEATURES AS
WITH daily_sales AS (
  SELECT
    transaction_date AS date,
    region,
    SUM(amount) AS daily_sales,
    COUNT(*) AS nb_transactions
  FROM SILVER.FINANCIAL_TRANSACTIONS_CLEAN
  WHERE transaction_type = 'Sale'
  GROUP BY transaction_date, region
),
promo_agg AS (
  SELECT
    d.date,
    d.region,
    COUNT(DISTINCT p.promotion_id) AS nb_active_promos,
    AVG(p.discount_percentage) AS avg_discount
  FROM (SELECT DISTINCT transaction_date AS date, region FROM daily_sales) d
  LEFT JOIN SILVER.PROMOTIONS_CLEAN p
    ON d.region = p.region
   AND d.date BETWEEN p.start_date AND p.end_date
  GROUP BY d.date, d.region
),
campaign_agg AS (
  SELECT
    d.date,
    d.region,
    COUNT(DISTINCT c.campaign_id) AS nb_active_campaigns,
    SUM(c.budget) AS total_campaign_budget
  FROM (SELECT DISTINCT transaction_date AS date, region FROM daily_sales) d
  LEFT JOIN SILVER.MARKETING_CAMPAIGNS_CLEAN c
    ON d.region = p.region
   AND d.date BETWEEN c.start_date AND c.end_date
  GROUP BY d.date, d.region
)
SELECT
  s.date,
  s.region,
  s.daily_sales,
  s.nb_transactions,
  
  -- Exogenous variables
  COALESCE(p.nb_active_promos, 0) AS nb_active_promos,
  COALESCE(p.avg_discount, 0) AS avg_discount,
  COALESCE(c.nb_active_campaigns, 0) AS nb_active_campaigns,
  COALESCE(c.total_campaign_budget, 0) AS total_campaign_budget,
  
  -- Temporal features
  DAYOFWEEK(s.date) AS day_of_week,
  DATE_PART('month', s.date) AS month,
  DATE_PART('quarter', s.date) AS quarter,
  
  -- Lag features (to compute in Python/Snowpark)
  LAG(s.daily_sales, 1) OVER (PARTITION BY s.region ORDER BY s.date) AS sales_lag1,
  LAG(s.daily_sales, 7) OVER (PARTITION BY s.region ORDER BY s.date) AS sales_lag7,
  AVG(s.daily_sales) OVER (PARTITION BY s.region ORDER BY s.date ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING) AS sales_ma7
FROM daily_sales s
LEFT JOIN promo_agg p ON s.date = p.date AND s.region = p.region
LEFT JOIN campaign_agg c ON s.date = c.date AND s.region = c.region
ORDER BY s.region, s.date;
```

#### Training Strategy
1. **Train/Test Split**: 
   - Train: 2010-2022
   - Validation: 2023 H1
   - Test: 2023 H2
2. **Cross-validation**: Time series CV (walk-forward)
3. **Evaluation Metrics**:
   - RMSE, MAE, MAPE (< 20% target)
   - Directional accuracy (trend prediction)

#### Implementation (Python Pseudo-Code)
```python
from snowflake.snowpark import Session
from prophet import Prophet
import pandas as pd

# Load data
session = Session.builder.configs(connection_params).create()
df = session.table("ANALYTICS.ML_SALES_FORECAST_FEATURES").to_pandas()

# Prepare for Prophet
prophet_df = df[['date', 'daily_sales']].rename(columns={'date': 'ds', 'daily_sales': 'y'})

# Add exogenous regressors
model = Prophet(yearly_seasonality=True, weekly_seasonality=True)
model.add_regressor('nb_active_promos')
model.add_regressor('avg_discount')
model.add_regressor('nb_active_campaigns')
model.fit(prophet_df)

# Forecast next 30 days
future = model.make_future_dataframe(periods=30)
# Add future promo/campaign data (from planned calendar)
forecast = model.predict(future)

# Save predictions to Snowflake
session.write_pandas(forecast[['ds', 'yhat', 'yhat_lower', 'yhat_upper']], 
                     "ANALYTICS.SALES_FORECAST", auto_create_table=True)
```

#### Business Value
- **Better inventory planning**: Reduce stockouts by 20-30%
- **Optimal campaign timing**: Launch campaigns 1-2 weeks before predicted peaks
- **Budget allocation**: Shift budget to high-potential weeks
- **KPI**: MAPE < 20%, leading to 10-15% cost savings on inventory

#### Deployment
1. **Batch scoring**: Weekly refresh (Airflow/dbt scheduled)
2. **Dashboard**: Add "Forecast" tab in Streamlit showing next 4-8 weeks
3. **Alerts**: Email when forecast predicts >20% drop (risk mitigation)

---

## ✅ Use Case 2: Promotion Effectiveness Predictor (ROI Optimizer)
**Priority:** 🔴 HIGH | **Complexity:** 🟢 LOW-MEDIUM | **Expected Impact:** 20-30% budget savings

### Problem Statement
- Only 4% of sales occur during promotions (37 sales out of 984)
- Some categories show 0 sales despite active promotions
- No clear understanding of which promo attributes drive sales

**Question:** Which promotions will generate positive ROI before launching them?

### ML Solution: Classification + Regression (Ensemble)

#### Model Type
- **Classification Model**: Will promotion generate any sales? (Binary: Yes/No)
  - Algorithm: Logistic Regression or XGBoost
- **Regression Model**: If yes, how much sales uplift? (Continuous)
  - Algorithm: Linear Regression or Gradient Boosting

#### Features (Predictors)
**Promotion Attributes:**
- `discount_percentage`: Discount level (%)
- `promo_duration_days`: Duration in days
- `product_category`: Category (one-hot encoded)
- `region`: Region (one-hot encoded)
- `promotion_type`: Type (one-hot encoded)

**Historical Context:**
- `avg_sales_baseline`: Average sales in region/category without promo (last 30 days)
- `nb_past_promos_category`: Number of past promos in same category
- `avg_past_promo_performance`: Avg ROI of past promos in category

**Temporal:**
- `month`: Seasonality
- `is_holiday_period`: If during holidays (to engineer)

**Competition:**
- `nb_concurrent_promos`: Other promos running simultaneously in region

#### Target Engineering
```sql
CREATE OR REPLACE TABLE ANALYTICS.ML_PROMO_EFFECTIVENESS AS
WITH promo_sales AS (
  SELECT
    p.promotion_id,
    p.product_category,
    p.region,
    p.discount_percentage,
    DATEDIFF('day', p.start_date, p.end_date) AS promo_duration_days,
    p.start_date,
    
    -- Sales during promotion
    SUM(s.amount) AS sales_during_promo,
    COUNT(s.transaction_id) AS nb_sales_during_promo
  FROM SILVER.PROMOTIONS_CLEAN p
  LEFT JOIN SILVER.FINANCIAL_TRANSACTIONS_CLEAN s
    ON s.region = p.region
   AND s.transaction_date BETWEEN p.start_date AND p.end_date
   AND s.transaction_type = 'Sale'
  GROUP BY 1,2,3,4,5,6
),
baseline_sales AS (
  SELECT
    p.promotion_id,
    AVG(s.amount) AS avg_baseline_daily_sales
  FROM SILVER.PROMOTIONS_CLEAN p
  LEFT JOIN SILVER.FINANCIAL_TRANSACTIONS_CLEAN s
    ON s.region = p.region
   AND s.transaction_date BETWEEN DATEADD('day', -30, p.start_date) AND DATEADD('day', -1, p.start_date)
   AND s.transaction_type = 'Sale'
  GROUP BY p.promotion_id
)
SELECT
  ps.*,
  COALESCE(bs.avg_baseline_daily_sales, 0) AS avg_baseline_daily_sales,
  
  -- Target 1: Binary (any sales?)
  IFF(ps.nb_sales_during_promo > 0, 1, 0) AS had_sales,
  
  -- Target 2: Uplift (if sales > 0)
  CASE
    WHEN ps.nb_sales_during_promo > 0 THEN
      (ps.sales_during_promo / ps.promo_duration_days) - COALESCE(bs.avg_baseline_daily_sales, 0)
    ELSE 0
  END AS daily_sales_uplift,
  
  -- ROI proxy
  CASE
    WHEN ps.sales_during_promo > 0 THEN
      ((ps.sales_during_promo / ps.promo_duration_days) - COALESCE(bs.avg_baseline_daily_sales, 0)) / NULLIF(ps.discount_percentage, 0)
    ELSE 0
  END AS roi_proxy
FROM promo_sales ps
LEFT JOIN baseline_sales bs ON ps.promotion_id = bs.promotion_id;
```

#### Training Strategy
1. **Train/Test Split**: 80/20 stratified by `had_sales`
2. **Handle class imbalance**: SMOTE or class weights (if many promos have 0 sales)
3. **Evaluation Metrics**:
   - Classification: Precision, Recall, F1-Score, AUC-ROC
   - Regression: RMSE, R² (for uplift prediction)

#### Implementation
```python
from sklearn.ensemble import GradientBoostingClassifier, GradientBoostingRegressor
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import OneHotEncoder

# Load data
df = session.table("ANALYTICS.ML_PROMO_EFFECTIVENESS").to_pandas()

# Prepare features
categorical = ['product_category', 'region', 'promotion_type']
numerical = ['discount_percentage', 'promo_duration_days', 'avg_baseline_daily_sales']

X = pd.get_dummies(df[categorical + numerical], columns=categorical)
y_class = df['had_sales']
y_regr = df['daily_sales_uplift']

# Split
X_train, X_test, y_class_train, y_class_test = train_test_split(X, y_class, test_size=0.2, stratify=y_class)

# Train classifier
clf = GradientBoostingClassifier(n_estimators=100, max_depth=5)
clf.fit(X_train, y_class_train)

# Train regressor (only on samples with sales)
X_train_sales = X_train[y_class_train == 1]
y_regr_train_sales = y_regr[y_class_train == 1]
reg = GradientBoostingRegressor(n_estimators=100, max_depth=5)
reg.fit(X_train_sales, y_regr_train_sales)

# Predict
proba_sales = clf.predict_proba(X_test)[:, 1]
predicted_uplift = reg.predict(X_test)

# Combined prediction
df_test['predicted_roi'] = proba_sales * predicted_uplift / df_test['discount_percentage']
```

#### Business Value
- **Stop ineffective promos**: Identify promos with <10% predicted success → Save 20-30% budget
- **Optimize discount levels**: Find sweet spot (e.g., 15-20% better than 5% or 30%)
- **Category prioritization**: Focus on categories with high predicted ROI
- **What-if scenarios**: Test "What if we run promo X in region Y for 7 days?" before launch

#### Deployment
1. **Streamlit "Promo Planner" page**: 
   - Input: Category, region, discount, duration
   - Output: Predicted ROI, recommended go/no-go
2. **Batch scoring**: Score all planned promos monthly
3. **API endpoint**: Real-time scoring for marketing team

---

## ✅ Use Case 3: Customer Satisfaction Prediction (Service Quality)
**Priority:** 🟡 MEDIUM | **Complexity:** 🟢 LOW | **Expected Impact:** +10-15% satisfaction, -20% churn

### Problem Statement
- Customer service satisfaction is mediocre (avg 2.95-3.05 out of 5)
- Technical Support has lowest satisfaction (2.95)
- ~3,000 interactions but no proactive intervention

**Question:** Can we predict which interactions will result in low satisfaction and intervene?

### ML Solution: Classification (Satisfaction Prediction)

#### Model Type
- **Algorithm:** Random Forest or Logistic Regression
- **Target:** Low satisfaction (rating <= 2) vs Acceptable/High (rating >= 3)
- **Goal:** Predict BEFORE interaction closes, to escalate or add special handling

#### Features (Predictors)
**Interaction Attributes:**
- `interaction_type`: Technical Support, Order Status, Returns
- `channel`: Phone, Email, Chat (if available)
- `interaction_duration`: Minutes (to engineer from date if available)
- `is_repeat_contact`: Same customer contacted in last 30 days

**Customer Context:**
- `customer_age`: From demographics
- `customer_income_segment`: Low/Medium/High
- `customer_region`: Region
- `past_avg_satisfaction`: Customer's average past ratings

**Product/Order Context:**
- `order_value`: If linked to an order (from transactions)
- `product_category`: If applicable
- `shipping_status`: If logistics-related (Delivered, Delayed, Returned)

**Temporal:**
- `hour_of_day`: Time of interaction (morning/evening may differ)
- `day_of_week`: Weekend vs weekday

#### Target Engineering
```sql
CREATE OR REPLACE TABLE ANALYTICS.ML_SATISFACTION_PREDICTION AS
WITH interactions AS (
  SELECT
    interaction_id,
    customer_id,
    interaction_type,
    interaction_date,
    satisfaction_rating,
    resolution_status
  FROM SILVER.CUSTOMER_SERVICE_INTERACTIONS_CLEAN
),
customer_context AS (
  SELECT
    c.customer_id,
    c.age,
    c.income_segment,
    c.region,
    AVG(i.satisfaction_rating) AS past_avg_satisfaction,
    COUNT(i.interaction_id) AS past_interaction_count
  FROM ANALYTICS.CUSTOMERS_ENRICHED c
  LEFT JOIN interactions i ON c.customer_id = i.customer_id
  GROUP BY c.customer_id, c.age, c.income_segment, c.region
)
SELECT
  i.interaction_id,
  i.interaction_type,
  i.interaction_date,
  
  -- Customer features
  cc.age,
  cc.income_segment,
  cc.region,
  COALESCE(cc.past_avg_satisfaction, 3.0) AS past_avg_satisfaction,
  COALESCE(cc.past_interaction_count, 0) AS past_interaction_count,
  
  -- Temporal features
  DATE_PART('hour', i.interaction_date) AS hour_of_day,
  DAYOFWEEK(i.interaction_date) AS day_of_week,
  
  -- Target
  IFF(i.satisfaction_rating <= 2, 1, 0) AS is_low_satisfaction
FROM interactions i
LEFT JOIN customer_context cc ON i.customer_id = cc.customer_id
WHERE i.satisfaction_rating IS NOT NULL;
```

#### Training Strategy
1. **Train/Test Split**: 70/30 time-based (older data for training)
2. **Handle imbalance**: Class weights (likely fewer low-satisfaction cases)
3. **Evaluation Metrics**:
   - Precision (avoid false alarms)
   - Recall (catch most low-satisfaction cases)
   - F1-Score
   - ROC-AUC

#### Implementation
```python
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report, roc_auc_score

# Load data
df = session.table("ANALYTICS.ML_SATISFACTION_PREDICTION").to_pandas()

# Prepare
categorical = ['interaction_type', 'income_segment', 'region']
numerical = ['age', 'past_avg_satisfaction', 'past_interaction_count', 'hour_of_day', 'day_of_week']

X = pd.get_dummies(df[categorical + numerical], columns=categorical)
y = df['is_low_satisfaction']

# Train
clf = RandomForestClassifier(n_estimators=100, max_depth=10, class_weight='balanced')
clf.fit(X_train, y_train)

# Evaluate
y_pred = clf.predict(X_test)
print(classification_report(y_test, y_pred))
print(f"AUC-ROC: {roc_auc_score(y_test, clf.predict_proba(X_test)[:, 1])}")

# Feature importance
feature_importance = pd.DataFrame({
    'feature': X.columns,
    'importance': clf.feature_importances_
}).sort_values('importance', ascending=False)
```

#### Business Value
- **Proactive escalation**: Flag high-risk interactions → Route to senior agent
- **Reduce churn**: Intervene before customer leaves (offer, apology, compensation)
- **Improve training**: Identify patterns (e.g., "Technical Support + evening hours = low satisfaction")
- **KPI Target**: Increase avg satisfaction from 3.0 → 3.5+ (17% improvement)

#### Deployment
1. **Real-time scoring**: Score interaction when opened (API call)
2. **Agent dashboard**: Show "Risk Level: High/Medium/Low" to agent
3. **Automated actions**: 
   - High risk → Offer 10% discount automatically
   - High risk + repeat contact → Escalate to manager
4. **Batch reporting**: Weekly report on predicted vs actual satisfaction

---

## 📊 Comparison & Prioritization

| Use Case | Priority | Complexity | Data Readiness | Expected Impact | Time to MVP |
|----------|----------|------------|----------------|-----------------|-------------|
| **1. Sales Forecasting** | 🔴 HIGH | 🟡 MEDIUM | 90% | +15-25% accuracy → 10-15% cost savings | 3-4 weeks |
| **2. Promo ROI Optimizer** | 🔴 HIGH | 🟢 LOW-MEDIUM | 85% | 20-30% budget savings | 2-3 weeks |
| **3. Satisfaction Predictor** | 🟡 MEDIUM | 🟢 LOW | 80% | +10-15% satisfaction, -20% churn | 2 weeks |

### Recommended Implementation Order:
1. **Start with Use Case 2 (Promo Optimizer)** - Fastest ROI, addresses critical pain point (low promo effectiveness)
2. **Then Use Case 1 (Sales Forecasting)** - High impact, helps with inventory & campaign planning
3. **Finally Use Case 3 (Satisfaction)** - Important but lower immediate business impact

---

## 🛠️ Implementation Roadmap

### Phase 1: Quick Win (Weeks 1-3)
- ✅ Create `ML_PROMO_EFFECTIVENESS` table (Use Case 2)
- ✅ Train initial Promo ROI model (Gradient Boosting)
- ✅ Build simple Streamlit "Promo Planner" page
- ✅ Test with marketing team on 5-10 planned promos
- 🎯 **Milestone**: First production prediction

### Phase 2: Scale (Weeks 4-6)
- ✅ Create `ML_SALES_FORECAST_FEATURES` table (Use Case 1)
- ✅ Train Prophet model for sales forecasting
- ✅ Add "Forecast" dashboard tab in Streamlit
- ✅ Automate weekly refresh (Airflow/dbt)
- 🎯 **Milestone**: Forecasts used in weekly planning meetings

### Phase 3: Customer Experience (Weeks 7-8)
- ✅ Create `ML_SATISFACTION_PREDICTION` table (Use Case 3)
- ✅ Train Random Forest classifier
- ✅ Integrate with customer service system (API or dashboard)
- 🎯 **Milestone**: Real-time satisfaction prediction live

### Phase 4: Monitor & Optimize (Ongoing)
- 📈 Track model performance (monthly)
- 🔄 Retrain models quarterly
- 📊 A/B test recommendations
- 🎯 **Goal**: Continuous improvement, adapt to market changes

---

## 🎯 Expected Business Outcomes (12 Months)

### Financial Impact:
- **Promo Optimizer**: Save $150k-200k (20-30% of wasted promo budget)
- **Sales Forecasting**: Save $80k-120k (10-15% inventory cost reduction)
- **Satisfaction Predictor**: Retain $50k-80k (reduce churn by 20% = retain 100-150 customers)
- **Total Estimated Savings**: $280k-400k annually

### Market Share Impact:
- Better promo targeting → +2-3 points market share
- Improved customer experience → +1-2 points (loyalty & word-of-mouth)
- Optimized campaign timing → +1-2 points
- **Total Contribution to Goal**: +4-7 points (40-70% of +10 point goal)

### KPIs to Track:
| KPI | Current | Target (12mo) | ML Contribution |
|-----|---------|---------------|-----------------|
| Market Share | 22% | 32% | +4-7 points |
| Promo Success Rate | 4% | 12-15% | +8-11 points |
| Sales Forecast MAPE | N/A | <20% | Enable better planning |
| Avg Customer Satisfaction | 3.0 | 3.5+ | +0.5 points |
| Marketing Budget Efficiency | Baseline | +25-35% | ROI improvement |

---

## 📋 Technical Requirements

### Infrastructure:
- ✅ **Snowflake** (Data warehouse) - Already in place
- ✅ **Python 3.8+** with libraries:
  - pandas, numpy, scikit-learn
  - prophet (for forecasting)
  - xgboost or lightgbm (for gradient boosting)
  - snowflake-connector-python, snowflake-snowpark-python
- ✅ **Streamlit** (Dashboards) - Already in place
- 🔄 **Orchestration**: Airflow or dbt (for scheduled model retraining)
- 🔄 **Model Registry**: MLflow or Snowflake Model Registry (recommended)

### Team:
- **Data Scientist** (1 FTE): Model development, tuning, evaluation
- **Data Engineer** (0.5 FTE): Pipeline setup, feature engineering, deployment
- **ML Engineer** (0.5 FTE): Productionization, API, monitoring

### Budget:
- **Compute** (Snowflake + Python): $500-1,000/month
- **Tools** (MLflow, monitoring): $200-500/month
- **Personnel** (2 FTE): Existing team
- **Total Initial Investment**: ~$10k setup + $8-15k/month operational

**ROI**: Payback in 1-2 months (vs $280k-400k annual savings)

---

## 🚨 Risks & Mitigations

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **Insufficient historical data** | HIGH | MEDIUM | Start with simpler models; augment with external data if needed |
| **Model drift** (market changes) | MEDIUM | HIGH | Monthly monitoring, quarterly retraining |
| **Low adoption by marketing team** | HIGH | MEDIUM | Involve stakeholders early; provide training; show quick wins |
| **Integration challenges** | MEDIUM | LOW | Start with batch scoring; move to real-time gradually |
| **Overfitting to past data** | MEDIUM | MEDIUM | Cross-validation; test on recent holdout data; regularization |

---

## 📚 Next Steps

### Immediate (This Week):
1. ✅ Review this proposal with Data Science + Marketing teams
2. ✅ Secure stakeholder buy-in (CMO, Head of Data)
3. ✅ Allocate resources (1 Data Scientist, 0.5 Data Engineer)

### Week 1-2:
1. ✅ Create ML feature tables (SQL scripts provided)
2. ✅ Set up Python environment (Snowpark, scikit-learn, Prophet)
3. ✅ Start with Use Case 2 (Promo Optimizer) - Quick Win

### Week 3-4:
1. ✅ Train initial models, evaluate metrics
2. ✅ Build MVP Streamlit page "Promo Planner"
3. ✅ Test with marketing team (5-10 real promos)

### Month 2-3:
1. ✅ Refine models based on feedback
2. ✅ Implement Use Case 1 (Forecasting)
3. ✅ Automate pipelines (Airflow/dbt)
4. ✅ Production deployment

---

**Author:** Data Science & Engineering Team  
**Status:** 📝 Proposal - Awaiting Approval  
**Expected Start Date:** Week of February 3, 2026
