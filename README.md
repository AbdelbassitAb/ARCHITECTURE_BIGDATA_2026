# AnyCompany Food & Beverage – Data-Driven Marketing Analytics (Snowflake + Streamlit)

Projet réalisé dans le cadre du workshop **Data-Driven Marketing Analytics avec Snowflake et Streamlit**.  
Objectif : construire un socle analytique fiable (ingestion + nettoyage), produire des analyses business, puis industrialiser ces analyses sous forme de **data product** prêt pour la BI et le Machine Learning.

---

## 1) Contexte & objectif business

AnyCompany (entreprise fictive) subit :
- une baisse de ventes sur le dernier exercice fiscal,
- une réduction de 30% du budget marketing,
- une perte de part de marché (28% → 22% en 8 mois).

**Objectif** : réorienter le marketing vers une approche data-driven afin de :
- inverser la tendance,
- viser **+10 points de part de marché** (22% → 32%) d’ici T4 2025,
- optimiser les actions avec un budget réduit.

---

## 2) Architecture et approche

Nous avons construit une architecture en 3 couches :

- **BRONZE** : données brutes (raw) issues des fichiers CSV/JSON
- **SILVER** : données nettoyées, cohérentes et exploitables
- **ANALYTICS** : data product (tables stables avec KPIs et flags utiles)

Source des données : `s3://logbrain-datalake/datasets/food-beverage/`

---

## 3) Phase 1 – Data Preparation & Ingestion (Snowflake)

### 3.1 Étape 1 — Préparation de l’environnement Snowflake

#### 3.1.1 Création du warehouse
Un warehouse `XSMALL` a été utilisé pour limiter la consommation de crédits, avec auto-suspend activé.

```sql
CREATE OR REPLACE WAREHOUSE WH_LAB
WITH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE;

USE WAREHOUSE WH_LAB;
```

#### 3.1.2 Création de la base et des schémas
Nous avons créé une base dédiée au lab, puis 3 schémas :
- `BRONZE` (raw)
- `SILVER` (clean)
- `ANALYTICS` (data product)

```sql
CREATE OR REPLACE DATABASE ANYCOMPANY_LAB;

CREATE OR REPLACE SCHEMA ANYCOMPANY_LAB.BRONZE;
CREATE OR REPLACE SCHEMA ANYCOMPANY_LAB.SILVER;
CREATE OR REPLACE SCHEMA ANYCOMPANY_LAB.ANALYTICS;
```

---

### 3.2 Étape 2 — File formats & Stage S3

#### 3.2.1 Formats de fichiers

**CSV standard** (délimiteur virgule) :

```sql
CREATE OR REPLACE FILE FORMAT FF_CSV
  TYPE = CSV
  FIELD_DELIMITER = ','
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  TRIM_SPACE = TRUE
  NULL_IF = ('', 'NULL');
```

**TSV (tabulation)** : utilisé pour `product_reviews.csv` car le fichier était en réalité séparé par tabulations.  
Sans cela, on obtenait l’erreur : *"Number of columns in file does not match table"*.  
Nous avons ajouté `ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE` pour éviter l’échec complet du chargement.

```sql
CREATE OR REPLACE FILE FORMAT FF_TSV
  TYPE = CSV
  FIELD_DELIMITER = '\t'
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  TRIM_SPACE = TRUE
  NULL_IF = ('', 'NULL', 'null')
  ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE;
```

**JSON** : les JSON fournis étaient sous forme de tableau → `STRIP_OUTER_ARRAY = TRUE`.

```sql
CREATE OR REPLACE FILE FORMAT FF_JSON
  TYPE = JSON
  STRIP_OUTER_ARRAY = TRUE;
```

#### 3.2.2 Stage S3
```sql
CREATE OR REPLACE STAGE STG_FOOD_BEVERAGE
  URL = 's3://logbrain-datalake/datasets/food-beverage/'
  FILE_FORMAT = FF_CSV;

LIST @STG_FOOD_BEVERAGE;
```

---

### 3.3 Étape 2 — Création des tables BRONZE (raw)

Une table BRONZE a été créée pour chaque fichier.  
Pour les JSON, nous avons stocké les lignes dans une colonne `VARIANT` (`raw`).

Exemples :

- **CSV** : types adaptés aux analyses (DATE, NUMBER(18,2), etc.)
- **JSON** : table `raw VARIANT`

```sql
CREATE OR REPLACE TABLE BRONZE.INVENTORY_RAW ( raw VARIANT );
CREATE OR REPLACE TABLE BRONZE.STORE_LOCATIONS_RAW ( raw VARIANT );
```

---

### 3.4 Étape 3 — Chargement des données (COPY INTO)

Pour chaque table BRONZE, nous avons chargé les données depuis le stage S3 avec `COPY INTO`, en utilisant le `FILE_FORMAT` adapté.

Exemples :

```sql
COPY INTO BRONZE.CUSTOMER_DEMOGRAPHICS
FROM @STG_FOOD_BEVERAGE/customer_demographics.csv
FILE_FORMAT = (FORMAT_NAME = FF_CSV)
ON_ERROR = 'CONTINUE';
```

