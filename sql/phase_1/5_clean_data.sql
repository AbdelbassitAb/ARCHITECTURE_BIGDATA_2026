-------------------------------------------------------------------------

--Table 1 — BRONZE.FINANCIAL_TRANSACTIONS → SILVER.FINANCIAL_TRANSACTIONS_CLEAN

--A1) Schéma
DESC TABLE BRONZE.FINANCIAL_TRANSACTIONS;

--A2) Volume
SELECT COUNT(*) AS nb_rows
FROM BRONZE.FINANCIAL_TRANSACTIONS;

--A3) Échantillon
SELECT *
FROM BRONZE.FINANCIAL_TRANSACTIONS
LIMIT 20;

--A4) Nulls sur colonnes clés
SELECT
  SUM(IFF(transaction_id IS NULL OR TRIM(transaction_id) = '', 1, 0)) AS null_transaction_id,
  SUM(IFF(transaction_date IS NULL, 1, 0)) AS null_transaction_date,
  SUM(IFF(amount IS NULL, 1, 0)) AS null_amount,
  SUM(IFF(region IS NULL OR TRIM(region) = '', 1, 0)) AS null_region
FROM BRONZE.FINANCIAL_TRANSACTIONS;

--A5) Doublons sur transaction_id
SELECT
  COUNT(*) AS total,
  COUNT(DISTINCT transaction_id) AS distinct_ids,
  COUNT(*) - COUNT(DISTINCT transaction_id) AS duplicate_rows
FROM BRONZE.FINANCIAL_TRANSACTIONS;


--B) Création de la table SILVER (nettoyage)

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

--C) Contrôles post-clean (SILVER)

--C1) Volume BRONZE vs SILVER
SELECT
  (SELECT COUNT(*) FROM BRONZE.FINANCIAL_TRANSACTIONS) AS bronze_rows,
  (SELECT COUNT(*) FROM SILVER.FINANCIAL_TRANSACTIONS_CLEAN) AS silver_rows;

--C2) Clé unique OK ?
SELECT
  COUNT(*) AS total,
  COUNT(DISTINCT transaction_id) AS distinct_ids
FROM SILVER.FINANCIAL_TRANSACTIONS_CLEAN;

--C3) Montants valides
SELECT
  SUM(IFF(amount IS NULL, 1, 0)) AS null_amount,
  MIN(amount) AS min_amount,
  MAX(amount) AS max_amount
FROM SILVER.FINANCIAL_TRANSACTIONS_CLEAN;

--C4) Période couverte
SELECT
  MIN(transaction_date) AS min_date,
  MAX(transaction_date) AS max_date
FROM SILVER.FINANCIAL_TRANSACTIONS_CLEAN;

--------------------------------------------------------------
--Table 2 — BRONZE.PROMOTIONS_DATA → SILVER.PROMOTIONS_CLEAN
--A) Profiling BRONZE (avant nettoyage)
--A1) Schéma

DESC TABLE BRONZE.PROMOTIONS_DATA;

--A2) Volume
SELECT COUNT(*) AS nb_rows
FROM BRONZE.PROMOTIONS_DATA;

--A3) Échantillon
SELECT *
FROM BRONZE.PROMOTIONS_DATA
LIMIT 20;

--A4) Nulls sur colonnes clés
SELECT
  SUM(IFF(promotion_id IS NULL OR TRIM(promotion_id) = '', 1, 0)) AS null_promotion_id,
  SUM(IFF(product_category IS NULL OR TRIM(product_category) = '', 1, 0)) AS null_product_category,
  SUM(IFF(start_date IS NULL, 1, 0)) AS null_start_date,
  SUM(IFF(end_date IS NULL, 1, 0)) AS null_end_date,
  SUM(IFF(region IS NULL OR TRIM(region) = '', 1, 0)) AS null_region,
  SUM(IFF(discount_percentage IS NULL, 1, 0)) AS null_discount
FROM BRONZE.PROMOTIONS_DATA;

--A5) Doublons sur promotion_id

SELECT
  COUNT(*) AS total,
  COUNT(DISTINCT promotion_id) AS distinct_ids,
  COUNT(*) - COUNT(DISTINCT promotion_id) AS duplicate_rows
FROM BRONZE.PROMOTIONS_DATA;



--A6) Contrôles qualité métier
--Dates incohérentes (start_date > end_date) :
SELECT *
FROM BRONZE.PROMOTIONS_DATA
WHERE start_date > end_date
LIMIT 50;

--Discount hors plage (on attend 0 à 1) :
SELECT discount_percentage
FROM BRONZE.PROMOTIONS_DATA
WHERE TRY_TO_DOUBLE(discount_percentage) IS NULL
   OR TRY_TO_DOUBLE(discount_percentage) < 0
   OR TRY_TO_DOUBLE(discount_percentage) > 1
LIMIT 50;

--B) Création de la table SILVER (nettoyage)
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

--C) Contrôles post-clean (SILVER)
SELECT
  (SELECT COUNT(*) FROM BRONZE.PROMOTIONS_DATA) AS bronze_rows,
  (SELECT COUNT(*) FROM SILVER.PROMOTIONS_CLEAN) AS silver_rows;

--C2) Clé unique OK ?
SELECT
  COUNT(*) AS total,
  COUNT(DISTINCT promotion_id) AS distinct_ids
FROM SILVER.PROMOTIONS_CLEAN;

--C3) Discount OK ?
SELECT
  MIN(discount_percentage) AS min_disc,
  MAX(discount_percentage) AS max_disc
