import streamlit as st
import pandas as pd
from _utils import run_query

st.set_page_config(page_title="Sales Dashboard", layout="wide")
st.title("Sales Dashboard – Tendances & Régions")

# --- Filtres ---
tx_type = st.selectbox("Transaction type", ["Sale", "All"], index=0)

where_type = "WHERE transaction_type = 'Sale'" if tx_type == "Sale" else "WHERE 1=1"

# --- KPI global ---
kpi_sql = f"""
SELECT
  SUM(amount) AS total_sales,
  COUNT(*) AS nb_transactions,
  COUNT(DISTINCT region) AS nb_regions
FROM FINANCIAL_TRANSACTIONS_CLEAN
{where_type};
"""
kpi = run_query(kpi_sql).iloc[0]

c1, c2, c3 = st.columns(3)
c1.metric("Total sales", f"{float(kpi['TOTAL_SALES']):,.2f}")
c2.metric("Transactions", int(kpi["NB_TRANSACTIONS"]))
c3.metric("Regions", int(kpi["NB_REGIONS"]))

# --- Ventes mensuelles ---
trend_sql = f"""
SELECT
  DATE_TRUNC('month', transaction_date) AS month,
  SUM(amount) AS total_sales
FROM FINANCIAL_TRANSACTIONS_CLEAN
{where_type}
GROUP BY month
ORDER BY month;
"""
trend = run_query(trend_sql)
trend["MONTH"] = pd.to_datetime(trend["MONTH"])

st.subheader("Sales over time (monthly)")
st.line_chart(trend.set_index("MONTH")["TOTAL_SALES"])

# --- Performance par région ---
region_sql = f"""
SELECT
  region,
  SUM(amount) AS total_sales,
  COUNT(*) AS nb_sales
FROM FINANCIAL_TRANSACTIONS_CLEAN
{where_type}
GROUP BY region
ORDER BY total_sales DESC;
"""
by_region = run_query(region_sql)

st.subheader("Sales by region")
left, right = st.columns([1, 1])

with left:
    st.bar_chart(by_region.set_index("REGION")["TOTAL_SALES"])
with right:
    st.dataframe(by_region, use_container_width=True)
