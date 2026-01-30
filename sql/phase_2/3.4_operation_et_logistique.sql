--2.3.4 Opérations & logistique

--A) Ruptures de stock (alertes)

SELECT
  product_category,
  region,
  COUNT(*) AS nb_stock_alerts
FROM SILVER.INVENTORY_CLEAN
WHERE current_stock IS NOT NULL
  AND reorder_point IS NOT NULL
  AND current_stock <= reorder_point
GROUP BY product_category, region
ORDER BY nb_stock_alerts DESC;

--B) Impact des délais de livraison (et lien avec statuts)

SELECT
  status,
  AVG(DATEDIFF('day', ship_date, estimated_delivery)) AS avg_delivery_days,
  COUNT(*) AS nb_shipments
FROM SILVER.LOGISTICS_AND_SHIPPING_CLEAN
WHERE ship_date IS NOT NULL
  AND estimated_delivery IS NOT NULL
GROUP BY status
ORDER BY avg_delivery_days DESC;