FROM SILVER.PROMOTIONS_CLEAN;

--C4) Dates OK ?
SELECT COUNT(*) AS bad_date_rows
FROM SILVER.PROMOTIONS_CLEAN
WHERE start_date > end_date;

--C5) Valeurs manquantes critiques
SELECT
  SUM(IFF(product_category IS NULL, 1, 0)) AS null_product_category,
  SUM(IFF(region IS NULL, 1, 0)) AS null_region
FROM SILVER.PROMOTIONS_CLEAN;

-- -----------------------------------------------------
--Table 3 — BRONZE.MARKETING_CAMPAIGNS → SILVER.MARKETING_CAMPAIGNS_CLEAN
--A) Profiling BRONZE (avant nettoyage)
--A1) Schéma
DESC TABLE BRONZE.MARKETING_CAMPAIGNS;

--A2) Volume
SELECT COUNT(*) AS nb_rows
FROM BRONZE.MARKETING_CAMPAIGNS;

--A3) Échantillon
SELECT *
FROM BRONZE.MARKETING_CAMPAIGNS
LIMIT 20;

--A4) Nulls sur colonnes clés
SELECT
  SUM(IFF(campaign_id IS NULL OR TRIM(campaign_id) = '', 1, 0)) AS null_campaign_id,
  SUM(IFF(start_date IS NULL, 1, 0)) AS null_start_date,
  SUM(IFF(end_date IS NULL, 1, 0)) AS null_end_date,
  SUM(IFF(region IS NULL OR TRIM(region) = '', 1, 0)) AS null_region,
  SUM(IFF(budget IS NULL, 1, 0)) AS null_budget,
  SUM(IFF(reach IS NULL, 1, 0)) AS null_reach,
  SUM(IFF(conversion_rate IS NULL, 1, 0)) AS null_conversion
FROM BRONZE.MARKETING_CAMPAIGNS;

--A5) Doublons sur campaign_id
SELECT
  COUNT(*) AS total,
  COUNT(DISTINCT campaign_id) AS distinct_ids,
  COUNT(*) - COUNT(DISTINCT campaign_id) AS duplicate_rows
FROM BRONZE.MARKETING_CAMPAIGNS;

--A6) Contrôles qualité métier
--Dates incohérentes (start_date > end_date) :
SELECT *
FROM BRONZE.MARKETING_CAMPAIGNS
WHERE TRY_TO_DATE(start_date::VARCHAR) > TRY_TO_DATE(end_date::VARCHAR)
LIMIT 50;
--Budget invalide (<=0 ou non convertible si texte) :
SELECT campaign_id, budget
FROM BRONZE.MARKETING_CAMPAIGNS
WHERE TRY_TO_DECIMAL(REPLACE(budget::VARCHAR, ' ', ''), 18, 2) IS NULL
   OR TRY_TO_DECIMAL(REPLACE(budget::VARCHAR, ' ', ''), 18, 2) <= 0
LIMIT 50;
--Reach invalide (non numérique) :
SELECT campaign_id, reach
FROM BRONZE.MARKETING_CAMPAIGNS
WHERE TRY_TO_NUMBER(REPLACE(reach::VARCHAR, ' ', '')) IS NULL
LIMIT 50;
--Conversion rate hors plage (on attend 0..1) :
SELECT campaign_id, conversion_rate
FROM BRONZE.MARKETING_CAMPAIGNS
WHERE TRY_TO_DOUBLE(conversion_rate) IS NULL
   OR TRY_TO_DOUBLE(conversion_rate) < 0
   OR TRY_TO_DOUBLE(conversion_rate) > 1
LIMIT 50;

SELECT campaign_id, COUNT(*) AS cnt
FROM BRONZE.MARKETING_CAMPAIGNS
GROUP BY campaign_id
HAVING COUNT(*) > 1
ORDER BY cnt DESC;

SELECT *
FROM BRONZE.MARKETING_CAMPAIGNS
WHERE campaign_id = 'CAMP73432'
ORDER BY start_date DESC, end_date DESC;


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

--C2) Clé unique OK ?
SELECT
  COUNT(*) AS total,
  COUNT(DISTINCT campaign_id) AS distinct_ids
FROM SILVER.MARKETING_CAMPAIGNS_CLEAN;

--C3) Conversion rate OK ?
SELECT
  MIN(conversion_rate) AS min_conv,
  MAX(conversion_rate) AS max_conv
FROM SILVER.MARKETING_CAMPAIGNS_CLEAN;

--C4) Dates OK ?
SELECT COUNT(*) AS bad_date_rows
FROM SILVER.MARKETING_CAMPAIGNS_CLEAN
WHERE start_date > end_date;

--C5) Nulls sur champs utiles
SELECT
  SUM(IFF(product_category IS NULL, 1, 0)) AS null_product_category,
  SUM(IFF(target_audience IS NULL, 1, 0)) AS null_target_audience,
  SUM(IFF(region IS NULL, 1, 0)) AS null_region
FROM SILVER.MARKETING_CAMPAIGNS_CLEAN;


-------------------------------------------------------------

--Table 4 — BRONZE.PRODUCT_REVIEWS → SILVER.PRODUCT_REVIEWS_CLEAN
--A) Profiling BRONZE (avant nettoyage)
--A1) Schéma
DESC TABLE BRONZE.PRODUCT_REVIEWS;

--A2) Volume

