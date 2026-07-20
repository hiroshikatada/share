CREATE OR REPLACE VIEW `audeodb.sample_ds.boss_customer_sales_mart` AS
WITH
customer_base AS (
  SELECT customer_id, customer_name, COALESCE(region,'UNKNOWN') AS region,
    COALESCE(customer_segment,'UNCLASSIFIED') AS customer_segment,
    signup_date, gender, DATE_DIFF(CURRENT_DATE(),signup_date,DAY) AS customer_age_days
  FROM `audeodb.sample_ds.customer_master`
  WHERE customer_id IS NOT NULL
),
purchase_base AS (
  SELECT order_id, customer_id, product_id, purchase_date, quantity, unit_price,
    sales_amount, discount_amount, payment_method, channel, order_status
  FROM `audeodb.sample_ds.customer_purchase_history`
  WHERE order_status NOT IN ('CANCELLED','VOID')
),
product_base AS (
  SELECT product_id, product_name, COALESCE(category,'OTHER') AS product_category,
    unit_price AS master_unit_price, stock_qty, release_date, brand
  FROM `audeodb.sample_ds.product_master`
),
purchase_fact AS (
  SELECT p.*, m.product_name, m.product_category, m.master_unit_price, m.stock_qty,
    m.release_date, m.brand,
    p.sales_amount-COALESCE(p.discount_amount,0) AS net_sales_amount,
    p.unit_price-m.master_unit_price AS unit_price_variance,
    STRUCT(p.payment_method AS payment_method,p.channel AS channel,p.order_status AS order_status) AS transaction_attributes
  FROM purchase_base AS p
  LEFT JOIN product_base AS m ON p.product_id=m.product_id
),
customer_sales AS (
  SELECT customer_id, COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT product_id) AS distinct_products, SUM(quantity) AS total_quantity,
    SUM(sales_amount) AS gross_sales, SUM(discount_amount) AS total_discount,
    SUM(net_sales_amount) AS total_sales, AVG(net_sales_amount) AS avg_line_sales,
    MAX(net_sales_amount) AS max_line_sales, MIN(purchase_date) AS first_purchase_date,
    MAX(purchase_date) AS last_purchase_date, COUNTIF(channel='EC') AS ec_line_count,
    COUNTIF(channel='STORE') AS store_line_count
  FROM purchase_fact GROUP BY customer_id
),
latest_purchase AS (
  SELECT customer_id, order_id AS latest_order_id, purchase_date AS latest_purchase_date,
    product_name AS latest_product_name, product_category AS latest_product_category,
    net_sales_amount AS latest_sales_amount, transaction_attributes AS latest_transaction_attributes
  FROM purchase_fact
  QUALIFY ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY purchase_date DESC,order_id DESC)=1
),
purchase_chain AS (
  SELECT customer_id,
    ARRAY_AGG(STRUCT(order_id,purchase_date,product_id,product_name,product_category,
      net_sales_amount AS sales_amount,
      STRUCT(payment_method AS payment_method,channel AS channel) AS transaction_header)
      ORDER BY purchase_date DESC,order_id DESC LIMIT 5) AS recent_purchase_chain
  FROM purchase_fact GROUP BY customer_id
),
category_sales_source AS (
  SELECT customer_id, product_category, net_sales_amount FROM purchase_fact
  UNION ALL
  SELECT customer_id, 'ALL_CATEGORIES', net_sales_amount FROM purchase_fact
),
category_sales AS (
  SELECT customer_id,COALESCE(PC,0) AS sales_pc,COALESCE(AV,0) AS sales_av,
    COALESCE(HOME_APPLIANCE,0) AS sales_home_appliance,
    COALESCE(WEARABLE,0) AS sales_wearable,
    COALESCE(ALL_CATEGORIES,0) AS sales_all_categories
  FROM category_sales_source
  PIVOT(SUM(net_sales_amount) FOR product_category IN
    ('PC' AS PC,'AV' AS AV,'HOME_APPLIANCE' AS HOME_APPLIANCE,
     'WEARABLE' AS WEARABLE,'ALL_CATEGORIES' AS ALL_CATEGORIES))
),
customer_business AS (
  SELECT c.*, COALESCE(s.total_orders,0) AS total_orders,
    COALESCE(s.distinct_products,0) AS distinct_products,
    COALESCE(s.total_quantity,0) AS total_quantity,
    COALESCE(s.gross_sales,0) AS gross_sales,
    COALESCE(s.total_discount,0) AS total_discount,
    COALESCE(s.total_sales,0) AS total_sales,
    COALESCE(s.avg_line_sales,0) AS avg_line_sales,
    COALESCE(s.max_line_sales,0) AS max_line_sales,
    s.first_purchase_date,s.last_purchase_date,
    COALESCE(s.ec_line_count,0) AS ec_line_count,
    COALESCE(s.store_line_count,0) AS store_line_count,
    l.latest_order_id,l.latest_purchase_date,l.latest_product_name,
    l.latest_product_category,l.latest_sales_amount,l.latest_transaction_attributes,
    pc.recent_purchase_chain,cs.sales_pc,cs.sales_av,cs.sales_home_appliance,
    cs.sales_wearable,cs.sales_all_categories,
    SAFE_DIVIDE(COALESCE(s.total_sales,0),NULLIF(COALESCE(s.total_orders,0),0)) AS avg_order_value,
    CASE WHEN COALESCE(s.total_sales,0)>=1000000 THEN 'PLATINUM'
      WHEN COALESCE(s.total_sales,0)>=500000 THEN 'GOLD'
      WHEN COALESCE(s.total_sales,0)>=100000 THEN 'SILVER' ELSE 'STANDARD' END AS customer_tier,
    EXISTS(SELECT 1 FROM purchase_fact r WHERE r.customer_id=c.customer_id
      AND r.purchase_date>=DATE_SUB(CURRENT_DATE(),INTERVAL 90 DAY)) AS has_recent_purchase,
    (SELECT AVG(x.order_sales) FROM (
      SELECT order_id,SUM(net_sales_amount) AS order_sales
      FROM purchase_fact o WHERE o.customer_id=c.customer_id
      GROUP BY order_id ORDER BY MAX(purchase_date) DESC LIMIT 3) x) AS avg_last_3_orders
  FROM customer_base c
  LEFT JOIN customer_sales s ON c.customer_id=s.customer_id
  LEFT JOIN latest_purchase l ON c.customer_id=l.customer_id
  LEFT JOIN purchase_chain pc ON c.customer_id=pc.customer_id
  LEFT JOIN category_sales cs ON c.customer_id=cs.customer_id
),
customer_rank AS (
  SELECT b.*,
    SUM(total_sales) OVER(PARTITION BY region) AS region_sales_total,
    DENSE_RANK() OVER(PARTITION BY region ORDER BY total_sales DESC) AS rank_in_region,
    SAFE_MULTIPLY(SAFE_DIVIDE(total_sales,NULLIF(SUM(total_sales) OVER(PARTITION BY region),0)),100) AS share_of_region_sales_pct
  FROM customer_business b
),
customer_dashboard AS (
  SELECT r.* EXCEPT(customer_age_days,gross_sales,total_discount,sales_all_categories),
    STRUCT(total_orders AS order_count,total_sales AS sales_amount,
      avg_order_value AS average_order_value,rank_in_region AS regional_rank) AS kpi_summary,
    CASE WHEN has_recent_purchase AND total_sales>=500000 THEN 'ACTIVE_HIGH_VALUE'
      WHEN has_recent_purchase THEN 'ACTIVE' WHEN total_orders>0 THEN 'DORMANT'
      ELSE 'PROSPECT' END AS customer_status
  FROM customer_rank r
),
final_output AS (
  SELECT d.* EXCEPT(latest_transaction_attributes)
    REPLACE(ROUND(total_sales,2) AS total_sales,
      ROUND(avg_order_value,2) AS avg_order_value,
      ROUND(avg_last_3_orders,2) AS avg_last_3_orders,
      ROUND(share_of_region_sales_pct,2) AS share_of_region_sales_pct),
    latest_transaction_attributes.payment_method AS latest_payment_method,
    latest_transaction_attributes.channel AS latest_channel,
    ARRAY_TO_STRING(ARRAY(SELECT item.product_name
      FROM UNNEST(recent_purchase_chain) item ORDER BY item.purchase_date DESC),' > ') AS recent_product_chain
  FROM customer_dashboard d
)
SELECT * FROM final_output;
