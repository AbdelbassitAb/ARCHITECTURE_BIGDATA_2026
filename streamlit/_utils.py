import streamlit as st
import pandas as pd
import snowflake.connector

# ------------------------------------------------------------
# Connexion Snowflake (LOCAL) via .streamlit/secrets.toml
# ------------------------------------------------------------
@st.cache_resource
def get_conn():
    cfg = st.secrets["snowflake"]
    conn = snowflake.connector.connect(
        account=cfg["account"],
        user=cfg["user"],
        password=cfg["password"],
        role=cfg.get("role"),
        warehouse=cfg.get("warehouse"),
        database=cfg.get("database"),
        schema=cfg.get("schema"),
    )
    return conn

# ------------------------------------------------------------
# Helper SQL
# ------------------------------------------------------------
@st.cache_data(ttl=300)
def run_query(sql: str) -> pd.DataFrame:
    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute(sql)
        return cur.fetch_pandas_all()
    finally:
        cur.close()

# ------------------------------------------------------------
# Helpers formatting & casting (ceux qui te manquent)
# ------------------------------------------------------------
def safe_float(x, default=0.0):
    try:
        return default if x is None else float(x)
    except:
        return default

def safe_int(x, default=0):
    try:
        return default if x is None else int(x)
    except:
        return default

def fmt_money(x: float) -> str:
    try:
        return f"{x:,.0f}".replace(",", " ")
    except:
        return str(x)
