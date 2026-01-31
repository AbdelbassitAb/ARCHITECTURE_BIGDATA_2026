-- ÉTAPE 5 – Data Cleanning


-------------------------------------------------------------------------

--Table 1 — BRONZE.FINANCIAL_TRANSACTIONS → SILVER.FINANCIAL_TRANSACTIONS_CLEAN


-- Nulls sur colonnes clés
SELECT
  SUM(IFF(transaction_id IS NULL OR TRIM(transaction_id) = '', 1, 0)) AS null_transaction_id,
  SUM(IFF(transaction_date IS NULL, 1, 0)) AS null_transaction_date,
  SUM(IFF(amount IS NULL, 1, 0)) AS null_amount,
  SUM(IFF(region IS NULL OR TRIM(region) = '', 1, 0)) AS null_region
FROM BRONZE.FINANCIAL_TRANSACTIONS;



-- Création de la table SILVER (nettoyage)

CREATE OR REPLACE TABLE SILVER.FINANCIAL_TRANSACTIONS_CLEAN AS
SELECT
  TRIM(transaction_id) AS transaction_id,
  /* si transaction_date est déjà DATE, TRY_TO_DATE ne casse pas */
  TRY_TO_DATE(transaction_date::VARCHAR) AS transaction_date,
  TRIM(transaction_type) AS transaction_type,
  TRY_TO_DECIMAL(REPLACE(amount::VARCHAR, ' ', ''), 18, 2) AS amount,
  TRIM(payment_method) AS payment_method,
  TRIM(entity) AS entity,
  NULLIF(TRIM(region), '') AS region,
  TRIM(account_code) AS account_code
FROM BRONZE.FINANCIAL_TRANSACTIONS
WHERE transaction_id IS NOT NULL
  AND TRIM(transaction_id) <> ''
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY TRIM(transaction_id)
  ORDER BY TRY_TO_DATE(transaction_date::VARCHAR) DESC NULLS LAST
) = 1;

--Filtre qualité montant (à appliquer après création)
DELETE FROM SILVER.FINANCIAL_TRANSACTIONS_CLEAN
WHERE amount IS NULL OR amount <= 0;

-- Contrôles post-clean (SILVER)

-- Volume BRONZE vs SILVER
SELECT
  (SELECT COUNT(*) FROM BRONZE.FINANCIAL_TRANSACTIONS) AS bronze_rows,
  (SELECT COUNT(*) FROM SILVER.FINANCIAL_TRANSACTIONS_CLEAN) AS silver_rows;



-- Montants valides
SELECT
  SUM(IFF(amount IS NULL, 1, 0)) AS null_amount,
  MIN(amount) AS min_amount,
  MAX(amount) AS max_amount
FROM SILVER.FINANCIAL_TRANSACTIONS_CLEAN;



--------------------------------------------------------------
--Table 2 — BRONZE.PROMOTIONS_DATA → SILVER.PROMOTIONS_CLEAN



-- Nulls sur colonnes clés
SELECT
  SUM(IFF(promotion_id IS NULL OR TRIM(promotion_id) = '', 1, 0)) AS null_promotion_id,
  SUM(IFF(product_category IS NULL OR TRIM(product_category) = '', 1, 0)) AS null_product_category,
  SUM(IFF(start_date IS NULL, 1, 0)) AS null_start_date,
  SUM(IFF(end_date IS NULL, 1, 0)) AS null_end_date,
  SUM(IFF(region IS NULL OR TRIM(region) = '', 1, 0)) AS null_region,
  SUM(IFF(discount_percentage IS NULL, 1, 0)) AS null_discount
FROM BRONZE.PROMOTIONS_DATA;


-- Création de la table SILVER (nettoyage)
CREATE OR REPLACE TABLE SILVER.PROMOTIONS_CLEAN AS
SELECT
  TRIM(promotion_id) AS promotion_id,
  NULLIF(TRIM(product_category), '') AS product_category,
  NULLIF(TRIM(promotion_type), '') AS promotion_type,
  TRY_TO_DOUBLE(discount_percentage) AS discount_percentage,
  TRY_TO_DATE(start_date::VARCHAR) AS start_date,
  TRY_TO_DATE(end_date::VARCHAR) AS end_date,
  NULLIF(TRIM(region), '') AS region
