-- ============================================================
-- ÉTAPE 4 – VÉRIFICATIONS (BRONZE & JSON RAW)
-- Objectifs :
-- 1) Vérifier le nombre de lignes
-- 2) Inspecter un échantillon (SELECT * LIMIT 10)
-- 3) Identifier les colonnes clés (IDs, dates, produits, régions)
-- ============================================================

USE DATABASE ANYCOMPANY_LAB;
USE SCHEMA BRONZE;
-- USE WAREHOUSE WH_LAB;

-- ------------------------------------------------------------
-- 0) VÉRIFICATION DES VOLUMES (toutes les tables BRONZE)
-- => Permet de détecter une table vide ou un chargement partiel
-- ------------------------------------------------------------
SELECT 'CUSTOMER_DEMOGRAPHICS' AS table_name, COUNT(*) AS nb_rows FROM BRONZE.CUSTOMER_DEMOGRAPHICS
UNION ALL SELECT 'CUSTOMER_SERVICE_INTERACTIONS', COUNT(*) FROM BRONZE.CUSTOMER_SERVICE_INTERACTIONS
UNION ALL SELECT 'FINANCIAL_TRANSACTIONS', COUNT(*) FROM BRONZE.FINANCIAL_TRANSACTIONS
UNION ALL SELECT 'PROMOTIONS_DATA', COUNT(*) FROM BRONZE.PROMOTIONS_DATA
UNION ALL SELECT 'MARKETING_CAMPAIGNS', COUNT(*) FROM BRONZE.MARKETING_CAMPAIGNS
UNION ALL SELECT 'PRODUCT_REVIEWS', COUNT(*) FROM BRONZE.PRODUCT_REVIEWS
UNION ALL SELECT 'LOGISTICS_AND_SHIPPING', COUNT(*) FROM BRONZE.LOGISTICS_AND_SHIPPING
UNION ALL SELECT 'SUPPLIER_INFORMATION', COUNT(*) FROM BRONZE.SUPPLIER_INFORMATION
UNION ALL SELECT 'EMPLOYEE_RECORDS', COUNT(*) FROM BRONZE.EMPLOYEE_RECORDS
UNION ALL SELECT 'INVENTORY_RAW', COUNT(*) FROM BRONZE.INVENTORY_RAW
UNION ALL SELECT 'STORE_LOCATIONS_RAW', COUNT(*) FROM BRONZE.STORE_LOCATIONS_RAW
ORDER BY table_name;

-- ------------------------------------------------------------
-- 1) CUSTOMER_DEMOGRAPHICS – Échantillon + colonnes clés
-- Clés : customer_id (ID), date_of_birth (date), region/country/city (géographie)
-- ------------------------------------------------------------
SELECT * FROM BRONZE.CUSTOMER_DEMOGRAPHICS LIMIT 10;

-- IDs : unicité / doublons éventuels
SELECT
  COUNT(*) AS total_rows,
  COUNT(DISTINCT customer_id) AS distinct_customer_id,
  COUNT(*) - COUNT(DISTINCT customer_id) AS duplicate_customer_id
FROM BRONZE.CUSTOMER_DEMOGRAPHICS;

-- Dates : période couverte
SELECT
  MIN(TRY_TO_DATE(date_of_birth::VARCHAR)) AS min_dob,
  MAX(TRY_TO_DATE(date_of_birth::VARCHAR)) AS max_dob
FROM BRONZE.CUSTOMER_DEMOGRAPHICS;

-- Régions : valeurs distinctes (utile pour segmentations)
SELECT region, COUNT(*) AS cnt
FROM BRONZE.CUSTOMER_DEMOGRAPHICS
GROUP BY region
ORDER BY cnt DESC;

-- ------------------------------------------------------------
-- 2) CUSTOMER_SERVICE_INTERACTIONS – Échantillon + colonnes clés
-- Clés : interaction_id (ID), interaction_date (date)
-- ------------------------------------------------------------
SELECT * FROM BRONZE.CUSTOMER_SERVICE_INTERACTIONS LIMIT 10;

SELECT
  COUNT(*) AS total_rows,
  COUNT(DISTINCT interaction_id) AS distinct_interaction_id,
  COUNT(*) - COUNT(DISTINCT interaction_id) AS duplicate_interaction_id
FROM BRONZE.CUSTOMER_SERVICE_INTERACTIONS;

SELECT
  MIN(TRY_TO_DATE(interaction_date::VARCHAR)) AS min_date,
  MAX(TRY_TO_DATE(interaction_date::VARCHAR)) AS max_date
FROM BRONZE.CUSTOMER_SERVICE_INTERACTIONS;

-- Types/catégories (utile pour analyse expérience client)
SELECT issue_category, COUNT(*) AS cnt
FROM BRONZE.CUSTOMER_SERVICE_INTERACTIONS
GROUP BY issue_category
ORDER BY cnt DESC;