SELECT COUNT(*) AS nb_rows
FROM BRONZE.PRODUCT_REVIEWS;

--A3) Échantillon (important)
SELECT *
FROM BRONZE.PRODUCT_REVIEWS
LIMIT 20;

--A4) Vérifier si review_id est bien numérique
SELECT
  COUNT(*) AS total,
  SUM(IFF(TRY_TO_NUMBER(review_id::VARCHAR) IS NULL, 1, 0)) AS not_numeric_review_id
FROM BRONZE.PRODUCT_REVIEWS;

--A5) Vérifier rating (1..5)
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

--A6) Vérifier dates (date ou timestamp)
SELECT
  COUNT(*) AS total,
  SUM(IFF(TRY_TO_DATE(review_date::VARCHAR) IS NULL 
          AND TRY_TO_TIMESTAMP_NTZ(review_date::VARCHAR) IS NULL, 1, 0)) AS invalid_date
FROM BRONZE.PRODUCT_REVIEWS
WHERE review_date IS NOT NULL;
--Voir exemples :
SELECT review_id, review_date
FROM BRONZE.PRODUCT_REVIEWS
WHERE TRY_TO_DATE(review_date::VARCHAR) IS NULL
  AND TRY_TO_TIMESTAMP_NTZ(review_date::VARCHAR) IS NULL
LIMIT 50;

--A7) Vérifier la colonne product_category (souvent manquante)
SELECT
  SUM(IFF(product_category IS NULL OR TRIM(product_category) = '', 1, 0)) AS missing_product_category,
  COUNT(*) AS total
FROM BRONZE.PRODUCT_REVIEWS;

--A8) Doublons (clé candidate)
SELECT
  COUNT(*) AS total,
  COUNT(DISTINCT TRY_TO_NUMBER(review_id::VARCHAR)) AS distinct_review_id
FROM BRONZE.PRODUCT_REVIEWS;

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

--C) Contrôles post-clean (SILVER)
--C1) Volume BRONZE vs SILVER

SELECT
  (SELECT COUNT(*) FROM BRONZE.PRODUCT_REVIEWS) AS bronze_rows,
  (SELECT COUNT(*) FROM SILVER.PRODUCT_REVIEWS_CLEAN) AS silver_rows;

--C2) Rating OK

SELECT
  MIN(rating) AS min_rating,
  MAX(rating) AS max_rating,
  SUM(IFF(rating IS NULL, 1, 0)) AS null_rating
FROM SILVER.PRODUCT_REVIEWS_CLEAN;

--C3) Date OK

SELECT
  MIN(review_date) AS min_date,
  MAX(review_date) AS max_date,
  SUM(IFF(review_date IS NULL, 1, 0)) AS null_dates
FROM SILVER.PRODUCT_REVIEWS_CLEAN;

--C4) product_category manquante ?

SELECT
  SUM(IFF(product_category = 'Unknown', 1, 0)) AS unknown_category,
  COUNT(*) AS total
FROM SILVER.PRODUCT_REVIEWS_CLEAN;

--C5) Vérifier qu’on n’a pas de lignes “vides”
SELECT COUNT(*) AS bad_rows
FROM SILVER.PRODUCT_REVIEWS_CLEAN
WHERE product_id IS NULL;

-------------------------------------------------------------------------
--Table 5 — BRONZE.CUSTOMER_DEMOGRAPHICS → SILVER.CUSTOMER_DEMOGRAPHICS_CLEAN

--A) Profiling BRONZE (avant nettoyage)
--A1) Schéma
DESC TABLE BRONZE.CUSTOMER_DEMOGRAPHICS;

--A2) Volume
SELECT COUNT(*) AS nb_rows
FROM BRONZE.CUSTOMER_DEMOGRAPHICS;

--A3) Échantillon
SELECT *
FROM BRONZE.CUSTOMER_DEMOGRAPHICS
LIMIT 20;

--A4) Nulls sur colonnes clés

SELECT
  SUM(IFF(customer_id IS NULL, 1, 0)) AS null_customer_id,
  SUM(IFF(name IS NULL OR TRIM(name) = '', 1, 0)) AS null_name,
  SUM(IFF(region IS NULL OR TRIM(region) = '', 1, 0)) AS null_region,
  SUM(IFF(country IS NULL OR TRIM(country) = '', 1, 0)) AS null_country,
  SUM(IFF(city IS NULL OR TRIM(city) = '', 1, 0)) AS null_city
FROM BRONZE.CUSTOMER_DEMOGRAPHICS;

--A5) Doublons sur customer_id

SELECT
  COUNT(*) AS total,
  COUNT(DISTINCT customer_id) AS distinct_ids,
  COUNT(*) - COUNT(DISTINCT customer_id) AS duplicate_rows
FROM BRONZE.CUSTOMER_DEMOGRAPHICS;

--Voir les doublons :
SELECT customer_id, COUNT(*) AS cnt
FROM BRONZE.CUSTOMER_DEMOGRAPHICS
GROUP BY customer_id
HAVING COUNT(*) > 1
ORDER BY cnt DESC
LIMIT 20;

--A6) Formats à risque : date_of_birth + annual_income
--Dates invalides :
SELECT customer_id, date_of_birth
FROM BRONZE.CUSTOMER_DEMOGRAPHICS
WHERE date_of_birth IS NOT NULL
  AND TRY_TO_DATE(date_of_birth::VARCHAR) IS NULL
LIMIT 50;