FROM BRONZE.PROMOTIONS_DATA
WHERE promotion_id IS NOT NULL
  AND TRIM(promotion_id) <> ''
  AND TRY_TO_DATE(start_date::VARCHAR) IS NOT NULL
  AND TRY_TO_DATE(end_date::VARCHAR) IS NOT NULL
  AND TRY_TO_DATE(start_date::VARCHAR) <= TRY_TO_DATE(end_date::VARCHAR)
  AND TRY_TO_DOUBLE(discount_percentage) BETWEEN 0 AND 1
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY TRIM(promotion_id)
  ORDER BY TRY_TO_DATE(start_date::VARCHAR) DESC NULLS LAST
) = 1;

--Contrôles post-clean (SILVER)
SELECT
  (SELECT COUNT(*) FROM BRONZE.PROMOTIONS_DATA) AS bronze_rows,
  (SELECT COUNT(*) FROM SILVER.PROMOTIONS_CLEAN) AS silver_rows;


-- -----------------------------------------------------
--Table 3 — BRONZE.MARKETING_CAMPAIGNS → SILVER.MARKETING_CAMPAIGNS_CLEAN


--Nulls sur colonnes clés
SELECT
  SUM(IFF(campaign_id IS NULL OR TRIM(campaign_id) = '', 1, 0)) AS null_campaign_id,
  SUM(IFF(start_date IS NULL, 1, 0)) AS null_start_date,
  SUM(IFF(end_date IS NULL, 1, 0)) AS null_end_date,
  SUM(IFF(region IS NULL OR TRIM(region) = '', 1, 0)) AS null_region,
  SUM(IFF(budget IS NULL, 1, 0)) AS null_budget,
  SUM(IFF(reach IS NULL, 1, 0)) AS null_reach,
  SUM(IFF(conversion_rate IS NULL, 1, 0)) AS null_conversion
FROM BRONZE.MARKETING_CAMPAIGNS;





CREATE OR REPLACE TABLE SILVER.MARKETING_CAMPAIGNS_CLEAN AS
SELECT
  TRIM(campaign_id) AS campaign_id,
  NULLIF(TRIM(campaign_name), '') AS campaign_name,
  NULLIF(TRIM(campaign_type), '') AS campaign_type,
  NULLIF(TRIM(product_category), '') AS product_category,
  NULLIF(TRIM(target_audience), '') AS target_audience,
  TRY_TO_DATE(start_date::VARCHAR) AS start_date,
  TRY_TO_DATE(end_date::VARCHAR) AS end_date,
  NULLIF(TRIM(region), '') AS region,
  TRY_TO_DECIMAL(REPLACE(budget::VARCHAR, ' ', ''), 18, 2) AS budget,
  TRY_TO_NUMBER(REPLACE(reach::VARCHAR, ' ', '')) AS reach,
  IFF(TRY_TO_DOUBLE(conversion_rate) BETWEEN 0 AND 1, TRY_TO_DOUBLE(conversion_rate), NULL) AS conversion_rate
FROM BRONZE.MARKETING_CAMPAIGNS
WHERE campaign_id IS NOT NULL
  AND TRIM(campaign_id) <> ''
  AND TRY_TO_DATE(start_date::VARCHAR) IS NOT NULL
  AND TRY_TO_DATE(end_date::VARCHAR) IS NOT NULL
  AND TRY_TO_DATE(start_date::VARCHAR) <= TRY_TO_DATE(end_date::VARCHAR)
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY
    TRIM(campaign_id),
    TRY_TO_DATE(start_date::VARCHAR),
    TRY_TO_DATE(end_date::VARCHAR),
    NULLIF(TRIM(region), ''),
    NULLIF(TRIM(campaign_type), ''),
    NULLIF(TRIM(product_category), ''),
    NULLIF(TRIM(target_audience), '')
  ORDER BY
    TRY_TO_DECIMAL(REPLACE(budget::VARCHAR, ' ', ''), 18, 2) DESC NULLS LAST,
    TRY_TO_NUMBER(REPLACE(reach::VARCHAR, ' ', '')) DESC NULLS LAST
) = 1;

