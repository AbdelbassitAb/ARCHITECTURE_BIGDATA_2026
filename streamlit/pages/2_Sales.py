import streamlit as st
import pandas as pd
from _utils import run_query

st.title("📈 Sales")
st.caption("Tendances & sanity checks")

df_month = run_query("""
SELECT DATE_TRUNC('month', transaction_date) AS month,
       SUM(amount) AS total_sales,
       COUNT(*) AS nb_sales
FROM SILVER.FINANCIAL_TRANSACTIONS_CLEAN
WHERE transaction_type='Sale'
GROUP BY month
ORDER BY month;
""")

if not df_month.empty:
    df_month["MONTH"] = pd.to_datetime(df_month["MONTH"])
    st.caption("Total Sales (mensuel) — line chart")
    st.line_chart(df_month.set_index("MONTH")[["TOTAL_SALES"]])

    st.caption("Nombre de ventes (mensuel) — line chart")
    st.line_chart(df_month.set_index("MONTH")[["NB_SALES"]])
else:
    st.info("Pas de données ventes.")

st.divider()

df_types = run_query("""
SELECT transaction_type, SUM(amount) AS total_amount
FROM SILVER.FINANCIAL_TRANSACTIONS_CLEAN
GROUP BY transaction_type
ORDER BY total_amount DESC;
""")

st.caption("Montant total par type de transaction — bar chart")
if not df_types.empty:
    st.bar_chart(df_types.set_index("TRANSACTION_TYPE")[["TOTAL_AMOUNT"]])

with st.expander("Voir tables"):
    st.dataframe(df_month, use_container_width=True)
    st.dataframe(df_types, use_container_width=True)
