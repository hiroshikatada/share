CREATE OR REPLACE VIEW `audeodb.sample_ds.v_ec_customer_purchase_pivot` AS
WITH base AS (
  SELECT
    h.order_id,
    h.customer_id,
    c.customer_name,
    c.region,
    c.customer_segment,
    h.purchase_date,
    ROUND(h.unit_price * h.quantity * (1 - h.discount_rate), 0) AS sales_amount,
    p.category AS product_category
  FROM `audeodb.sample_ds.customer_purchase_history` AS h
  JOIN `audeodb.sample_ds.customer_master` AS c
    ON h.customer_id = c.customer_id
  JOIN `audeodb.sample_ds.product_master` AS p
    ON h.product_id = p.product_id
)
SELECT
  customer_id,
  customer_name,
  region,
  customer_segment,
  SUM(CASE WHEN product_category = 'PC' THEN sales_amount ELSE 0 END) AS sales_pc,
  SUM(CASE WHEN product_category = 'AV' THEN sales_amount ELSE 0 END) AS sales_av,
  SUM(CASE WHEN product_category = '家電' THEN sales_amount ELSE 0 END) AS sales_home_appliance,
  SUM(CASE WHEN product_category = 'ウェアラブル' THEN sales_amount ELSE 0 END) AS sales_wearable,
  SUM(sales_amount) AS total_sales,
  COUNT(DISTINCT order_id) AS total_orders,
  ROUND(AVG(sales_amount), 0) AS avg_order_value
FROM base
GROUP BY
  customer_id,
  customer_name,
  region,
  customer_segment
QUALIFY ROW_NUMBER() OVER (PARTITION BY region ORDER BY total_sales DESC) <= 3;