DELETE FROM SILVER.MARKETING_CAMPAIGNS_CLEAN
WHERE budget IS NULL OR budget <= 0
   OR reach IS NULL OR reach < 0;

--C1) Volume BRONZE vs SILVER

SELECT
  (SELECT COUNT(*) FROM BRONZE.MARKETING_CAMPAIGNS) AS bronze_rows,
  (SELECT COUNT(*) FROM SILVER.MARKETING_CAMPAIGNS_CLEAN) AS silver_rows;




-------------------------------------------------------------

--Table 4 — BRONZE.PRODUCT_REVIEWS → SILVER.PRODUCT_REVIEWS_CLEAN

-- Vérifier rating (1..5)
SELECT
  COUNT(*) AS total,
  SUM(IFF(TRY_TO_NUMBER(rating::VARCHAR) BETWEEN 1 AND 5, 0, 1)) AS invalid_rating
FROM BRONZE.PRODUCT_REVIEWS
WHERE rating IS NOT NULL;
--Voir exemples invalides :
SELECT review_id, rating
FROM BRONZE.PRODUCT_REVIEWS
WHERE TRY_TO_NUMBER(rating::VARCHAR) IS NULL
   OR TRY_TO_NUMBER(rating::VARCHAR) NOT BETWEEN 1 AND 5
LIMIT 50;


--B) Création de la table SILVER (nettoyage)

CREATE OR REPLACE TABLE SILVER.PRODUCT_REVIEWS_CLEAN AS
SELECT
  TRY_TO_NUMBER(review_id::VARCHAR) AS review_id,
  NULLIF(TRIM(product_id), '') AS product_id,
  NULLIF(TRIM(reviewer_id), '') AS reviewer_id,
  NULLIF(TRIM(reviewer_name), '') AS reviewer_name,
  TRY_TO_NUMBER(rating::VARCHAR) AS rating,

  /* date : si timestamp, on le convertit puis on prend la date */
  COALESCE(
    TRY_TO_DATE(review_date::VARCHAR),
    TO_DATE(TRY_TO_TIMESTAMP_NTZ(review_date::VARCHAR))
  ) AS review_date,

  NULLIF(TRIM(review_title), '') AS review_title,
  review_text AS review_text,
  COALESCE(NULLIF(TRIM(product_category), ''), 'Unknown') AS product_category
FROM BRONZE.PRODUCT_REVIEWS
WHERE NULLIF(TRIM(product_id), '') IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY
    /* clé de dédoublonnage robuste */
    COALESCE(TRY_TO_NUMBER(review_id::VARCHAR)::VARCHAR, 'NA'),
    NULLIF(TRIM(product_id), ''),
    NULLIF(TRIM(reviewer_id), ''),
    COALESCE(NULLIF(TRIM(review_title), ''), 'NA'),
    COALESCE(
      TRY_TO_DATE(review_date::VARCHAR)::VARCHAR,
      TO_DATE(TRY_TO_TIMESTAMP_NTZ(review_date::VARCHAR))::VARCHAR,
      'NA'
    )
  ORDER BY
    /* on garde la version la plus complète */
    IFF(review_text IS NULL OR TRIM(review_text) = '', 0, 1) DESC
) = 1;


DELETE FROM SILVER.PRODUCT_REVIEWS_CLEAN
WHERE rating < 1
   OR rating > 5;

--Volume BRONZE vs SILVER

SELECT
  (SELECT COUNT(*) FROM BRONZE.PRODUCT_REVIEWS) AS bronze_rows,
  (SELECT COUNT(*) FROM SILVER.PRODUCT_REVIEWS_CLEAN) AS silver_rows;


-------------------------------------------------------------------------
--Table 5 — BRONZE.CUSTOMER_DEMOGRAPHICS → SILVER.CUSTOMER_DEMOGRAPHICS_CLEAN


