--2.2 – Analyses exploratoires descriptives (SQL)
--2.2.1 Évolution des ventes dans le temps

SELECT
  DATE_TRUNC('month', transaction_date) AS month,
  SUM(amount) AS total_sales,
  COUNT(*) AS nb_sales
FROM SILVER.FINANCIAL_TRANSACTIONS_CLEAN
WHERE transaction_type = 'Sale'
GROUP BY month
ORDER BY month;


--2.2.2 Performance par catégorie et région (proxy)

--Ventes par région

SELECT
  region,
  SUM(amount) AS total_sales,
  COUNT(*) AS nb_sales
FROM SILVER.FINANCIAL_TRANSACTIONS_CLEAN
WHERE transaction_type = 'Sale'
GROUP BY region
ORDER BY total_sales DESC;

--Ventes par type de transaction (sanity check)

SELECT transaction_type, COUNT(*) AS cnt, SUM(amount) AS total_amount
FROM SILVER.FINANCIAL_TRANSACTIONS_CLEAN
GROUP BY transaction_type
ORDER BY total_amount DESC;


--2.2.3 Répartition des clients par segments démographiques

--Par région

SELECT region, COUNT(*) AS nb_clients, AVG(annual_income) AS avg_income
FROM SILVER.CUSTOMER_DEMOGRAPHICS_CLEAN
GROUP BY region
ORDER BY nb_clients DESC;


--Par genre

SELECT gender, COUNT(*) AS nb_clients
FROM SILVER.CUSTOMER_DEMOGRAPHICS_CLEAN
GROUP BY gender
ORDER BY nb_clients DESC;


--Par statut marital

SELECT marital_status, COUNT(*) AS nb_clients
FROM SILVER.CUSTOMER_DEMOGRAPHICS_CLEAN
GROUP BY marital_status
ORDER BY nb_clients DESC;
