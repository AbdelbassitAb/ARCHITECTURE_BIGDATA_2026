import streamlit as st
import pandas as pd
from _utils import run_query, safe_float, safe_int, fmt_money

st.title("🏠 Overview")
st.caption("KPIs & visualisations rapides")

kpi = run_query("""
SELECT
  SUM(IFF(transaction_type='Sale', amount, 0)) AS total_sales,
  COUNT_IF(transaction_type='Sale') AS nb_sales,
  COUNT(DISTINCT region) AS nb_regions
FROM SILVER.FINANCIAL_TRANSACTIONS_CLEAN;
""")

total_sales = safe_float(kpi.loc[0, "TOTAL_SALES"]) if not kpi.empty else 0.0
nb_sales = safe_int(kpi.loc[0, "NB_SALES"]) if not kpi.empty else 0
nb_regions = safe_int(kpi.loc[0, "NB_REGIONS"]) if not kpi.empty else 0

promo_rate_df = run_query("""
WITH sales AS (
  SELECT transaction_id, transaction_date, region
  FROM SILVER.FINANCIAL_TRANSACTIONS_CLEAN
  WHERE transaction_type='Sale'
),
flagged AS (
  SELECT
    s.*,
    IFF(EXISTS (
      SELECT 1
      FROM SILVER.PROMOTIONS_CLEAN p
      WHERE p.region = s.region
        AND s.transaction_date BETWEEN p.start_date AND p.end_date
    ), 1, 0) AS is_promo
  FROM sales s
)
SELECT AVG(is_promo)::FLOAT AS promo_rate
FROM flagged;
""")
promo_rate = safe_float(promo_rate_df.loc[0, "PROMO_RATE"]) if not promo_rate_df.empty else 0.0

c1, c2, c3, c4 = st.columns(4)
c1.metric("Total Sales", fmt_money(total_sales))
c2.metric("Nb ventes (Sale)", f"{nb_sales:,}".replace(",", " "))
c3.metric("Nb régions", f"{nb_regions:,}".replace(",", " "))
c4.metric("Part ventes en période promo", f"{promo_rate*100:.1f}%")

st.divider()

df_month = run_query("""
SELECT DATE_TRUNC('month', transaction_date) AS month,
       SUM(amount) AS total_sales
FROM SILVER.FINANCIAL_TRANSACTIONS_CLEAN
WHERE transaction_type='Sale'
GROUP BY month
ORDER BY month;
""")

df_regions = run_query("""
SELECT region, SUM(amount) AS total_sales
FROM SILVER.FINANCIAL_TRANSACTIONS_CLEAN
WHERE transaction_type='Sale'
GROUP BY region
ORDER BY total_sales DESC;
""")

left, right = st.columns(2)

with left:
    st.caption("Tendance des ventes (mensuel) — line chart")
    if not df_month.empty:
        df_month["MONTH"] = pd.to_datetime(df_month["MONTH"])
        st.line_chart(df_month.set_index("MONTH")[["TOTAL_SALES"]])
    else:
        st.info("Pas de données ventes.")

with right:
    st.caption("Ventes par région — bar chart")
    if not df_regions.empty:
        st.bar_chart(df_regions.set_index("REGION")[["TOTAL_SALES"]])
    else:
        st.info("Pas de données régions.")

with st.expander("Voir les données"):
    st.dataframe(df_month, use_container_width=True)
    st.dataframe(df_regions, use_container_width=True)
