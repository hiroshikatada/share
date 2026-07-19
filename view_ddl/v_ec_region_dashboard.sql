CREATE OR REPLACE VIEW `audeodb.sample_ds.v_ec_region_dashboard` AS
SELECT
  rank_view.customer_id,
  rank_view.customer_name,
  rank_view.region,
  rank_view.customer_segment,
  rank_view.customer_tier,
  rank_view.total_orders,
  rank_view.total_sales,
  rank_view.avg_order_value,
  rank_view.categories_bought,
  rank_view.rank_in_region,
  rank_view.region_sales_total,
  ROUND(rank_view.total_sales / NULLIF(rank_view.region_sales_total, 0) * 100, 1) AS share_of_region_sales_pct,
  CASE
    WHEN ROUND(rank_view.total_sales / NULLIF(rank_view.region_sales_total, 0) * 100, 1) >= 20 THEN '地域の主要顧客'
    WHEN rank_view.customer_tier = 'VIP' THEN 'VIP顧客'
    ELSE '一般顧客'
  END AS customer_role
FROM `audeodb.sample_ds.v_ec_customer_segment_rank` AS rank_view;