`product_reviews.csv` (TSV) :

```sql
COPY INTO BRONZE.PRODUCT_REVIEWS
FROM @STG_FOOD_BEVERAGE/product_reviews.csv
FILE_FORMAT = (FORMAT_NAME = FF_TSV)
ON_ERROR = 'CONTINUE';
```

JSON :

```sql
COPY INTO BRONZE.INVENTORY_RAW
FROM @STG_FOOD_BEVERAGE/inventory.json
FILE_FORMAT = (FORMAT_NAME = FF_JSON)
ON_ERROR = 'CONTINUE';
```

#### Vérification COPY (historique)
```sql
SELECT *
FROM TABLE(
  INFORMATION_SCHEMA.COPY_HISTORY(
    TABLE_NAME=>'FINANCIAL_TRANSACTIONS',
    START_TIME=>DATEADD('hour', -2, CURRENT_TIMESTAMP())
  )
);
```

---

### 3.5 Étape 4 — Vérifications post-chargement (BRONZE)

Après chaque chargement, nous avons systématiquement :
- vérifié les **volumes** (table vide / chargement partiel),
- inspecté un **échantillon** (`LIMIT 10`),
- identifié les **colonnes clés** (IDs, dates, régions, catégories),
- détecté les anomalies évidentes (valeurs négatives, dates invalides, etc.).

Exemple de contrôle volume global :

```sql
SELECT 'CUSTOMER_DEMOGRAPHICS' AS table_name, COUNT(*) AS nb_rows FROM BRONZE.CUSTOMER_DEMOGRAPHICS
UNION ALL SELECT 'FINANCIAL_TRANSACTIONS', COUNT(*) FROM BRONZE.FINANCIAL_TRANSACTIONS
UNION ALL SELECT 'STORE_LOCATIONS_RAW', COUNT(*) FROM BRONZE.STORE_LOCATIONS_RAW
ORDER BY table_name;
```

---

## 4) Phase 1 – Étape 5 : Data Cleaning (BRONZE → SILVER)

### 4.1 Principes de nettoyage appliqués

Pour chaque table BRONZE, nous avons créé une table SILVER en appliquant :

1. **Nettoyage des champs texte**
   - `TRIM()`, `NULLIF(TRIM(x), '')` pour éviter les chaînes vides
2. **Harmonisation des types**
   - Dates : `TRY_TO_DATE(...)`
   - Numériques : `TRY_TO_DECIMAL(...)`, suppression des espaces (`REPLACE(x,' ','')`)
3. **Règles de qualité**
   - montants positifs (transactions)
   - discount entre 0 et 1 (promotions)
   - rating entre 1 et 5 (reviews)
   - coûts de shipping >= 0
   - lead_time, stock, reorder_point >= 0
4. **Gestion des doublons (IDs)**
   - Règle générale : **si un ID est censé être unique, on dédoublonne**
   - Méthode : `QUALIFY ROW_NUMBER()` avec un critère métier (date la plus récente ou “ligne la plus complète”)

---

### 4.2 Exemple : Financial Transactions

**Objectif** : sécuriser la base de ventes (montants exploitables, IDs uniques, dates valides).

- Dédoublonnage sur `transaction_id`
- Conversion robuste du montant
- Suppression des montants nuls ou négatifs

```sql
CREATE OR REPLACE TABLE SILVER.FINANCIAL_TRANSACTIONS_CLEAN AS
SELECT
  TRIM(transaction_id) AS transaction_id,
  TRY_TO_DATE(transaction_date::VARCHAR) AS transaction_date,
  TRIM(transaction_type) AS transaction_type,
  TRY_TO_DECIMAL(REPLACE(amount::VARCHAR, ' ', ''), 18, 2) AS amount,
  TRIM(payment_method) AS payment_method,
  TRIM(entity) AS entity,
  NULLIF(TRIM(region), '') AS region,
  TRIM(account_code) AS account_code
FROM BRONZE.FINANCIAL_TRANSACTIONS
WHERE transaction_id IS NOT NULL AND TRIM(transaction_id) <> ''
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY TRIM(transaction_id)
  ORDER BY TRY_TO_DATE(transaction_date::VARCHAR) DESC NULLS LAST
) = 1;

DELETE FROM SILVER.FINANCIAL_TRANSACTIONS_CLEAN
WHERE amount IS NULL OR amount <= 0;
```

---

### 4.3 Exemple : Promotions

- validation de la période (start_date <= end_date)
- discount entre 0 et 1

```sql
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
```

---

### 4.4 Cas particulier important : STORE_LOCATIONS (IDs dupliqués)

#### Constat
Dans la table `BRONZE.STORE_LOCATIONS_RAW`, nous avions environ **5000 lignes**.  
Après nettoyage et dédoublonnage par `store_id`, il ne restait que **897 lignes**, donc **~82% des données supprimées**.