-- Nulls sur colonnes clés

SELECT
  SUM(IFF(customer_id IS NULL, 1, 0)) AS null_customer_id,
  SUM(IFF(name IS NULL OR TRIM(name) = '', 1, 0)) AS null_name,
  SUM(IFF(region IS NULL OR TRIM(region) = '', 1, 0)) AS null_region,
  SUM(IFF(country IS NULL OR TRIM(country) = '', 1, 0)) AS null_country,
  SUM(IFF(city IS NULL OR TRIM(city) = '', 1, 0)) AS null_city
FROM BRONZE.CUSTOMER_DEMOGRAPHICS;



-- Création de la table SILVER (nettoyage)

CREATE OR REPLACE TABLE SILVER.CUSTOMER_DEMOGRAPHICS_CLEAN AS
WITH base AS (
  SELECT
    customer_id::NUMBER AS customer_id,
    NULLIF(TRIM(name), '') AS name,
    TRY_TO_DATE(date_of_birth::VARCHAR) AS date_of_birth,
    NULLIF(TRIM(gender), '') AS gender,
    NULLIF(TRIM(region), '') AS region,
    NULLIF(TRIM(country), '') AS country,
    NULLIF(TRIM(city), '') AS city,
    NULLIF(TRIM(marital_status), '') AS marital_status,
    TRY_TO_DECIMAL(REPLACE(annual_income::VARCHAR, ' ', ''), 18, 2) AS annual_income,

    /* score de complétude : plus il est grand, mieux c’est */
    (
      IFF(NULLIF(TRIM(name), '') IS NULL, 0, 1) +
      IFF(TRY_TO_DATE(date_of_birth::VARCHAR) IS NULL, 0, 1) +
      IFF(NULLIF(TRIM(country), '') IS NULL, 0, 1) +
      IFF(NULLIF(TRIM(city), '') IS NULL, 0, 1) +
      IFF(TRY_TO_DECIMAL(REPLACE(annual_income::VARCHAR, ' ', ''), 18, 2) IS NULL, 0, 1)
    ) AS completeness_score
  FROM BRONZE.CUSTOMER_DEMOGRAPHICS
  WHERE customer_id IS NOT NULL
)
SELECT
  customer_id,
  name,
  date_of_birth,
  gender,
  region,
  country,
  city,
  marital_status,
  annual_income
FROM base
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY customer_id
  ORDER BY completeness_score DESC
) = 1;

--Règles qualité post-création (optionnel mais propre) revenus négatifs → supprimés / 
DELETE FROM SILVER.CUSTOMER_DEMOGRAPHICS_CLEAN
WHERE annual_income < 0;

-- Volume BRONZE vs SILVER
SELECT
  (SELECT COUNT(*) FROM BRONZE.CUSTOMER_DEMOGRAPHICS) AS bronze_rows,
  (SELECT COUNT(*) FROM SILVER.CUSTOMER_DEMOGRAPHICS_CLEAN) AS silver_rows;


------------------------------------------------------------------------------------
--Table 6 — BRONZE.LOGISTICS_AND_SHIPPING → SILVER.LOGISTICS_AND_SHIPPING_CLEAN


-- Création de la table SILVER (nettoyage)

CREATE OR REPLACE TABLE SILVER.LOGISTICS_AND_SHIPPING_CLEAN AS
SELECT
  TRIM(shipment_id) AS shipment_id,
  NULLIF(TRIM(order_id), '') AS order_id,
  TRY_TO_DATE(ship_date::VARCHAR) AS ship_date,
  TRY_TO_DATE(estimated_delivery::VARCHAR) AS estimated_delivery,
  NULLIF(TRIM(shipping_method), '') AS shipping_method,
  NULLIF(TRIM(status), '') AS status,
  TRY_TO_DECIMAL(REPLACE(shipping_cost::VARCHAR, ' ', ''), 18, 2) AS shipping_cost,
  NULLIF(TRIM(destination_region), '') AS destination_region,
  NULLIF(TRIM(destination_country), '') AS destination_country,
  NULLIF(TRIM(carrier), '') AS carrier
