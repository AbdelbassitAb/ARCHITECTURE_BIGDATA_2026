import streamlit as st

st.set_page_config(page_title="AnyCompany Analytics", layout="wide")

st.title("AnyCompany – Marketing Analytics (Snowflake + Streamlit)")
st.write(
    """
Bienvenue dans l’application d’analytics.
Utilise le menu à gauche pour naviguer entre les dashboards.

**Dashboards disponibles :**
- Sales Dashboard (tendances & régions)
- Promotion Analysis (impact des promotions)
- Marketing ROI (campagnes les plus efficaces)
- Customer Segmentation (segments démographiques)
- Operations & Logistics (stocks & délais)
- **🆕 Promo Planner** (AI-powered ROI predictions)
"""
)

st.info("Navigation : clique sur une page dans le menu latéral (à gauche).")
