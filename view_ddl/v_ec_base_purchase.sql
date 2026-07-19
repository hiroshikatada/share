CREATE OR REPLACE VIEW `audeodb.sample_ds.v_ec_base_purchase` AS
SELECT
  h.order_id,
  h.customer_id,
  c.customer_name,
  c.region,
  c.customer_segment,
  h.purchase_date,
  ROUND(h.unit_price * h.quantity * (1 - h.discount_rate), 0) AS sales_amount,
  p.product_name,
  p.category AS product_category
FROM `audeodb.sample_ds.customer_purchase_history` AS h
JOIN `audeodb.sample_ds.customer_master` AS c
  ON h.customer_id = c.customer_id
JOIN `audeodb.sample_ds.product_master` AS p
  ON h.product_id = p.product_id;
