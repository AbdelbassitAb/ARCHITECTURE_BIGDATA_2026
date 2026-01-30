import streamlit as st
import pandas as pd
import snowflake.connector

@st.cache_resource
def get_conn():
    cfg = st.secrets["snowflake"]
    return snowflake.connector.connect(
        account=cfg["account"],
        user=cfg["user"],
        password=cfg["password"],
        role=cfg["role"],
        warehouse=cfg["warehouse"],
        database=cfg["database"],
        schema=cfg["schema"],
    )

@st.cache_data(ttl=300)
def run_query(sql: str, params=None) -> pd.DataFrame:
    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute(sql, params=params)
        df = cur.fetch_pandas_all()
        return df
    finally:
        cur.close()
