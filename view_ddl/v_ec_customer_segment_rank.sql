CREATE OR REPLACE VIEW `audeodb.sample_ds.v_ec_customer_segment_rank` AS
SELECT
  summary.customer_id,
  summary.customer_name,
  summary.region,
  summary.customer_segment,
  summary.total_orders,
  summary.total_sales,
  summary.avg_order_value,
  summary.max_order_amount,
  summary.first_purchase_date,
  summary.last_purchase_date,
  summary.categories_bought,
  CASE
    WHEN summary.total_sales >= 200000 THEN 'VIP'
    WHEN summary.total_sales >= 100000 THEN '高額顧客'
    WHEN summary.total_orders >= 3 THEN 'リピート顧客'
    ELSE '新規顧客'
  END AS customer_tier,
  RANK() OVER (PARTITION BY summary.region ORDER BY summary.total_sales DESC) AS rank_in_region,
  SUM(summary.total_sales) OVER (PARTITION BY summary.region) AS region_sales_total,
  ROUND(
    (
      SELECT AVG(s.total_sales)
      FROM `audeodb.sample_ds.v_ec_customer_summary` AS s
      WHERE s.region = summary.region
    ),
    0
  ) AS avg_sales_by_region
FROM `audeodb.sample_ds.v_ec_customer_summary` AS summary;
