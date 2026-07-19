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