FROM BRONZE.LOGISTICS_AND_SHIPPING
WHERE shipment_id IS NOT NULL
  AND TRIM(shipment_id) <> ''
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY TRIM(shipment_id)
  ORDER BY TRY_TO_DATE(ship_date::VARCHAR) DESC NULLS LAST
) = 1;

--Règles qualité post-création
--Supprimer coûts négatifs
DELETE FROM SILVER.LOGISTICS_AND_SHIPPING_CLEAN
WHERE shipping_cost < 0;

--Corriger les dates incohérentes (livraison avant expédition)
UPDATE SILVER.LOGISTICS_AND_SHIPPING_CLEAN
SET estimated_delivery = NULL
WHERE ship_date IS NOT NULL
  AND estimated_delivery IS NOT NULL
  AND estimated_delivery < ship_date;


--C) Contrôles post-clean (SILVER)
--C1) Volume BRONZE vs SILVER
SELECT
  (SELECT COUNT(*) FROM BRONZE.LOGISTICS_AND_SHIPPING) AS bronze_rows,
  (SELECT COUNT(*) FROM SILVER.LOGISTICS_AND_SHIPPING_CLEAN) AS silver_rows;


--Table 7 — BRONZE.CUSTOMER_SERVICE_INTERACTIONS → SILVER.CUSTOMER_SERVICE_INTERACTIONS_CLEAN

-- Création de la table SILVER (nettoyage)
CREATE OR REPLACE TABLE SILVER.CUSTOMER_SERVICE_INTERACTIONS_CLEAN AS
SELECT
  TRIM(interaction_id) AS interaction_id,
  TRY_TO_DATE(interaction_date::VARCHAR) AS interaction_date,
  NULLIF(TRIM(interaction_type), '') AS interaction_type,
  NULLIF(TRIM(issue_category), '') AS issue_category,
  description AS description,

  /* durée : si hors plage, on met NULL */
  IFF(duration_minutes BETWEEN 0 AND 600, duration_minutes, NULL) AS duration_minutes,

  NULLIF(TRIM(resolution_status), '') AS resolution_status,

  /* follow_up_required -> boolean */
  IFF(UPPER(TRIM(follow_up_required)) IN ('YES','Y','TRUE','1'), TRUE, FALSE) AS follow_up_required,

  /* satisfaction : si hors 1..5 => NULL */
  IFF(customer_satisfaction BETWEEN 1 AND 5, customer_satisfaction, NULL) AS customer_satisfaction

FROM BRONZE.CUSTOMER_SERVICE_INTERACTIONS
WHERE interaction_id IS NOT NULL
  AND TRIM(interaction_id) <> ''
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY TRIM(interaction_id)
  ORDER BY TRY_TO_DATE(interaction_date::VARCHAR) DESC NULLS LAST
) = 1;


----------------------------------------------------------------------

--Table 8 — BRONZE.SUPPLIER_INFORMATION → SILVER.SUPPLIER_INFORMATION_CLEAN


-- Création de la table SILVER (nettoyage)
CREATE OR REPLACE TABLE SILVER.SUPPLIER_INFORMATION_CLEAN AS
WITH base AS (
  SELECT
    TRIM(supplier_id) AS supplier_id,
    NULLIF(TRIM(supplier_name), '') AS supplier_name,
    NULLIF(TRIM(product_category), '') AS product_category,
    NULLIF(TRIM(region), '') AS region,
    NULLIF(TRIM(country), '') AS country,
    NULLIF(TRIM(city), '') AS city,

    IFF(lead_time BETWEEN 0 AND 365, lead_time, NULL) AS lead_time,
    IFF(reliability_score BETWEEN 0 AND 1, reliability_score, NULL) AS reliability_score,
    NULLIF(TRIM(quality_rating), '') AS quality_rating,

    /* score de complétude */
    (
      IFF(NULLIF(TRIM(supplier_name), '') IS NULL, 0, 1) +
      IFF(NULLIF(TRIM(product_category), '') IS NULL, 0, 1) +
      IFF(IFF(lead_time BETWEEN 0 AND 365, lead_time, NULL) IS NULL, 0, 1) +
      IFF(IFF(reliability_score BETWEEN 0 AND 1, reliability_score, NULL) IS NULL, 0, 1) +
      IFF(NULLIF(TRIM(quality_rating), '') IS NULL, 0, 1)
    ) AS completeness_score
  FROM BRONZE.SUPPLIER_INFORMATION
  WHERE supplier_id IS NOT NULL
    AND TRIM(supplier_id) <> ''
)
SELECT
  supplier_id,
  supplier_name,
  product_category,
  region,
  country,
  city,
  lead_time,
  reliability_score,
  quality_rating
