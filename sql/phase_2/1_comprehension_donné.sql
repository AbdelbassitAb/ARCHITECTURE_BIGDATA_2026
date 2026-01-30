--2.1 – Compréhension des jeux de données (table par table)

--2.1.1 SILVER.FINANCIAL_TRANSACTIONS_CLEAN (Ventes)

--Volume & période
SELECT COUNT(*) AS nb_rows FROM SILVER.FINANCIAL_TRANSACTIONS_CLEAN;

SELECT MIN(transaction_date) AS min_date, MAX(transaction_date) AS max_date
FROM SILVER.FINANCIAL_TRANSACTIONS_CLEAN;

--Valeurs manquantes / anomalies

SELECT
  SUM(IFF(transaction_id IS NULL, 1, 0)) AS null_id,
  SUM(IFF(transaction_date IS NULL, 1, 0)) AS null_date,
  SUM(IFF(region IS NULL, 1, 0)) AS null_region,
  SUM(IFF(amount IS NULL, 1, 0)) AS null_amount,
  SUM(IFF(amount <= 0, 1, 0)) AS non_positive_amount
FROM SILVER.FINANCIAL_TRANSACTIONS_CLEAN;

--2.1.2 SILVER.PROMOTIONS_CLEAN (Promotions)

--Volume & période
SELECT COUNT(*) AS nb_rows FROM SILVER.PROMOTIONS_CLEAN;

SELECT MIN(start_date) AS min_start, MAX(end_date) AS max_end
FROM SILVER.PROMOTIONS_CLEAN;

--Valeurs manquantes / anomalies

SELECT
  SUM(IFF(promotion_id IS NULL, 1, 0)) AS null_id,
  SUM(IFF(product_category IS NULL, 1, 0)) AS null_category,
  SUM(IFF(region IS NULL, 1, 0)) AS null_region,
  SUM(IFF(start_date IS NULL OR end_date IS NULL, 1, 0)) AS null_dates,
  SUM(IFF(start_date > end_date, 1, 0)) AS bad_date_range,
  SUM(IFF(discount_percentage < 0 OR discount_percentage > 1 OR discount_percentage IS NULL, 1, 0)) AS bad_discount
FROM SILVER.PROMOTIONS_CLEAN;


--2.1.3 SILVER.MARKETING_CAMPAIGNS_CLEAN (Marketing)

--Volume & période
SELECT COUNT(*) AS nb_rows FROM SILVER.MARKETING_CAMPAIGNS_CLEAN;

SELECT MIN(start_date) AS min_start, MAX(end_date) AS max_end
FROM SILVER.MARKETING_CAMPAIGNS_CLEAN;

--Valeurs manquantes / anomalies

SELECT
  SUM(IFF(campaign_id IS NULL, 1, 0)) AS null_id,
  SUM(IFF(region IS NULL, 1, 0)) AS null_region,
  SUM(IFF(product_category IS NULL, 1, 0)) AS null_category,
  SUM(IFF(budget IS NULL OR budget <= 0, 1, 0)) AS bad_budget,
  SUM(IFF(reach IS NULL OR reach < 0, 1, 0)) AS bad_reach,
  SUM(IFF(conversion_rate IS NULL OR conversion_rate < 0 OR conversion_rate > 1, 1, 0)) AS bad_conversion
FROM SILVER.MARKETING_CAMPAIGNS_CLEAN;


--2.1.4 SILVER.CUSTOMER_DEMOGRAPHICS_CLEAN (Clients)

--Volume & période (DOB)

SELECT COUNT(*) AS nb_rows FROM SILVER.CUSTOMER_DEMOGRAPHICS_CLEAN;

SELECT MIN(date_of_birth) AS min_dob, MAX(date_of_birth) AS max_dob
FROM SILVER.CUSTOMER_DEMOGRAPHICS_CLEAN;


--Valeurs manquantes / anomalies
SELECT
  SUM(IFF(customer_id IS NULL, 1, 0)) AS null_id,
  SUM(IFF(region IS NULL, 1, 0)) AS null_region,
  SUM(IFF(annual_income IS NULL, 1, 0)) AS null_income,
  SUM(IFF(annual_income < 0, 1, 0)) AS negative_income
FROM SILVER.CUSTOMER_DEMOGRAPHICS_CLEAN;

--2.1.5 SILVER.PRODUCT_REVIEWS_CLEAN (Avis)

--Volume & période
SELECT COUNT(*) AS nb_rows FROM SILVER.PRODUCT_REVIEWS_CLEAN;

SELECT MIN(review_date) AS min_date, MAX(review_date) AS max_date
FROM SILVER.PRODUCT_REVIEWS_CLEAN;

--Valeurs manquantes / anomalies

SELECT
  SUM(IFF(product_id IS NULL, 1, 0)) AS null_product_id,
  SUM(IFF(review_date IS NULL, 1, 0)) AS null_date,
  SUM(IFF(rating IS NULL, 1, 0)) AS null_rating,
  SUM(IFF(rating < 1 OR rating > 5, 1, 0)) AS bad_rating
FROM SILVER.PRODUCT_REVIEWS_CLEAN;

--2.1.6 SILVER.CUSTOMER_SERVICE_INTERACTIONS_CLEAN (Service client)

--Volume & période

SELECT COUNT(*) AS nb_rows FROM SILVER.CUSTOMER_SERVICE_INTERACTIONS_CLEAN;

SELECT MIN(interaction_date) AS min_date, MAX(interaction_date) AS max_date
FROM SILVER.CUSTOMER_SERVICE_INTERACTIONS_CLEAN;

--Valeurs manquantes / anomalies

SELECT
  SUM(IFF(customer_satisfaction IS NULL, 1, 0)) AS null_satisfaction,
  SUM(IFF(duration_minutes IS NULL, 1, 0)) AS null_duration
FROM SILVER.CUSTOMER_SERVICE_INTERACTIONS_CLEAN;

--2.1.7 SILVER.LOGISTICS_AND_SHIPPING_CLEAN (Logistique)

--Volume & période
SELECT COUNT(*) AS nb_rows FROM SILVER.LOGISTICS_AND_SHIPPING_CLEAN;

SELECT MIN(ship_date) AS min_ship, MAX(ship_date) AS max_ship
FROM SILVER.LOGISTICS_AND_SHIPPING_CLEAN;

--Valeurs manquantes / anomalies

SELECT
  SUM(IFF(ship_date IS NULL OR estimated_delivery IS NULL, 1, 0)) AS missing_dates,
  SUM(IFF(shipping_cost IS NULL, 1, 0)) AS missing_cost
FROM SILVER.LOGISTICS_AND_SHIPPING_CLEAN;


--2.1.8 SILVER.INVENTORY_CLEAN (Stock)

--Volume & période

SELECT COUNT(*) AS nb_rows FROM SILVER.INVENTORY_CLEAN;

SELECT MIN(last_restock_date) AS min_restock, MAX(last_restock_date) AS max_restock
FROM SILVER.INVENTORY_CLEAN;


--Valeurs manquantes / anomalies

SELECT
  SUM(IFF(current_stock IS NULL OR reorder_point IS NULL, 1, 0)) AS missing_stock_fields,
  SUM(IFF(current_stock < 0 OR reorder_point < 0 OR lead_time < 0, 1, 0)) AS negative_values
FROM SILVER.INVENTORY_CLEAN;