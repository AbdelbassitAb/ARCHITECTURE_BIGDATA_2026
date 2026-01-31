--🚀 Phase 3 – Data Product & Machine Learning

--🧩 Partie 3.1 – Création du Data Product (ANALYTICS)

CREATE SCHEMA IF NOT EXISTS ANALYTICS;

--🧱 Table 1 – ANALYTICS.SALES_ENRICHED

CREATE OR REPLACE TABLE ANALYTICS.SALES_ENRICHED AS
WITH sales AS (
  SELECT
    transaction_id,
    transaction_date,
    region,
    amount
  FROM SILVER.FINANCIAL_TRANSACTIONS_CLEAN
  WHERE transaction_type = 'Sale'
),

promo_flag AS (
  SELECT
    s.transaction_id,
    MAX(1) AS is_promo_period
  FROM sales s
  JOIN SILVER.PROMOTIONS_CLEAN p
    ON s.region = p.region
   AND s.transaction_date BETWEEN p.start_date AND p.end_date
  GROUP BY s.transaction_id
),

campaign_flag AS (
  SELECT
    s.transaction_id,
    MAX(1) AS is_campaign_period
  FROM sales s
  JOIN SILVER.MARKETING_CAMPAIGNS_CLEAN c
    ON s.region = c.region
   AND s.transaction_date BETWEEN c.start_date AND c.end_date
  GROUP BY s.transaction_id
)

SELECT
  s.transaction_id,
  s.transaction_date,
  s.region,
  s.amount,

  COALESCE(p.is_promo_period, 0) AS is_promo_period,
  COALESCE(c.is_campaign_period, 0) AS is_campaign_period,

  DATE_TRUNC('month', s.transaction_date) AS sales_month,
  DAYOFWEEK(s.transaction_date) AS day_of_week
FROM sales s
LEFT JOIN promo_flag p ON s.transaction_id = p.transaction_id
LEFT JOIN campaign_flag c ON s.transaction_id = c.transaction_id;


--🧱 Table 2 – ANALYTICS.ACTIVE_PROMOTIONS

CREATE OR REPLACE TABLE ANALYTICS.ACTIVE_PROMOTIONS AS
SELECT
  promotion_id,
  product_category,
  region,
  discount_percentage,
  start_date,
  end_date,
  DATEDIFF('day', start_date, end_date) AS promo_duration_days
FROM SILVER.PROMOTIONS_CLEAN;


--🧱 Table 3 – ANALYTICS.CUSTOMERS_ENRICHED

CREATE OR REPLACE TABLE ANALYTICS.CUSTOMERS_ENRICHED AS
SELECT
  customer_id,
  region,
  country,
  gender,
  marital_status,
  annual_income,
  DATE_PART(year, CURRENT_DATE) - DATE_PART(year, date_of_birth) AS age,
  CASE
    WHEN annual_income < 40000 THEN 'Low'
    WHEN annual_income BETWEEN 40000 AND 100000 THEN 'Medium'
    ELSE 'High'
  END AS income_segment
FROM SILVER.CUSTOMER_DEMOGRAPHICS_CLEAN;


--✅ Vérifications – Cohérence métier

SELECT COUNT(*) FROM ANALYTICS.SALES_ENRICHED;
SELECT COUNT(*) FROM ANALYTICS.ACTIVE_PROMOTIONS;
SELECT COUNT(*) FROM ANALYTICS.CUSTOMERS_ENRICHED;

--2️⃣ Vérifier les flags

SELECT
  is_promo_period,
  is_campaign_period,
  COUNT(*) AS cnt
FROM ANALYTICS.SALES_ENRICHED
GROUP BY is_promo_period, is_campaign_period;
