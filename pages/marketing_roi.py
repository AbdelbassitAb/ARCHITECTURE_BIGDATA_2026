import streamlit as st
from _utils import run_query

st.set_page_config(page_title="Marketing ROI", layout="wide")
st.title("Marketing ROI – Campagnes les plus efficaces (ROI proxy)")

sql = """
SELECT
  campaign_name,
  region,
  product_category,
  budget,
  reach,
  conversion_rate,
  (reach * conversion_rate) AS estimated_conversions,
  (reach * conversion_rate) / NULLIF(budget, 0) AS roi_proxy
FROM MARKETING_CAMPAIGNS_CLEAN
ORDER BY roi_proxy DESC
LIMIT 50;
"""
df = run_query(sql)

st.subheader("Top campaigns (ROI proxy)")
st.dataframe(df, use_container_width=True)

st.subheader("ROI proxy by campaign (top 20)")
top20 = df.head(20).set_index("CAMPAIGN_NAME")["ROI_PROXY"]
st.bar_chart(top20)