Cela signifie que :
- les `store_id` étaient fortement dupliqués,
- MAIS les lignes associées à un même `store_id` avaient **des valeurs différentes** (donc ce ne sont pas de vrais doublons).

#### Alternatives envisagées
Nous avons envisagé des approches plus avancées :

1) **Changer l’identifiant**
- créer un identifiant technique (surrogate key) : `store_id + hash(address + city + country)`
- permet de conserver toutes les lignes

2) **Créer des versions (SCD Type 2)**
- conserver l’historique des changements avec `valid_from / valid_to`
- nécessite un champ date fiable (par exemple `updated_at`)

#### Pourquoi nous ne les avons pas retenues
Les données du workshop sont **générées** et ne contiennent **pas de champ date** (ex : updated_at) permettant de gérer les versions correctement.  
Sans date, il est impossible de savoir :
- quelle ligne est la version “courante”
- quelle ligne est la version “ancienne”

#### Décision finale
Nous avons choisi une approche simple et cohérente avec l’objectif pédagogique :

✅ **Dédoublonner sur `store_id` en gardant la ligne la plus complète**  
(méthode `completeness_score` + `ROW_NUMBER()`)

```sql
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
    IFF(TRY_TO_DOUBLE(raw:square_footage::STRING) > 0,
        TRY_TO_DOUBLE(raw:square_footage::STRING),
        NULL) AS square_footage,
    IFF(TRY_TO_NUMBER(raw:employee_count::STRING) >= 0,
        TRY_TO_NUMBER(raw:employee_count::STRING),
        NULL) AS employee_count,
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
  store_id, store_name, store_type, region, country, city, address, postal_code,
  square_footage, employee_count
FROM parsed
WHERE store_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY store_id
  ORDER BY completeness_score DESC
) = 1;
```

---

## 5) Phase 2 – Analyses exploratoires & business (SILVER)

Les analyses ont été réalisées à partir des tables SILVER, en couvrant :
- évolution des ventes dans le temps,
- performance par région,
- impact promotions (par région + période),
- ROI proxy des campagnes,
- ratings par catégorie,
- SAV (satisfaction),
- ruptures de stock,
- délais de livraison.

Les scripts SQL sont regroupés dans `sql/` (1 fichier par analyse).

---

## 6) Phase 3 – Data Product (ANALYTICS)

Objectif : industrialiser les insights en tables réutilisables.

Tables créées :
- `ANALYTICS.SALES_ENRICHED` : ventes enrichies avec flags promo/campagne + variables temporelles
- `ANALYTICS.ACTIVE_PROMOTIONS` : promotions normalisées (durée, discount)
- `ANALYTICS.CUSTOMERS_ENRICHED` : clients enrichis (âge, segment de revenu)

Exemple : `SALES_ENRICHED`

```sql
CREATE OR REPLACE TABLE ANALYTICS.SALES_ENRICHED AS
WITH sales AS (
  SELECT transaction_id, transaction_date, region, amount
  FROM SILVER.FINANCIAL_TRANSACTIONS_CLEAN
  WHERE transaction_type = 'Sale'
),
promo_flag AS (
  SELECT s.transaction_id, MAX(1) AS is_promo_period
  FROM sales s
  JOIN SILVER.PROMOTIONS_CLEAN p
    ON s.region = p.region
   AND s.transaction_date BETWEEN p.start_date AND p.end_date
  GROUP BY s.transaction_id
),
campaign_flag AS (
  SELECT s.transaction_id, MAX(1) AS is_campaign_period
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
```

---

## 7) Streamlit (dashboards)

Une page par analyse (multi-pages Streamlit) :
- Sales Dashboard
- Promotion Analysis
- Marketing ROI
- Customer Segmentation
- Operations & Logistics

Connexion Snowflake via `.streamlit/secrets.toml` (non versionné).

---

## 8) Structure du projet

```
project/
├── sql/
│   ├── Load_data.sql
│   ├── step4_verifications.sql
│   ├── clean_data.sql
│   ├── sales_trends.sql
│   ├── promotion_impact.sql
│   └── campaign_performance.sql
├── Home.py
├── pages/
│   ├── 1_Sales_Dashboard.py
│   ├── 2_Promotion_Analysis.py
│   ├── 3_Marketing_ROI.py
│   ├── 4_Customer_Segmentation.py
│   └── 5_Operations_Logistics.py
├── _utils.py
├── .streamlit/
│   └── secrets.toml   (local only)
├── README.md
└── business_insights.md
```

---

## 9) Notes et limites

- Les données étant **générées**, certaines clés (ex : `store_id`) ne reflètent pas toujours une logique métier réaliste.
- Absence de `customer_id` dans les transactions : les analyses ventes/clients restent séparées.
- Absence de `product_id` dans les ventes : analyses produit effectuées par proxy (catégorie/région/période).

---

## 10) Lancer l’app Streamlit

Depuis la racine :

```bash
streamlit run Home.py
```

---

## 11) Sécurité / GitHub

Le fichier de secrets ne doit jamais être commité :

Dans `.gitignore` :

```
.streamlit/secrets.toml
```

---