--Revenus non convertibles (espaces, texte, etc.) :
SELECT customer_id, annual_income
FROM BRONZE.CUSTOMER_DEMOGRAPHICS
WHERE annual_income IS NOT NULL
  AND TRY_TO_DECIMAL(REPLACE(annual_income::VARCHAR, ' ', ''), 18, 2) IS NULL
LIMIT 50;

--A7) Qualité métier (optionnel mais utile)
--Date de naissance dans le futur (impossible) :
SELECT customer_id, date_of_birth
FROM BRONZE.CUSTOMER_DEMOGRAPHICS
WHERE TRY_TO_DATE(date_of_birth::VARCHAR) > CURRENT_DATE()
LIMIT 50;

--Revenus négatifs :
SELECT customer_id, annual_income
FROM BRONZE.CUSTOMER_DEMOGRAPHICS
WHERE TRY_TO_DECIMAL(REPLACE(annual_income::VARCHAR, ' ', ''), 18, 2) < 0
LIMIT 50;

--B) Création de la table SILVER (nettoyage)

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

--C) Contrôles post-clean (SILVER)
--C1) Volume BRONZE vs SILVER
SELECT
  (SELECT COUNT(*) FROM BRONZE.CUSTOMER_DEMOGRAPHICS) AS bronze_rows,
  (SELECT COUNT(*) FROM SILVER.CUSTOMER_DEMOGRAPHICS_CLEAN) AS silver_rows;

--C2) Clé unique OK ?
SELECT COUNT(*) - COUNT(DISTINCT customer_id) AS duplicates
FROM SILVER.CUSTOMER_DEMOGRAPHICS_CLEAN;

--C3) Nulls sur colonnes importantes
SELECT
  SUM(IFF(name IS NULL, 1, 0)) AS null_name,
  SUM(IFF(region IS NULL, 1, 0)) AS null_region,
  SUM(IFF(country IS NULL, 1, 0)) AS null_country,
  SUM(IFF(annual_income IS NULL, 1, 0)) AS null_income,
  SUM(IFF(date_of_birth IS NULL, 1, 0)) AS null_dob
FROM SILVER.CUSTOMER_DEMOGRAPHICS_CLEAN;

--C4) Statistiques rapides (sanity check)
SELECT
  MIN(annual_income) AS min_income,
  MAX(annual_income) AS max_income
FROM SILVER.CUSTOMER_DEMOGRAPHICS_CLEAN;

------------------------------------------------------------------------------------
--Table 6 — BRONZE.LOGISTICS_AND_SHIPPING → SILVER.LOGISTICS_AND_SHIPPING_CLEAN
--A) Profiling BRONZE (avant nettoyage)
--A1) Schéma
DESC TABLE BRONZE.LOGISTICS_AND_SHIPPING;
--A2) Volume
SELECT COUNT(*) AS nb_rows
FROM BRONZE.LOGISTICS_AND_SHIPPING;

--A3) Échantillon
SELECT *
FROM BRONZE.LOGISTICS_AND_SHIPPING
LIMIT 20;

--A4) Nulls sur colonnes clés
SELECT
  SUM(IFF(shipment_id IS NULL OR TRIM(shipment_id) = '', 1, 0)) AS null_shipment_id,
  SUM(IFF(order_id IS NULL OR TRIM(order_id) = '', 1, 0)) AS null_order_id,
  SUM(IFF(ship_date IS NULL, 1, 0)) AS null_ship_date,
  SUM(IFF(status IS NULL OR TRIM(status) = '', 1, 0)) AS null_status,
  SUM(IFF(shipping_cost IS NULL, 1, 0)) AS null_shipping_cost,
  SUM(IFF(destination_region IS NULL OR TRIM(destination_region) = '', 1, 0)) AS null_dest_region,
  SUM(IFF(destination_country IS NULL OR TRIM(destination_country) = '', 1, 0)) AS null_dest_country
FROM BRONZE.LOGISTICS_AND_SHIPPING;

--A5) Doublons sur shipment_id

SELECT
  COUNT(*) AS total,
  COUNT(DISTINCT shipment_id) AS distinct_ids,
  COUNT(*) - COUNT(DISTINCT shipment_id) AS duplicate_rows
FROM BRONZE.LOGISTICS_AND_SHIPPING;

--Voir les doublons :
SELECT shipment_id, COUNT(*) AS cnt
FROM BRONZE.LOGISTICS_AND_SHIPPING
GROUP BY shipment_id
HAVING COUNT(*) > 1
ORDER BY cnt DESC
LIMIT 20;

--A6) Dates incohérentes / invalides
--Dates non convertibles :
SELECT shipment_id, ship_date, estimated_delivery
FROM BRONZE.LOGISTICS_AND_SHIPPING
WHERE (ship_date IS NOT NULL AND TRY_TO_DATE(ship_date::VARCHAR) IS NULL)
   OR (estimated_delivery IS NOT NULL AND TRY_TO_DATE(estimated_delivery::VARCHAR) IS NULL)
LIMIT 50;

--Livraison avant expédition (incohérent) :

SELECT shipment_id, ship_date, estimated_delivery
FROM BRONZE.LOGISTICS_AND_SHIPPING
WHERE TRY_TO_DATE(ship_date::VARCHAR) IS NOT NULL
  AND TRY_TO_DATE(estimated_delivery::VARCHAR) IS NOT NULL
  AND TRY_TO_DATE(estimated_delivery::VARCHAR) < TRY_TO_DATE(ship_date::VARCHAR)
