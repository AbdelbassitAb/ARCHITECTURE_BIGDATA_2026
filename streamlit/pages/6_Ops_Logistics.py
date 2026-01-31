import streamlit as st
from _utils import run_query

st.title("🚚 Ops & Logistics")
st.caption("Stock alerts & delivery performance")

df_stock_cat = run_query("""
SELECT product_category, COUNT(*) AS nb_stock_alerts
FROM SILVER.INVENTORY_CLEAN
WHERE current_stock IS NOT NULL
  AND reorder_point IS NOT NULL
  AND current_stock <= reorder_point
GROUP BY product_category
ORDER BY nb_stock_alerts DESC;
""")

df_delivery = run_query("""
SELECT status,
       AVG(DATEDIFF('day', ship_date, estimated_delivery)) AS avg_delivery_days,
       COUNT(*) AS nb_shipments
FROM SILVER.LOGISTICS_AND_SHIPPING_CLEAN
WHERE ship_date IS NOT NULL
  AND estimated_delivery IS NOT NULL
GROUP BY status
ORDER BY avg_delivery_days DESC;
""")

df_delivery["AVG_DELIVERY_DAYS"] = df_delivery["AVG_DELIVERY_DAYS"].astype(float)


left, right = st.columns(2)

with left:
    st.caption("Alertes stock par catégorie — bar chart")
    if not df_stock_cat.empty:
        st.bar_chart(df_stock_cat.set_index("PRODUCT_CATEGORY")[["NB_STOCK_ALERTS"]])
    else:
        st.info("Pas d'alertes stock détectées.")

with right:
    st.caption("Délais moyens de livraison (jours) par statut — bar chart")
    if not df_delivery.empty:
        st.bar_chart(df_delivery.set_index("STATUS")[["AVG_DELIVERY_DAYS"]])
    else:
        st.info("Pas de données délais livraison.")

with st.expander("Voir tables"):
    st.dataframe(df_stock_cat, use_container_width=True)
    st.dataframe(df_delivery, use_container_width=True)
