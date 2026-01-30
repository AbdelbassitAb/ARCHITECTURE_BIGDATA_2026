import streamlit as st
from _utils import run_query

st.set_page_config(page_title="Promotion Analysis", layout="wide")
st.title("Promotion Analysis – Impact promotions")

# --- Filtres ---
region = st.text_input("Filter region (optional)", "")

region_filter = ""
if region.strip():
    region_filter = "AND s.region = %s"

# --- Ventes avec/sans promotion (proxy) ---
flag_sql = f"""
WITH sales AS (
  SELECT transaction_id, transaction_date, region, amount
  FROM FINANCIAL_TRANSACTIONS_CLEAN
  WHERE transaction_type = 'Sale'
),
sales_flag AS (
  SELECT
    s.*,
    IFF(EXISTS (
      SELECT 1
      FROM PROMOTIONS_CLEAN p
      WHERE p.region = s.region
        AND s.transaction_date BETWEEN p.start_date AND p.end_date
    ), 1, 0) AS is_promo_period
  FROM sales s
  WHERE 1=1 {region_filter}
)
SELECT
  IFF(is_promo_period=1, 'With Promotion Period', 'Without Promotion Period') AS promo_flag,
  SUM(amount) AS total_sales,
  COUNT(*) AS nb_sales
FROM sales_flag
GROUP BY promo_flag;
"""

params = (region,) if region.strip() else None
flag = run_query(flag_sql, params=params)

c1, c2 = st.columns(2)
with c1:
    st.subheader("Sales with/without promotion period")
    st.dataframe(flag, use_container_width=True)
with c2:
    # petit bar chart
    flag_chart = flag.set_index("PROMO_FLAG")["TOTAL_SALES"]
    st.bar_chart(flag_chart)

# --- Catégories les plus promues ---
cat_sql = """
SELECT
  product_category,
  COUNT(*) AS nb_promos,
  AVG(discount_percentage) AS avg_discount
FROM PROMOTIONS_CLEAN
GROUP BY product_category
ORDER BY nb_promos DESC;
"""
cats = run_query(cat_sql)

st.subheader("Most promoted categories")
st.dataframe(cats, use_container_width=True)
st.bar_chart(cats.set_index("PRODUCT_CATEGORY")["NB_PROMOS"])
