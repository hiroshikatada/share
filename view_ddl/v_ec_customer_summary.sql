CREATE OR REPLACE VIEW `audeodb.sample_ds.v_ec_customer_summary` AS
SELECT
  base.customer_id,
  base.customer_name,
  base.region,
  base.customer_segment,
  COUNT(DISTINCT base.order_id) AS total_orders,
  SUM(base.sales_amount) AS total_sales,
  ROUND(AVG(base.sales_amount), 0) AS avg_order_value,
  MAX(base.sales_amount) AS max_order_amount,
  MIN(base.purchase_date) AS first_purchase_date,
  MAX(base.purchase_date) AS last_purchase_date,
  ARRAY_TO_STRING(
    ARRAY(
      SELECT DISTINCT category
      FROM UNNEST(
        ARRAY(
          SELECT DISTINCT b2.product_category
          FROM `audeodb.sample_ds.v_ec_base_purchase` AS b2
          WHERE b2.customer_id = base.customer_id
        )
      ) AS category
    ),
    ', '
  ) AS categories_bought
FROM `audeodb.sample_ds.v_ec_base_purchase` AS base
GROUP BY
  base.customer_id,
  base.customer_name,
  base.region,
  base.customer_segment;