-- ------------------------------------------------------------
-- 3) FINANCIAL_TRANSACTIONS – Échantillon + colonnes clés
-- Clés : transaction_id (ID), transaction_date (date), region (géographie), amount (mesure)
-- ------------------------------------------------------------
SELECT * FROM BRONZE.FINANCIAL_TRANSACTIONS LIMIT 10;

SELECT
  COUNT(*) AS total_rows,
  COUNT(DISTINCT transaction_id) AS distinct_transaction_id,
  COUNT(*) - COUNT(DISTINCT transaction_id) AS duplicate_transaction_id
FROM BRONZE.FINANCIAL_TRANSACTIONS;

SELECT
  MIN(TRY_TO_DATE(transaction_date::VARCHAR)) AS min_date,
  MAX(TRY_TO_DATE(transaction_date::VARCHAR)) AS max_date
FROM BRONZE.FINANCIAL_TRANSACTIONS;

SELECT region, COUNT(*) AS cnt
FROM BRONZE.FINANCIAL_TRANSACTIONS
GROUP BY region
ORDER BY cnt DESC;

-- Contrôle rapide montants (anomalies/NULLs)
SELECT
  SUM(IFF(amount IS NULL, 1, 0)) AS null_amount,
  SUM(IFF(TRY_TO_DECIMAL(REPLACE(amount::VARCHAR,' ',''),18,2) IS NULL AND amount IS NOT NULL, 1, 0)) AS not_parsable_amount
FROM BRONZE.FINANCIAL_TRANSACTIONS;

-- ------------------------------------------------------------
-- 4) PROMOTIONS_DATA – Échantillon + colonnes clés
-- Clés : promotion_id (ID), start_date/end_date (dates), region (géographie), product_category (produit)
-- ------------------------------------------------------------
SELECT * FROM BRONZE.PROMOTIONS_DATA LIMIT 10;

SELECT
  COUNT(*) AS total_rows,
  COUNT(DISTINCT promotion_id) AS distinct_promotion_id,
  COUNT(*) - COUNT(DISTINCT promotion_id) AS duplicate_promotion_id
FROM BRONZE.PROMOTIONS_DATA;

SELECT
  MIN(TRY_TO_DATE(start_date::VARCHAR)) AS min_start,
  MAX(TRY_TO_DATE(end_date::VARCHAR)) AS max_end
FROM BRONZE.PROMOTIONS_DATA;

SELECT product_category, COUNT(*) AS cnt
FROM BRONZE.PROMOTIONS_DATA
GROUP BY product_category
ORDER BY cnt DESC;

SELECT region, COUNT(*) AS cnt
FROM BRONZE.PROMOTIONS_DATA
GROUP BY region
ORDER BY cnt DESC;

-- ------------------------------------------------------------
-- 5) MARKETING_CAMPAIGNS – Échantillon + colonnes clés
-- Attention : campaign_id peut ne pas être unique (cas observé)
-- Clés utiles : campaign_id, start_date/end_date, region, product_category, target_audience
-- ------------------------------------------------------------
SELECT * FROM BRONZE.MARKETING_CAMPAIGNS LIMIT 10;

SELECT
  COUNT(*) AS total_rows,
  COUNT(DISTINCT campaign_id) AS distinct_campaign_id,
  COUNT(*) - COUNT(DISTINCT campaign_id) AS duplicate_campaign_id
FROM BRONZE.MARKETING_CAMPAIGNS;

SELECT
  MIN(TRY_TO_DATE(start_date::VARCHAR)) AS min_start,
  MAX(TRY_TO_DATE(end_date::VARCHAR)) AS max_end
FROM BRONZE.MARKETING_CAMPAIGNS;

SELECT region, COUNT(*) AS cnt
FROM BRONZE.MARKETING_CAMPAIGNS
GROUP BY region
ORDER BY cnt DESC;

SELECT product_category, COUNT(*) AS cnt
FROM BRONZE.MARKETING_CAMPAIGNS
GROUP BY product_category
ORDER BY cnt DESC;

-- ------------------------------------------------------------
-- 6) PRODUCT_REVIEWS – Échantillon + colonnes clés
-- Clés : review_id (ID parfois sale), review_date (date), product_id (produit), product_category
-- ------------------------------------------------------------
SELECT * FROM BRONZE.PRODUCT_REVIEWS LIMIT 10;

-- Unicité review_id si convertible en numérique
SELECT
  COUNT(*) AS total_rows,
  COUNT(DISTINCT TRY_TO_NUMBER(review_id::VARCHAR)) AS distinct_review_id_numeric
FROM BRONZE.PRODUCT_REVIEWS;

SELECT
  MIN(COALESCE(TRY_TO_DATE(review_date::VARCHAR), TO_DATE(TRY_TO_TIMESTAMP_NTZ(review_date::VARCHAR)))) AS min_review_date,
  MAX(COALESCE(TRY_TO_DATE(review_date::VARCHAR), TO_DATE(TRY_TO_TIMESTAMP_NTZ(review_date::VARCHAR)))) AS max_review_date
FROM BRONZE.PRODUCT_REVIEWS;

