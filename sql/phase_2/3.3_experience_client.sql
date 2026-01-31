--2.3.3 Expérience client
--A) Impact des avis produits (proxy : note moyenne par catégorie)

SELECT
  product_category,
  AVG(rating) AS avg_rating,
  COUNT(*) AS nb_reviews
FROM SILVER.PRODUCT_REVIEWS_CLEAN
GROUP BY product_category
ORDER BY avg_rating DESC;


--B) Influence du service client (satisfaction par type de problème)

SELECT
  issue_category,
  AVG(customer_satisfaction) AS avg_satisfaction,
  COUNT(*) AS nb_interactions
FROM SILVER.CUSTOMER_SERVICE_INTERACTIONS_CLEAN
GROUP BY issue_category
ORDER BY avg_satisfaction ASC;

