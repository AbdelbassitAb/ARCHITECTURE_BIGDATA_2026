import streamlit as st
from _utils import run_query

st.title("🏷️ Promotions")
st.caption("Volume & discount")

df_cat = run_query("""
SELECT
  product_category,
  COUNT(*) AS nb_promos,
  AVG(discount_percentage) AS avg_discount
FROM SILVER.PROMOTIONS_CLEAN
GROUP BY product_category
ORDER BY nb_promos DESC;
""")

c1, c2 = st.columns(2)

with c1:
    st.caption("Nombre de promotions par catégorie — bar chart")
    if not df_cat.empty:
        st.bar_chart(df_cat.set_index("PRODUCT_CATEGORY")[["NB_PROMOS"]])

with c2:
    st.caption("Discount moyen par catégorie — bar chart")
    if not df_cat.empty:
        st.bar_chart(df_cat.set_index("PRODUCT_CATEGORY")[["AVG_DISCOUNT"]])

st.divider()

df_region = run_query("""
SELECT region, COUNT(*) AS nb_promos
FROM SILVER.PROMOTIONS_CLEAN
GROUP BY region
ORDER BY nb_promos DESC;
""")

st.caption("Nombre de promotions par région — bar chart")
if not df_region.empty:
    st.bar_chart(df_region.set_index("REGION")[["NB_PROMOS"]])

with st.expander("Voir tables"):
    st.dataframe(df_cat, use_container_width=True)
    st.dataframe(df_region, use_container_width=True)