SELECT product_category, COUNT(*) AS cnt
FROM BRONZE.PRODUCT_REVIEWS
GROUP BY product_category
ORDER BY cnt DESC;

-- ------------------------------------------------------------
-- 7) LOGISTICS_AND_SHIPPING – Échantillon + colonnes clés
-- Clés : shipment_id (ID), ship_date/estimated_delivery (dates), destination_region (géographie)
-- ------------------------------------------------------------
SELECT * FROM BRONZE.LOGISTICS_AND_SHIPPING LIMIT 10;

SELECT
  COUNT(*) AS total_rows,
  COUNT(DISTINCT shipment_id) AS distinct_shipment_id,
  COUNT(*) - COUNT(DISTINCT shipment_id) AS duplicate_shipment_id
FROM BRONZE.LOGISTICS_AND_SHIPPING;

SELECT
  MIN(TRY_TO_DATE(ship_date::VARCHAR)) AS min_ship_date,
  MAX(TRY_TO_DATE(ship_date::VARCHAR)) AS max_ship_date
FROM BRONZE.LOGISTICS_AND_SHIPPING;

SELECT destination_region, COUNT(*) AS cnt
FROM BRONZE.LOGISTICS_AND_SHIPPING
GROUP BY destination_region
ORDER BY cnt DESC;

-- ------------------------------------------------------------
-- 8) SUPPLIER_INFORMATION – Échantillon + colonnes clés
-- Clés : supplier_id (ID), product_category, region/country
-- ------------------------------------------------------------
SELECT * FROM BRONZE.SUPPLIER_INFORMATION LIMIT 10;

SELECT
  COUNT(*) AS total_rows,
  COUNT(DISTINCT supplier_id) AS distinct_supplier_id,
  COUNT(*) - COUNT(DISTINCT supplier_id) AS duplicate_supplier_id
FROM BRONZE.SUPPLIER_INFORMATION;

SELECT product_category, COUNT(*) AS cnt
FROM BRONZE.SUPPLIER_INFORMATION
GROUP BY product_category
ORDER BY cnt DESC;

SELECT region, COUNT(*) AS cnt
FROM BRONZE.SUPPLIER_INFORMATION
GROUP BY region
ORDER BY cnt DESC;

-- ------------------------------------------------------------
-- 9) EMPLOYEE_RECORDS – Échantillon + colonnes clés
-- Clés : employee_id (ID), hire_date (date), department/region
-- ------------------------------------------------------------
SELECT * FROM BRONZE.EMPLOYEE_RECORDS LIMIT 10;

SELECT
  COUNT(*) AS total_rows,
  COUNT(DISTINCT employee_id) AS distinct_employee_id,
  COUNT(*) - COUNT(DISTINCT employee_id) AS duplicate_employee_id
FROM BRONZE.EMPLOYEE_RECORDS;

SELECT
  MIN(TRY_TO_DATE(hire_date::VARCHAR)) AS min_hire_date,
  MAX(TRY_TO_DATE(hire_date::VARCHAR)) AS max_hire_date
FROM BRONZE.EMPLOYEE_RECORDS;

SELECT department, COUNT(*) AS cnt
FROM BRONZE.EMPLOYEE_RECORDS
GROUP BY department
ORDER BY cnt DESC;

-- ------------------------------------------------------------
-- 10) INVENTORY_RAW (JSON) – Échantillon + colonnes clés
-- Clés : product_id, region/country/warehouse, last_restock_date
-- ------------------------------------------------------------
SELECT raw FROM BRONZE.INVENTORY_RAW LIMIT 10;

SELECT
  COUNT(*) AS total_rows,
  COUNT(DISTINCT raw:product_id::STRING) AS distinct_product_id
FROM BRONZE.INVENTORY_RAW;

SELECT
  MIN(TRY_TO_DATE(raw:last_restock_date::STRING)) AS min_restock,
  MAX(TRY_TO_DATE(raw:last_restock_date::STRING)) AS max_restock
FROM BRONZE.INVENTORY_RAW;

SELECT raw:region::STRING AS region, COUNT(*) AS cnt
FROM BRONZE.INVENTORY_RAW
GROUP BY region
ORDER BY cnt DESC;

-- ------------------------------------------------------------
-- 11) STORE_LOCATIONS_RAW (JSON) – Échantillon + colonnes clés
-- Clés : store_id, region/country/city
-- ------------------------------------------------------------
SELECT raw FROM BRONZE.STORE_LOCATIONS_RAW LIMIT 10;

SELECT
  COUNT(*) AS total_rows,
  COUNT(DISTINCT raw:store_id::STRING) AS distinct_store_id
FROM BRONZE.STORE_LOCATIONS_RAW;

SELECT raw:region::STRING AS region, COUNT(*) AS cnt
FROM BRONZE.STORE_LOCATIONS_RAW
GROUP BY region
ORDER BY cnt DESC;

SELECT raw:country::STRING AS country, COUNT(*) AS cnt
FROM BRONZE.STORE_LOCATIONS_RAW
GROUP BY country
ORDER BY cnt DESC;