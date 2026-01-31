import streamlit as st
from _utils import run_query

st.title("💰 Marketing ROI")
st.caption("Analyse campagnes (proxy)")

df_roi = run_query("""
SELECT
  campaign_name,
  region,
  product_category,
  budget,
  reach,
  conversion_rate,
  (reach * conversion_rate) AS estimated_conversions,
  (reach * conversion_rate) / NULLIF(budget, 0) AS roi_proxy
FROM SILVER.MARKETING_CAMPAIGNS_CLEAN
ORDER BY roi_proxy DESC
LIMIT 50;
""")

st.caption("Top campagnes par ROI proxy — bar chart")
if not df_roi.empty:
    st.bar_chart(df_roi.head(20).set_index("CAMPAIGN_NAME")[["ROI_PROXY"]])

st.divider()

df_campaign_sales = run_query("""
WITH sales_daily AS (
  SELECT transaction_date, region, SUM(amount) AS daily_sales
  FROM SILVER.FINANCIAL_TRANSACTIONS_CLEAN
  WHERE transaction_type='Sale'
  GROUP BY transaction_date, region
)
SELECT
  c.campaign_name,
  c.region,
  CAST(SUM(s.daily_sales) AS NUMBER(18,2)) AS sales_during_campaign
FROM SILVER.MARKETING_CAMPAIGNS_CLEAN c
LEFT JOIN sales_daily s
  ON s.region = c.region
 AND s.transaction_date BETWEEN c.start_date AND c.end_date
GROUP BY c.campaign_name, c.region
ORDER BY sales_during_campaign DESC NULLS LAST
LIMIT 50;
""")

df_campaign_sales["SALES_DURING_CAMPAIGN"] = df_campaign_sales["SALES_DURING_CAMPAIGN"].astype(float)


st.caption("Top campagnes par ventes pendant campagne — bar chart")
if not df_campaign_sales.empty:
    st.bar_chart(df_campaign_sales.head(20).set_index("CAMPAIGN_NAME")[["SALES_DURING_CAMPAIGN"]])

with st.expander("Voir tables"):
    st.dataframe(df_roi, use_container_width=True)
    st.dataframe(df_campaign_sales, use_container_width=True)
