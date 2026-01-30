--2.3.1 Ventes & promotions
--A) Ventes avec / sans promotion (par région + période)

WITH sales AS (
  SELECT transaction_id, transaction_date, region, amount
  FROM SILVER.FINANCIAL_TRANSACTIONS_CLEAN
  WHERE transaction_type = 'Sale'
),
sales_flag AS (
  SELECT
    s.*,
    IFF(EXISTS (
      SELECT 1
      FROM SILVER.PROMOTIONS_CLEAN p
      WHERE p.region = s.region
        AND s.transaction_date BETWEEN p.start_date AND p.end_date
    ), 1, 0) AS is_promo_period
  FROM sales s
)
SELECT
  IFF(is_promo_period=1, 'With Promotion Period', 'Without Promotion Period') AS promo_flag,
  SUM(amount) AS total_sales,
  COUNT(*) AS nb_sales
FROM sales_flag
GROUP BY promo_flag;

--B) Sensibilité des catégories aux promotions (proxy)

WITH promo_stats AS (
  SELECT
    product_category,
    region,
    AVG(discount_percentage) AS avg_discount,
    COUNT(*) AS nb_promos
  FROM SILVER.PROMOTIONS_CLEAN
  GROUP BY product_category, region
),
sales_in_promo AS (
  SELECT
    p.product_category,
    s.region,
    SUM(s.amount) AS sales_during_promo
  FROM SILVER.FINANCIAL_TRANSACTIONS_CLEAN s
  JOIN SILVER.PROMOTIONS_CLEAN p
    ON p.region = s.region
   AND s.transaction_date BETWEEN p.start_date AND p.end_date
  WHERE s.transaction_type = 'Sale'
  GROUP BY p.product_category, s.region
)
SELECT
  ps.product_category,
  ps.region,
  ps.nb_promos,
  ps.avg_discount,
  COALESCE(sp.sales_during_promo, 0) AS sales_during_promo
FROM promo_stats ps
LEFT JOIN sales_in_promo sp
  ON ps.product_category = sp.product_category
 AND ps.region = sp.region
ORDER BY sales_during_promo DESC;