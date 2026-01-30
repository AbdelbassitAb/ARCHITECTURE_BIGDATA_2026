--Étape 2 – Création des tables BRONZE (brutes)


--2.1 customer_demographics.csv
CREATE OR REPLACE TABLE BRONZE.CUSTOMER_DEMOGRAPHICS (
  customer_id NUMBER,
  name VARCHAR,
  date_of_birth DATE,
  gender VARCHAR,
  region VARCHAR,
  country VARCHAR,
  city VARCHAR,
  marital_status VARCHAR,
  annual_income NUMBER(18,2)
);

--2.2 customer_service_interactions.csv
CREATE OR REPLACE TABLE BRONZE.CUSTOMER_SERVICE_INTERACTIONS (
  interaction_id VARCHAR,
  interaction_date DATE,
  interaction_type VARCHAR,
  issue_category VARCHAR,
  description VARCHAR,
  duration_minutes NUMBER(10,0),
  resolution_status VARCHAR,
  follow_up_required VARCHAR,
  customer_satisfaction NUMBER(5,0)
);

--2.3 financial_transactions.csv
CREATE OR REPLACE TABLE BRONZE.FINANCIAL_TRANSACTIONS (
  transaction_id VARCHAR,
  transaction_date DATE,
  transaction_type VARCHAR,
  amount NUMBER(18,2),
  payment_method VARCHAR,
  entity VARCHAR,
  region VARCHAR,
  account_code VARCHAR
);
--2.4 promotions-data.csv
CREATE OR REPLACE TABLE BRONZE.PROMOTIONS_DATA (
  promotion_id VARCHAR,
  product_category VARCHAR,
  promotion_type VARCHAR,
  discount_percentage FLOAT,
  start_date DATE,
  end_date DATE,
  region VARCHAR
);

--2.5 marketing_campaigns.csv
CREATE OR REPLACE TABLE BRONZE.MARKETING_CAMPAIGNS (
  campaign_id VARCHAR,
  campaign_name VARCHAR,
  campaign_type VARCHAR,
  product_category VARCHAR,
  target_audience VARCHAR,
  start_date DATE,
  end_date DATE,
  region VARCHAR,
  budget NUMBER(18,2),
  reach NUMBER(18,0),
  conversion_rate FLOAT
);

--2.6 product_reviews.csv

CREATE OR REPLACE TABLE BRONZE.PRODUCT_REVIEWS (
  review_id NUMBER,
  product_id VARCHAR,
  reviewer_id VARCHAR,
  reviewer_name VARCHAR,
  rating VARCHAR,
  review_date DATE,
  review_title VARCHAR,
  review_text VARCHAR,
  product_category VARCHAR
);

--2.7 inventory.json (semi-structuré)
CREATE OR REPLACE TABLE BRONZE.INVENTORY_RAW (
  raw VARIANT
);


--2.8 store_locations.json
CREATE OR REPLACE TABLE BRONZE.STORE_LOCATIONS_RAW (
  raw VARIANT
);

--2.9 logistics_and_shipping.csv
CREATE OR REPLACE TABLE BRONZE.LOGISTICS_AND_SHIPPING (
  shipment_id VARCHAR,
  order_id VARCHAR,
  ship_date DATE,
  estimated_delivery DATE,
  shipping_method VARCHAR,
  status VARCHAR,
  shipping_cost NUMBER(18,2),
  destination_region VARCHAR,
  destination_country VARCHAR,
  carrier VARCHAR
);

--2.10 supplier_information.csv
CREATE OR REPLACE TABLE BRONZE.SUPPLIER_INFORMATION (
  supplier_id VARCHAR,
  supplier_name VARCHAR,
  product_category VARCHAR,
  region VARCHAR,
  country VARCHAR,
  city VARCHAR,
  lead_time NUMBER(10,0),
  reliability_score FLOAT,
  quality_rating VARCHAR
);

--2.11 employee_records.csv
CREATE OR REPLACE TABLE BRONZE.EMPLOYEE_RECORDS (
  employee_id VARCHAR,
  name VARCHAR,
  date_of_birth DATE,
  hire_date DATE,
  department VARCHAR,
  job_title VARCHAR,
  salary NUMBER(18,2),
  region VARCHAR,
  country VARCHAR,
  email VARCHAR
);


LIST @STG_FOOD_BEVERAGE;
