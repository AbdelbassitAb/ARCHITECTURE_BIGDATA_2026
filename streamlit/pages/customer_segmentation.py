import streamlit as st
from _utils import run_query

st.set_page_config(page_title="Customer Segmentation", layout="wide")
st.title("Customer Segmentation – Démographie")

region_sql = """
SELECT region, COUNT(*) AS nb_clients, AVG(annual_income) AS avg_income
FROM CUSTOMER_DEMOGRAPHICS_CLEAN
GROUP BY region
ORDER BY nb_clients DESC;
"""
gender_sql = """
SELECT gender, COUNT(*) AS nb_clients
FROM CUSTOMER_DEMOGRAPHICS_CLEAN
GROUP BY gender
ORDER BY nb_clients DESC;
"""
marital_sql = """
SELECT marital_status, COUNT(*) AS nb_clients
FROM CUSTOMER_DEMOGRAPHICS_CLEAN
GROUP BY marital_status
ORDER BY nb_clients DESC;
"""

by_region = run_query(region_sql)
by_gender = run_query(gender_sql)
by_marital = run_query(marital_sql)

c1, c2 = st.columns(2)
with c1:
    st.subheader("Clients by region")
    st.dataframe(by_region, use_container_width=True)
    st.bar_chart(by_region.set_index("REGION")["NB_CLIENTS"])
with c2:
    st.subheader("Average income by region")
    st.bar_chart(by_region.set_index("REGION")["AVG_INCOME"])

c3, c4 = st.columns(2)
with c3:
    st.subheader("Clients by gender")
    st.dataframe(by_gender, use_container_width=True)
with c4:
    st.subheader("Clients by marital status")
    st.dataframe(by_marital, use_container_width=True)
