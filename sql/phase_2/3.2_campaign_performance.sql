--2.3.2 Marketing & performance commerciale
--A) Lien campagnes ↔ ventes (par région + période)

WITH sales_daily AS (
  SELECT
    transaction_date,
    region,
    SUM(amount) AS daily_sales
  FROM SILVER.FINANCIAL_TRANSACTIONS_CLEAN
  WHERE transaction_type = 'Sale'
  GROUP BY transaction_date, region
),
campaign_sales AS (
  SELECT
    c.campaign_id,
    c.campaign_name,
    c.region,
    c.start_date,
    c.end_date,
    c.budget,
    c.reach,
    c.conversion_rate,
    SUM(s.daily_sales) AS sales_during_campaign
  FROM SILVER.MARKETING_CAMPAIGNS_CLEAN c
  LEFT JOIN sales_daily s
    ON s.region = c.region
   AND s.transaction_date BETWEEN c.start_date AND c.end_date
  GROUP BY
    c.campaign_id, c.campaign_name, c.region, c.start_date, c.end_date,
    c.budget, c.reach, c.conversion_rate
)
SELECT *
FROM campaign_sales
ORDER BY sales_during_campaign DESC NULLS LAST;


--B) Campagnes les plus efficaces (ROI proxy)
SELECT
  campaign_name,
  region,
  product_category,
  budget,
  reach,
  conversion_rate,
  (reach * conversion_rate) AS estimated_conversions,
  (reach * conversion_rate) / NULLIF(budget, 0) AS roi_proxy
FROM SILVER.MARKETING_CAMPAIGNS_CLEAN
ORDER BY roi_proxy DESC
LIMIT 20;
