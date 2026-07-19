-- BigQuery用: Viewを依存関係の順に作成する一括実行SQL
-- 実行順: base -> summary -> segment_rank -> region_dashboard -> pivot -> pivot_4layer

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

CREATE OR REPLACE VIEW `audeodb.sample_ds.v_ec_customer_purchase_pivot_4layer` AS
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
),
customer_summary AS (
  SELECT
    customer_id,
    customer_name,
    region,
    customer_segment,
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(AVG(sales_amount), 0) AS avg_order_value,
    ARRAY_TO_STRING(
      ARRAY(
        SELECT DISTINCT product_category
        FROM UNNEST(
          ARRAY(
            SELECT DISTINCT b2.product_category
            FROM base AS b2
            WHERE b2.customer_id = base.customer_id
          )
        ) AS product_category
      ),
      ', '
    ) AS categories_bought
  FROM base
  GROUP BY
    customer_id,
    customer_name,
    region,
    customer_segment
),
pivoted AS (
  SELECT
    customer_id,
    customer_name,
    region,
    customer_segment,
    total_sales,
    total_orders,
    avg_order_value,
    categories_bought,
    SUM(CASE WHEN product_category = 'PC' THEN sales_amount ELSE 0 END) AS sales_pc,
    SUM(CASE WHEN product_category = 'AV' THEN sales_amount ELSE 0 END) AS sales_av,
    SUM(CASE WHEN product_category = '家電' THEN sales_amount ELSE 0 END) AS sales_home_appliance,
    SUM(CASE WHEN product_category = 'ウェアラブル' THEN sales_amount ELSE 0 END) AS sales_wearable
  FROM (
    SELECT
      base.customer_id,
      base.customer_name,
      base.region,
      base.customer_segment,
      base.sales_amount,
      base.product_category,
      customer_summary.total_sales,
      customer_summary.total_orders,
      customer_summary.avg_order_value,
      customer_summary.categories_bought
    FROM base
    JOIN customer_summary
      ON base.customer_id = customer_summary.customer_id
  )
  GROUP BY
    customer_id,
    customer_name,
    region,
    customer_segment,
    total_sales,
    total_orders,
    avg_order_value,
    categories_bought
)
SELECT
  customer_id,
  customer_name,
  region,
  customer_segment,
  total_sales,
  total_orders,
  avg_order_value,
  categories_bought,
  sales_pc,
  sales_av,
  sales_home_appliance,
  sales_wearable,
  CASE
    WHEN total_sales >= 200000 THEN 'VIP'
    WHEN total_sales >= 100000 THEN '高額顧客'
    WHEN total_orders >= 3 THEN 'リピート顧客'
    ELSE '新規顧客'
  END AS customer_tier,
  ROUND(total_sales / NULLIF(SUM(total_sales) OVER (PARTITION BY region), 0) * 100, 1) AS share_of_region_sales_pct
FROM pivoted
QUALIFY ROW_NUMBER() OVER (PARTITION BY region ORDER BY total_sales DESC) <= 3;