LIMIT 50;

--A7) Coûts invalides (espaces, non numériques, négatifs)
--Non convertibles :

SELECT shipment_id, shipping_cost
FROM BRONZE.LOGISTICS_AND_SHIPPING
WHERE shipping_cost IS NOT NULL
  AND TRY_TO_DECIMAL(REPLACE(shipping_cost::VARCHAR, ' ', ''), 18, 2) IS NULL
LIMIT 50;

--Négatifs :

SELECT shipment_id, shipping_cost
FROM BRONZE.LOGISTICS_AND_SHIPPING
WHERE TRY_TO_DECIMAL(REPLACE(shipping_cost::VARCHAR, ' ', ''), 18, 2) < 0
LIMIT 50;


--B) Création de la table SILVER (nettoyage)

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

--C2) Doublons restants ?
SELECT COUNT(*) - COUNT(DISTINCT shipment_id) AS duplicates
FROM SILVER.LOGISTICS_AND_SHIPPING_CLEAN;

--C3) Coûts valides
SELECT
  SUM(IFF(shipping_cost IS NULL, 1, 0)) AS null_cost,
  MIN(shipping_cost) AS min_cost,
  MAX(shipping_cost) AS max_cost
FROM SILVER.LOGISTICS_AND_SHIPPING_CLEAN;

--C4) Contrôle des délais (sanity check)
SELECT
  COUNT(*) AS rows_with_dates,
  AVG(DATEDIFF('day', ship_date, estimated_delivery)) AS avg_delivery_days
FROM SILVER.LOGISTICS_AND_SHIPPING_CLEAN
WHERE ship_date IS NOT NULL AND estimated_delivery IS NOT NULL;

--C5) Statuts (utile pour Phase 2)

SELECT status, COUNT(*) AS cnt
FROM SILVER.LOGISTICS_AND_SHIPPING_CLEAN
GROUP BY status
ORDER BY cnt DESC;

------------------------------------------------------------------------------------
--Table 7 — BRONZE.CUSTOMER_SERVICE_INTERACTIONS → SILVER.CUSTOMER_SERVICE_INTERACTIONS_CLEAN
--A) Profiling BRONZE (avant nettoyage)
--A1) Schéma

DESC TABLE BRONZE.CUSTOMER_SERVICE_INTERACTIONS;

--A2) Volume
SELECT COUNT(*) AS nb_rows
FROM BRONZE.CUSTOMER_SERVICE_INTERACTIONS;

--A3) Échantillon

SELECT *
FROM BRONZE.CUSTOMER_SERVICE_INTERACTIONS
LIMIT 20;

--A4) Nulls sur colonnes clés
SELECT
  SUM(IFF(interaction_id IS NULL OR TRIM(interaction_id) = '', 1, 0)) AS null_interaction_id,
  SUM(IFF(interaction_date IS NULL, 1, 0)) AS null_interaction_date,
  SUM(IFF(interaction_type IS NULL OR TRIM(interaction_type) = '', 1, 0)) AS null_interaction_type,
  SUM(IFF(issue_category IS NULL OR TRIM(issue_category) = '', 1, 0)) AS null_issue_category,
  SUM(IFF(resolution_status IS NULL OR TRIM(resolution_status) = '', 1, 0)) AS null_resolution_status,
  SUM(IFF(customer_satisfaction IS NULL, 1, 0)) AS null_satisfaction
FROM BRONZE.CUSTOMER_SERVICE_INTERACTIONS;

--A5) Doublons sur interaction_id
SELECT
  COUNT(*) AS total,
  COUNT(DISTINCT interaction_id) AS distinct_ids,
  COUNT(*) - COUNT(DISTINCT interaction_id) AS duplicate_rows
FROM BRONZE.CUSTOMER_SERVICE_INTERACTIONS;

--Voir les doublons :
SELECT interaction_id, COUNT(*) AS cnt
FROM BRONZE.CUSTOMER_SERVICE_INTERACTIONS
GROUP BY interaction_id
HAVING COUNT(*) > 1
ORDER BY cnt DESC
LIMIT 20;

--A6) Contrôles qualité métier
--Satisfaction hors plage (on attend 1..5) :
SELECT interaction_id, customer_satisfaction
FROM BRONZE.CUSTOMER_SERVICE_INTERACTIONS
WHERE customer_satisfaction IS NOT NULL
  AND customer_satisfaction NOT BETWEEN 1 AND 5
LIMIT 50;

--Durée négative ou absurde (ex : > 600 min) :

SELECT interaction_id, duration_minutes
FROM BRONZE.CUSTOMER_SERVICE_INTERACTIONS
WHERE duration_minutes IS NOT NULL
  AND (duration_minutes < 0 OR duration_minutes > 600)
LIMIT 50;

--follow_up_required valeurs non standard
SELECT follow_up_required, COUNT(*) AS cnt
FROM BRONZE.CUSTOMER_SERVICE_INTERACTIONS
GROUP BY follow_up_required
ORDER BY cnt DESC;

--B) Création de la table SILVER (nettoyage)
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

--C) Contrôles post-clean (SILVER)
--C1) Volume BRONZE vs SILVER

SELECT
  (SELECT COUNT(*) FROM BRONZE.CUSTOMER_SERVICE_INTERACTIONS) AS bronze_rows,
  (SELECT COUNT(*) FROM SILVER.CUSTOMER_SERVICE_INTERACTIONS_CLEAN) AS silver_rows;

