import streamlit as st
from _utils import run_query

st.set_page_config(page_title="Operations & Logistics", layout="wide")
st.title("Operations & Logistics – Stock & Delivery")

# --- Stock alerts ---
stock_sql = """
SELECT
  product_category,
  region,
  COUNT(*) AS nb_stock_alerts
FROM INVENTORY_CLEAN
WHERE current_stock IS NOT NULL
  AND reorder_point IS NOT NULL
  AND current_stock <= reorder_point
GROUP BY product_category, region
ORDER BY nb_stock_alerts DESC;
"""
stock = run_query(stock_sql)

st.subheader("Stock alerts (current_stock <= reorder_point)")
st.dataframe(stock, use_container_width=True)

# --- Delivery delays ---
delay_sql = """
SELECT
  status,
  AVG(DATEDIFF('day', ship_date, estimated_delivery)) AS avg_delivery_days,
  COUNT(*) AS nb_shipments
FROM LOGISTICS_AND_SHIPPING_CLEAN
WHERE ship_date IS NOT NULL
  AND estimated_delivery IS NOT NULL
GROUP BY status
ORDER BY avg_delivery_days DESC;
"""
delay = run_query(delay_sql)

st.subheader("Average delivery time by status")
st.dataframe(delay, use_container_width=True)
st.bar_chart(delay.set_index("STATUS")["AVG_DELIVERY_DAYS"])