FROM base
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY supplier_id
  ORDER BY completeness_score DESC
) = 1;

--C1) Volume BRONZE vs SILVER
SELECT
  (SELECT COUNT(*) FROM BRONZE.SUPPLIER_INFORMATION) AS bronze_rows,
  (SELECT COUNT(*) FROM SILVER.SUPPLIER_INFORMATION_CLEAN) AS silver_rows;


----------------------------------------------------------------------------------
--Table 9 — BRONZE.EMPLOYEE_RECORDS → SILVER.EMPLOYEE_RECORDS_CLEAN
--A) Profiling BRONZE (avant nettoyage)

-- Création de la table SILVER (nettoyage)

CREATE OR REPLACE TABLE SILVER.EMPLOYEE_RECORDS_CLEAN AS
WITH base AS (
  SELECT
    TRIM(employee_id) AS employee_id,
    NULLIF(TRIM(name), '') AS name,
    TRY_TO_DATE(date_of_birth::VARCHAR) AS date_of_birth,
    TRY_TO_DATE(hire_date::VARCHAR) AS hire_date,
    NULLIF(TRIM(department), '') AS department,
    NULLIF(TRIM(job_title), '') AS job_title,
    TRY_TO_DECIMAL(REPLACE(salary::VARCHAR, ' ', ''), 18, 2) AS salary,
    NULLIF(TRIM(region), '') AS region,
    NULLIF(TRIM(country), '') AS country,
    NULLIF(REPLACE(TRIM(email), 'mailto:', ''), '') AS email,

    (
      IFF(NULLIF(TRIM(name), '') IS NULL, 0, 1) +
      IFF(TRY_TO_DATE(hire_date::VARCHAR) IS NULL, 0, 1) +
      IFF(TRY_TO_DECIMAL(REPLACE(salary::VARCHAR, ' ', ''), 18, 2) IS NULL, 0, 1) +
      IFF(NULLIF(REPLACE(TRIM(email), 'mailto:', ''), '') IS NULL, 0, 1)
    ) AS completeness_score
  FROM BRONZE.EMPLOYEE_RECORDS
  WHERE employee_id IS NOT NULL
    AND TRIM(employee_id) <> ''
)
SELECT
  employee_id,
  name,
  date_of_birth,
  hire_date,
  department,
  job_title,
  salary,
  region,
  country,
  email
FROM base
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY employee_id
  ORDER BY completeness_score DESC, hire_date DESC NULLS LAST
) = 1;

--Règles qualité post-création
--Salaire doit être > 0 :
DELETE FROM SILVER.EMPLOYEE_RECORDS_CLEAN
WHERE salary IS NULL OR salary <= 0;



--Volume BRONZE vs SILVER
SELECT
  (SELECT COUNT(*) FROM BRONZE.EMPLOYEE_RECORDS) AS bronze_rows,
  (SELECT COUNT(*) FROM SILVER.EMPLOYEE_RECORDS_CLEAN) AS silver_rows;


-- -----------------------------------------------------
--Table 10 — BRONZE.INVENTORY_RAW (JSON) → SILVER.INVENTORY_CLEAN

--B) Création de la table SILVER (parsing + nettoyage)