--C2) Doublons restants ?

SELECT COUNT(*) - COUNT(DISTINCT interaction_id) AS duplicates
FROM SILVER.CUSTOMER_SERVICE_INTERACTIONS_CLEAN;

--C3) Satisfaction (1..5 ou NULL)

SELECT
  MIN(customer_satisfaction) AS min_sat,
  MAX(customer_satisfaction) AS max_sat,
  SUM(IFF(customer_satisfaction IS NULL, 1, 0)) AS null_sat
FROM SILVER.CUSTOMER_SERVICE_INTERACTIONS_CLEAN;

--C4) Durée (0..600 ou NULL)

SELECT
  MIN(duration_minutes) AS min_dur,
  MAX(duration_minutes) AS max_dur,
  SUM(IFF(duration_minutes IS NULL, 1, 0)) AS null_dur
FROM SILVER.CUSTOMER_SERVICE_INTERACTIONS_CLEAN;


--C5) Valeurs follow_up_required (sanity)
SELECT follow_up_required, COUNT(*) AS cnt
FROM SILVER.CUSTOMER_SERVICE_INTERACTIONS_CLEAN
GROUP BY follow_up_required;


----------------------------------------------------------------------

--Table 8 — BRONZE.SUPPLIER_INFORMATION → SILVER.SUPPLIER_INFORMATION_CLEAN
--A) Profiling BRONZE (avant nettoyage)
--A1) Schéma
DESC TABLE BRONZE.SUPPLIER_INFORMATION;

--A2) Volume
SELECT COUNT(*) AS nb_rows
FROM BRONZE.SUPPLIER_INFORMATION;

--A3) Échantillon

SELECT *
FROM BRONZE.SUPPLIER_INFORMATION
LIMIT 20;

--A4) Nulls sur colonnes clés

SELECT
  SUM(IFF(supplier_id IS NULL OR TRIM(supplier_id) = '', 1, 0)) AS null_supplier_id,
  SUM(IFF(supplier_name IS NULL OR TRIM(supplier_name) = '', 1, 0)) AS null_supplier_name,
  SUM(IFF(product_category IS NULL OR TRIM(product_category) = '', 1, 0)) AS null_product_category,
  SUM(IFF(region IS NULL OR TRIM(region) = '', 1, 0)) AS null_region,
  SUM(IFF(lead_time IS NULL, 1, 0)) AS null_lead_time,
  SUM(IFF(reliability_score IS NULL, 1, 0)) AS null_reliability
FROM BRONZE.SUPPLIER_INFORMATION;

--A5) Doublons sur supplier_id

SELECT
  COUNT(*) AS total,
  COUNT(DISTINCT supplier_id) AS distinct_ids,
  COUNT(*) - COUNT(DISTINCT supplier_id) AS duplicate_rows
FROM BRONZE.SUPPLIER_INFORMATION;


--Voir les doublons :
SELECT supplier_id, COUNT(*) AS cnt
FROM BRONZE.SUPPLIER_INFORMATION
GROUP BY supplier_id
HAVING COUNT(*) > 1
ORDER BY cnt DESC
LIMIT 20;

--A6) Contrôles qualité métier
--lead_time invalide (négatif / trop grand) :
SELECT supplier_id, lead_time
FROM BRONZE.SUPPLIER_INFORMATION
WHERE lead_time IS NOT NULL
  AND (lead_time < 0 OR lead_time > 365)
LIMIT 50;

--reliability_score hors plage (attendu 0..1) :
SELECT supplier_id, reliability_score
FROM BRONZE.SUPPLIER_INFORMATION
WHERE reliability_score IS NOT NULL
  AND (reliability_score < 0 OR reliability_score > 1)
LIMIT 50;

--quality_rating valeurs possibles (A/B/C…)
SELECT quality_rating, COUNT(*) AS cnt
FROM BRONZE.SUPPLIER_INFORMATION
GROUP BY quality_rating
ORDER BY cnt DESC;

--B) Création de la table SILVER (nettoyage)
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

--C) Contrôles post-clean (SILVER)
--C1) Volume BRONZE vs SILVER
SELECT
  (SELECT COUNT(*) FROM BRONZE.SUPPLIER_INFORMATION) AS bronze_rows,
  (SELECT COUNT(*) FROM SILVER.SUPPLIER_INFORMATION_CLEAN) AS silver_rows;

--C2) Doublons restants ?
SELECT COUNT(*) - COUNT(DISTINCT supplier_id) AS duplicates
FROM SILVER.SUPPLIER_INFORMATION_CLEAN;

--C3) Règles métier OK
SELECT
  SUM(IFF(lead_time IS NOT NULL AND (lead_time < 0 OR lead_time > 365), 1, 0)) AS bad_lead_time,
  SUM(IFF(reliability_score IS NOT NULL AND (reliability_score < 0 OR reliability_score > 1), 1, 0)) AS bad_reliability
FROM SILVER.SUPPLIER_INFORMATION_CLEAN;

--C4) Valeurs quality_rating

SELECT quality_rating, COUNT(*) AS cnt
FROM SILVER.SUPPLIER_INFORMATION_CLEAN
GROUP BY quality_rating
ORDER BY cnt DESC;

----------------------------------------------------------------------------------
--Table 9 — BRONZE.EMPLOYEE_RECORDS → SILVER.EMPLOYEE_RECORDS_CLEAN
--A) Profiling BRONZE (avant nettoyage)
--A1) Schéma
DESC TABLE BRONZE.EMPLOYEE_RECORDS;


--A2) Volume
SELECT COUNT(*) AS nb_rows
FROM BRONZE.EMPLOYEE_RECORDS;

--A3) Échantillon
SELECT *
FROM BRONZE.EMPLOYEE_RECORDS
LIMIT 20;

--A4) Nulls sur colonnes clés
SELECT
  SUM(IFF(employee_id IS NULL OR TRIM(employee_id) = '', 1, 0)) AS null_employee_id,
  SUM(IFF(name IS NULL OR TRIM(name) = '', 1, 0)) AS null_name,
  SUM(IFF(hire_date IS NULL, 1, 0)) AS null_hire_date,
  SUM(IFF(department IS NULL OR TRIM(department) = '', 1, 0)) AS null_department,
  SUM(IFF(job_title IS NULL OR TRIM(job_title) = '', 1, 0)) AS null_job_title,
  SUM(IFF(salary IS NULL, 1, 0)) AS null_salary,
  SUM(IFF(email IS NULL OR TRIM(email) = '', 1, 0)) AS null_email
FROM BRONZE.EMPLOYEE_RECORDS;

--A5) Doublons sur employee_id

SELECT
  COUNT(*) AS total,
  COUNT(DISTINCT employee_id) AS distinct_ids,
  COUNT(*) - COUNT(DISTINCT employee_id) AS duplicate_rows
FROM BRONZE.EMPLOYEE_RECORDS;


--Voir les doublons :
SELECT employee_id, COUNT(*) AS cnt
FROM BRONZE.EMPLOYEE_RECORDS
GROUP BY employee_id
HAVING COUNT(*) > 1
ORDER BY cnt DESC
LIMIT 20;

--A6) Formats à risque : dates + salaire

--Dates invalides :
SELECT employee_id, date_of_birth, hire_date
FROM BRONZE.EMPLOYEE_RECORDS
WHERE (date_of_birth IS NOT NULL AND TRY_TO_DATE(date_of_birth::VARCHAR) IS NULL)
   OR (hire_date IS NOT NULL AND TRY_TO_DATE(hire_date::VARCHAR) IS NULL)
LIMIT 50;


--Salaire non convertible / négatif :
SELECT employee_id, salary
FROM BRONZE.EMPLOYEE_RECORDS
WHERE salary IS NOT NULL
  AND (TRY_TO_DECIMAL(REPLACE(salary::VARCHAR, ' ', ''), 18, 2) IS NULL
       OR TRY_TO_DECIMAL(REPLACE(salary::VARCHAR, ' ', ''), 18, 2) <= 0)
LIMIT 50;




--B) Création de la table SILVER (nettoyage)

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


--Hire_date dans le futur → on met NULL (ou supprimer si tu préfères)
UPDATE SILVER.EMPLOYEE_RECORDS_CLEAN
SET hire_date = NULL
WHERE hire_date > CURRENT_DATE();


--C) Contrôles post-clean (SILVER)
--C1) Volume BRONZE vs SILVER
SELECT
  (SELECT COUNT(*) FROM BRONZE.EMPLOYEE_RECORDS) AS bronze_rows,
  (SELECT COUNT(*) FROM SILVER.EMPLOYEE_RECORDS_CLEAN) AS silver_rows;

--C2) Doublons restants ?

SELECT COUNT(*) - COUNT(DISTINCT employee_id) AS duplicates
FROM SILVER.EMPLOYEE_RECORDS_CLEAN;

--C3) Salaire OK

SELECT
  MIN(salary) AS min_salary,
  MAX(salary) AS max_salary,
  SUM(IFF(salary IS NULL, 1, 0)) AS null_salary
FROM SILVER.EMPLOYEE_RECORDS_CLEAN;

--C4) Dates OK
SELECT
  SUM(IFF(date_of_birth IS NULL, 1, 0)) AS null_dob,
  SUM(IFF(hire_date IS NULL, 1, 0)) AS null_hire_date,
  MIN(hire_date) AS min_hire_date,
  MAX(hire_date) AS max_hire_date
FROM SILVER.EMPLOYEE_RECORDS_CLEAN;


-- -----------------------------------------------------
--Table 10 — BRONZE.INVENTORY_RAW (JSON) → SILVER.INVENTORY_CLEAN
--A) Profiling BRONZE (avant nettoyage)
--A1) Volume

SELECT COUNT(*) AS nb_rows
FROM BRONZE.INVENTORY_RAW;

--A2) Échantillon brut

SELECT raw
FROM BRONZE.INVENTORY_RAW
LIMIT 10;

--A3) Vérifier les clés JSON présentes

SELECT
  raw:product_id::STRING AS product_id,
  raw:product_category::STRING AS product_category,
  raw:region::STRING AS region,
  raw:country::STRING AS country,
  raw:warehouse::STRING AS warehouse,
  raw:current_stock::STRING AS current_stock,
  raw:reorder_point::STRING AS reorder_point,
  raw:lead_time::STRING AS lead_time,
  raw:last_restock_date::STRING AS last_restock_date
FROM BRONZE.INVENTORY_RAW
LIMIT 20;

--A4) Nulls sur clés critiques
SELECT
  SUM(IFF(raw:product_id IS NULL, 1, 0)) AS null_product_id,
  SUM(IFF(raw:current_stock IS NULL, 1, 0)) AS null_current_stock,
  SUM(IFF(raw:reorder_point IS NULL, 1, 0)) AS null_reorder_point