CREATE OR REPLACE TABLE SILVER.INVENTORY_CLEAN AS
WITH parsed AS (
  SELECT
    NULLIF(TRIM(raw:product_id::STRING), '') AS product_id,
    NULLIF(TRIM(raw:product_category::STRING), '') AS product_category,
    NULLIF(TRIM(raw:region::STRING), '') AS region,
    NULLIF(TRIM(raw:country::STRING), '') AS country,
    NULLIF(TRIM(raw:warehouse::STRING), '') AS warehouse,

    TRY_TO_NUMBER(raw:current_stock::STRING) AS current_stock,
    TRY_TO_NUMBER(raw:reorder_point::STRING) AS reorder_point,
    TRY_TO_NUMBER(raw:lead_time::STRING) AS lead_time,

    TRY_TO_DATE(raw:last_restock_date::STRING) AS last_restock_date
  FROM BRONZE.INVENTORY_RAW
)
SELECT *
FROM parsed
WHERE product_id IS NOT NULL
  AND (current_stock IS NULL OR current_stock >= 0)
  AND (reorder_point IS NULL OR reorder_point >= 0)
  AND (lead_time IS NULL OR lead_time >= 0)
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY product_id, region, country, warehouse
  ORDER BY last_restock_date DESC NULLS LAST
) = 1;

--C1) Volume BRONZE vs SILVER

SELECT
  (SELECT COUNT(*) FROM BRONZE.INVENTORY_RAW) AS bronze_rows,
  (SELECT COUNT(*) FROM SILVER.INVENTORY_CLEAN) AS silver_rows;

-------------------------------------------------------------------------------------------
--Table 11 — BRONZE.STORE_LOCATIONS_RAW (JSON) → SILVER.STORE_LOCATIONS_CLEAN

--Création de la table SILVER (parsing + nettoyage)

CREATE OR REPLACE TABLE SILVER.STORE_LOCATIONS_CLEAN AS
WITH parsed AS (
  SELECT
    NULLIF(TRIM(raw:store_id::STRING), '') AS store_id,
    NULLIF(TRIM(raw:store_name::STRING), '') AS store_name,
    NULLIF(TRIM(raw:store_type::STRING), '') AS store_type,
    NULLIF(TRIM(raw:region::STRING), '') AS region,
    NULLIF(TRIM(raw:country::STRING), '') AS country,
    NULLIF(TRIM(raw:city::STRING), '') AS city,
    NULLIF(TRIM(raw:address::STRING), '') AS address,
    NULLIF(TRIM(raw:postal_code::STRING), '') AS postal_code,

    /* qualité : valeurs positives */
    IFF(TRY_TO_DOUBLE(raw:square_footage::STRING) > 0,
        TRY_TO_DOUBLE(raw:square_footage::STRING),
        NULL) AS square_footage,

    IFF(TRY_TO_NUMBER(raw:employee_count::STRING) >= 0,
        TRY_TO_NUMBER(raw:employee_count::STRING),
        NULL) AS employee_count,

    /* score de complétude pour choisir la meilleure ligne par store_id */
    (
      IFF(NULLIF(TRIM(raw:store_name::STRING), '') IS NULL, 0, 1) +
      IFF(NULLIF(TRIM(raw:country::STRING), '') IS NULL, 0, 1) +
      IFF(NULLIF(TRIM(raw:city::STRING), '') IS NULL, 0, 1) +
      IFF(TRY_TO_DOUBLE(raw:square_footage::STRING) > 0, 1, 0) +
      IFF(TRY_TO_NUMBER(raw:employee_count::STRING) >= 0, 1, 0)
    ) AS completeness_score
  FROM BRONZE.STORE_LOCATIONS_RAW
)
SELECT
  store_id,
  store_name,
  store_type,
  region,
  country,
  city,
  address,
  postal_code,
  square_footage,
  employee_count
FROM parsed
WHERE store_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY store_id
  ORDER BY completeness_score DESC
) = 1;

--C) Contrôles post-clean (SILVER)
--C1) Volume BRONZE vs SILVER
SELECT
  (SELECT COUNT(*) FROM BRONZE.STORE_LOCATIONS_RAW) AS bronze_rows,
  (SELECT COUNT(*) FROM SILVER.STORE_LOCATIONS_CLEAN) AS silver_rows;