FROM BRONZE.INVENTORY_RAW;

--A5) Valeurs non convertibles (numériques / date)

SELECT raw:product_id::STRING AS product_id, raw:current_stock AS current_stock
FROM BRONZE.INVENTORY_RAW
WHERE raw:current_stock IS NOT NULL
  AND TRY_TO_NUMBER(raw:current_stock::STRING) IS NULL
LIMIT 50;

SELECT raw:product_id::STRING AS product_id, raw:last_restock_date AS last_restock_date
FROM BRONZE.INVENTORY_RAW
WHERE raw:last_restock_date IS NOT NULL
  AND TRY_TO_DATE(raw:last_restock_date::STRING) IS NULL
LIMIT 50;

--A6) Doublons potentiels sur (product_id, region, country, warehouse)

SELECT
  raw:product_id::STRING AS product_id,
  raw:region::STRING AS region,
  raw:country::STRING AS country,
  raw:warehouse::STRING AS warehouse,
  COUNT(*) AS cnt
FROM BRONZE.INVENTORY_RAW
GROUP BY 1,2,3,4
HAVING COUNT(*) > 1
ORDER BY cnt DESC
LIMIT 20;

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

--C) Contrôles post-clean (SILVER)
--C1) Volume BRONZE vs SILVER

SELECT
  (SELECT COUNT(*) FROM BRONZE.INVENTORY_RAW) AS bronze_rows,
  (SELECT COUNT(*) FROM SILVER.INVENTORY_CLEAN) AS silver_rows;


--C3) Valeurs négatives (doit être 0)

SELECT COUNT(*) AS bad_rows
FROM SILVER.INVENTORY_CLEAN
WHERE (current_stock < 0) OR (reorder_point < 0) OR (lead_time < 0);

--C4) Identifier ruptures / risques de rupture (utile Phase 2)

SELECT *
FROM SILVER.INVENTORY_CLEAN
WHERE current_stock IS NOT NULL
  AND reorder_point IS NOT NULL
  AND current_stock <= reorder_point
LIMIT 50;


-------------------------------------------------------------------------------------------
--Table 11 — BRONZE.STORE_LOCATIONS_RAW (JSON) → SILVER.STORE_LOCATIONS_CLEAN
--A) Profiling BRONZE (avant nettoyage)
--A1) Volume

SELECT COUNT(*) AS nb_rows
FROM BRONZE.STORE_LOCATIONS_RAW;


--A2) Échantillon brut
SELECT raw
FROM BRONZE.STORE_LOCATIONS_RAW
LIMIT 10;

--A3) Vérifier les champs extraits (lecture “humaine”)
SELECT
  raw:store_id::STRING AS store_id,
  raw:store_name::STRING AS store_name,
  raw:store_type::STRING AS store_type,
  raw:region::STRING AS region,
  raw:country::STRING AS country,
  raw:city::STRING AS city,
  raw:address::STRING AS address,
  raw:postal_code::STRING AS postal_code,
  raw:square_footage::STRING AS square_footage,
  raw:employee_count::STRING AS employee_count
FROM BRONZE.STORE_LOCATIONS_RAW
LIMIT 20;


--A4) Nulls sur clés critiques

SELECT
  SUM(IFF(raw:store_id IS NULL, 1, 0)) AS null_store_id,
  SUM(IFF(raw:store_name IS NULL, 1, 0)) AS null_store_name,
  SUM(IFF(raw:country IS NULL, 1, 0)) AS null_country
FROM BRONZE.STORE_LOCATIONS_RAW;

--A5) Valeurs non convertibles (square_footage / employee_count)

SELECT raw:store_id::STRING AS store_id, raw:square_footage AS square_footage
FROM BRONZE.STORE_LOCATIONS_RAW
WHERE raw:square_footage IS NOT NULL
  AND TRY_TO_DOUBLE(raw:square_footage::STRING) IS NULL
LIMIT 50;

SELECT raw:store_id::STRING AS store_id, raw:employee_count AS employee_count
FROM BRONZE.STORE_LOCATIONS_RAW
WHERE raw:employee_count IS NOT NULL
  AND TRY_TO_NUMBER(raw:employee_count::STRING) IS NULL
LIMIT 50;


--A6) Doublons potentiels sur store_id

SELECT raw:store_id::STRING AS store_id, COUNT(*) AS cnt
FROM BRONZE.STORE_LOCATIONS_RAW
GROUP BY 1
HAVING COUNT(*) > 1
ORDER BY cnt DESC
LIMIT 20;


--B) Création de la table SILVER (parsing + nettoyage)

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


--C2) Doublons restants ?

SELECT COUNT(*) - COUNT(DISTINCT store_id) AS duplicates
FROM SILVER.STORE_LOCATIONS_CLEAN;


--C3) Qualité surface / effectif
SELECT
  SUM(IFF(square_footage IS NOT NULL AND square_footage <= 0, 1, 0)) AS bad_sqft,
  SUM(IFF(employee_count IS NOT NULL AND employee_count < 0, 1, 0)) AS bad_emp
FROM SILVER.STORE_LOCATIONS_CLEAN;

--C4) Valeurs manquantes utiles

SELECT
  SUM(IFF(country IS NULL, 1, 0)) AS null_country,
  SUM(IFF(city IS NULL, 1, 0)) AS null_city,
  SUM(IFF(region IS NULL, 1, 0)) AS null_region
FROM SILVER.STORE_LOCATIONS_CLEAN;
