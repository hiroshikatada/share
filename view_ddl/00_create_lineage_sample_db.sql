-- BigQuery Physical Lineage 検証用サンプルDB
-- 対象データセット: audeodb.sample_ds
--
-- 作成するテーブル:
--   1. customer_master
--   2. product_master
--   3. customer_purchase_history
--
-- customer_purchase_history には、COLUMN_FIELD_PATHS検証用として
-- STRUCT/RECORDおよびARRAY<STRUCT>列も含めています。

SET @@location = 'asia-northeast1';

-- データセットが存在しない環境でも実行できるように作成します。
CREATE SCHEMA IF NOT EXISTS `audeodb.sample_ds`
OPTIONS (
  location = 'asia-northeast1',
  description = 'BigQuery lineage repository validation sample dataset'
);

-- ============================================================
-- 1. 顧客マスタ
-- ============================================================
CREATE OR REPLACE TABLE `audeodb.sample_ds.customer_master`
(
  customer_id STRING NOT NULL OPTIONS(description = '顧客ID'),
  customer_name STRING OPTIONS(description = '顧客名'),
  region STRING OPTIONS(description = '地域'),
  customer_segment STRING OPTIONS(description = '顧客セグメント'),

  -- STRUCT/RECORDのfield_path検証用
  contact_info STRUCT<
    email STRING,
    phone STRING,
    preferred_contact STRING
  > OPTIONS(description = '連絡先情報'),

  -- ARRAY<STRING>の検証用
  tags ARRAY<STRING> OPTIONS(description = '顧客タグ'),

  registered_at TIMESTAMP OPTIONS(description = '登録日時')
)
OPTIONS (
  description = 'Lineage検証用顧客マスタ'
);

INSERT INTO `audeodb.sample_ds.customer_master`
(
  customer_id,
  customer_name,
  region,
  customer_segment,
  contact_info,
  tags,
  registered_at
)
VALUES
  ('C001', '佐藤 太郎', '関東', '個人', STRUCT('taro.sato@example.com', '090-1000-0001', 'email'), ['VIP候補', 'オンライン'], TIMESTAMP '2024-01-05 09:00:00+09'),
  ('C002', '鈴木 花子', '関東', '法人', STRUCT('hanako.suzuki@example.com', '090-1000-0002', 'phone'), ['法人', '店舗'], TIMESTAMP '2024-01-10 10:30:00+09'),
  ('C003', '高橋 健',   '関西', 'EC',   STRUCT('ken.takahashi@example.com', '090-1000-0003', 'email'), ['EC', 'リピーター'], TIMESTAMP '2024-02-01 11:00:00+09'),
  ('C004', '田中 美咲', '関西', '個人', STRUCT('misaki.tanaka@example.com', '090-1000-0004', 'sms'), ['新規', 'オンライン'], TIMESTAMP '2024-02-14 13:20:00+09'),
  ('C005', '伊藤 誠',   '中部', '法人', STRUCT('makoto.ito@example.com', '090-1000-0005', 'phone'), ['法人', '高額購入'], TIMESTAMP '2024-03-03 08:45:00+09'),
  ('C006', '渡辺 彩',   '中部', '個人', STRUCT('aya.watanabe@example.com', '090-1000-0006', 'email'), ['ウェアラブル', 'オンライン'], TIMESTAMP '2024-03-18 15:00:00+09'),
  ('C007', '山本 翔',   '九州', 'EC',   STRUCT('sho.yamamoto@example.com', '090-1000-0007', 'email'), ['EC', 'PC'], TIMESTAMP '2024-04-02 09:15:00+09'),
  ('C008', '中村 恵',   '九州', '個人', STRUCT('megumi.nakamura@example.com', '090-1000-0008', 'sms'), ['家電', '店舗'], TIMESTAMP '2024-04-21 12:10:00+09'),
  ('C009', '小林 直樹', '北海道', '法人', STRUCT('naoki.kobayashi@example.com', '090-1000-0009', 'phone'), ['法人', 'AV'], TIMESTAMP '2024-05-06 14:40:00+09'),
  ('C010', '加藤 由美', '北海道', 'EC', STRUCT('yumi.kato@example.com', '090-1000-0010', 'email'), ['EC', '新規'], TIMESTAMP '2024-05-30 16:00:00+09');

-- ============================================================
-- 2. 商品マスタ
-- ============================================================
CREATE OR REPLACE TABLE `audeodb.sample_ds.product_master`
(
  product_id STRING NOT NULL OPTIONS(description = '商品ID'),
  product_name STRING OPTIONS(description = '商品名'),
  category STRING OPTIONS(description = '商品カテゴリ'),
  list_price NUMERIC OPTIONS(description = '標準価格'),

  -- 多階層STRUCTのfield_path検証用
  product_spec STRUCT<
    manufacturer STRING,
    model_number STRING,
    dimensions STRUCT<
      width_cm FLOAT64,
      height_cm FLOAT64,
      depth_cm FLOAT64
    >,
    attributes ARRAY<STRUCT<
      attribute_name STRING,
      attribute_value STRING
    >>
  > OPTIONS(description = '商品仕様'),

  is_active BOOL OPTIONS(description = '販売中フラグ')
)
OPTIONS (
  description = 'Lineage検証用商品マスタ'
);

INSERT INTO `audeodb.sample_ds.product_master`
(
  product_id,
  product_name,
  category,
  list_price,
  product_spec,
  is_active
)
VALUES
  ('P001', 'ノートPC Pro 14', 'PC', 158000,
    STRUCT('Audeo Computing', 'AC-PRO14', STRUCT(31.2, 1.7, 22.1), [STRUCT('CPU', 'Core Ultra 7'), STRUCT('Memory', '16GB')]), TRUE),
  ('P002', 'ノートPC Air 13', 'PC', 98000,
    STRUCT('Audeo Computing', 'AC-AIR13', STRUCT(29.7, 1.5, 21.0), [STRUCT('CPU', 'Core Ultra 5'), STRUCT('Memory', '8GB')]), TRUE),
  ('P003', '4Kテレビ 55型', 'AV', 128000,
    STRUCT('Audeo Vision', 'AV-TV55', STRUCT(122.5, 71.5, 6.8), [STRUCT('Resolution', '4K'), STRUCT('Panel', 'OLED')]), TRUE),
  ('P004', 'ワイヤレススピーカー', 'AV', 32000,
    STRUCT('Audeo Sound', 'AS-SP01', STRUCT(18.0, 25.0, 16.0), [STRUCT('Bluetooth', '5.3'), STRUCT('Battery', '12h')]), TRUE),
  ('P005', 'ドラム式洗濯乾燥機', '家電', 218000,
    STRUCT('Audeo Home', 'AH-WD10', STRUCT(63.0, 106.0, 72.0), [STRUCT('Capacity', '10kg'), STRUCT('Dry', '6kg')]), TRUE),
  ('P006', 'ロボット掃除機', '家電', 68000,
    STRUCT('Audeo Home', 'AH-RC02', STRUCT(35.0, 9.6, 35.0), [STRUCT('Mapping', 'LiDAR'), STRUCT('Runtime', '180min')]), TRUE),
  ('P007', 'スマートウォッチ', 'ウェアラブル', 42000,
    STRUCT('Audeo Wear', 'AW-SW03', STRUCT(4.5, 1.1, 3.8), [STRUCT('GPS', 'Yes'), STRUCT('Waterproof', '5ATM')]), TRUE),
  ('P008', 'フィットネスバンド', 'ウェアラブル', 18000,
    STRUCT('Audeo Wear', 'AW-FB01', STRUCT(4.0, 1.0, 2.0), [STRUCT('HeartRate', 'Yes'), STRUCT('Battery', '10days')]), TRUE);

-- ============================================================
-- 3. 購買履歴
-- ============================================================
CREATE OR REPLACE TABLE `audeodb.sample_ds.customer_purchase_history`
(
  order_id STRING NOT NULL OPTIONS(description = '注文ID'),
  customer_id STRING NOT NULL OPTIONS(description = '顧客ID'),
  product_id STRING NOT NULL OPTIONS(description = '商品ID'),
  purchase_date DATE OPTIONS(description = '購入日'),
  unit_price NUMERIC OPTIONS(description = '単価'),
  quantity INT64 OPTIONS(description = '数量'),
  discount_rate FLOAT64 OPTIONS(description = '割引率'),
  order_status STRING OPTIONS(description = '注文状態'),
  payment_method STRING OPTIONS(description = '支払方法'),
  channel STRING OPTIONS(description = '販売チャネル'),

  -- ネストしたSTRUCT/RECORD。
  -- COLUMN_FIELD_PATHSでは delivery_address.prefecture などを取得できます。
  delivery_address STRUCT<
    postal_code STRING,
    prefecture STRING,
    city STRING,
    address_line STRING,
    contact STRUCT<
      recipient_name STRING,
      phone STRING
    >
  > OPTIONS(description = '配送先'),

  -- ARRAY<STRUCT>。
  -- order_items.product.product_id のような多階層field_path検証用です。
  order_items ARRAY<STRUCT<
    line_number INT64,
    product STRUCT<
      product_id STRING,
      product_name STRING,
      category STRING
    >,
    quantity INT64,
    unit_price NUMERIC
  >> OPTIONS(description = '注文明細'),

  -- ARRAY<STRUCT>の別パターン
  status_history ARRAY<STRUCT<
    status STRING,
    changed_at TIMESTAMP,
    operator STRUCT<
      operator_id STRING,
      operator_name STRING
    >
  >> OPTIONS(description = '注文ステータス履歴'),

  created_at TIMESTAMP OPTIONS(description = '登録日時')
)
PARTITION BY purchase_date
CLUSTER BY customer_id, product_id, order_status, channel
OPTIONS (
  description = 'Lineage検証用購買履歴。STRUCT、RECORD、ARRAYを含む'
);

-- サンプル注文を簡潔に記述し、STRUCT/ARRAY列はSELECT内で生成します。
INSERT INTO `audeodb.sample_ds.customer_purchase_history`
SELECT
  order_id,
  customer_id,
  product_id,
  purchase_date,
  unit_price,
  quantity,
  discount_rate,
  order_status,
  payment_method,
  channel,
  STRUCT(
    postal_code AS postal_code,
    prefecture AS prefecture,
    city AS city,
    CONCAT(city, ' 1-2-3') AS address_line,
    STRUCT(
      recipient_name AS recipient_name,
      phone AS phone
    ) AS contact
  ) AS delivery_address,
  [
    STRUCT(
      1 AS line_number,
      STRUCT(
        product_id AS product_id,
        product_name AS product_name,
        category AS category
      ) AS product,
      quantity AS quantity,
      unit_price AS unit_price
    )
  ] AS order_items,
  CASE
    WHEN order_status = 'completed' THEN [
      STRUCT('ordered', TIMESTAMP(DATETIME(purchase_date, TIME '09:00:00'), 'Asia/Tokyo'), STRUCT('SYS' AS operator_id, '自動受付' AS operator_name)),
      STRUCT('completed', TIMESTAMP(DATETIME(purchase_date, TIME '18:00:00'), 'Asia/Tokyo'), STRUCT('OP01' AS operator_id, '出荷担当A' AS operator_name))
    ]
    WHEN order_status IN ('refunded', 'returned') THEN [
      STRUCT('ordered', TIMESTAMP(DATETIME(purchase_date, TIME '09:00:00'), 'Asia/Tokyo'), STRUCT('SYS' AS operator_id, '自動受付' AS operator_name)),
      STRUCT('completed', TIMESTAMP(DATETIME(purchase_date, TIME '18:00:00'), 'Asia/Tokyo'), STRUCT('OP01' AS operator_id, '出荷担当A' AS operator_name)),
      STRUCT(order_status, TIMESTAMP(DATETIME(DATE_ADD(purchase_date, INTERVAL 3 DAY), TIME '10:00:00'), 'Asia/Tokyo'), STRUCT('CS01' AS operator_id, '顧客対応A' AS operator_name))
    ]
    ELSE [
      STRUCT(order_status, TIMESTAMP(DATETIME(purchase_date, TIME '09:00:00'), 'Asia/Tokyo'), STRUCT('SYS' AS operator_id, '自動受付' AS operator_name))
    ]
  END AS status_history,
  TIMESTAMP(DATETIME(purchase_date, TIME '08:30:00'), 'Asia/Tokyo') AS created_at
FROM UNNEST([
  STRUCT('O0001' AS order_id, 'C001' AS customer_id, 'P001' AS product_id, DATE '2025-01-05' AS purchase_date, NUMERIC '158000' AS unit_price, 1 AS quantity, 0.05 AS discount_rate, 'completed' AS order_status, 'credit_card' AS payment_method, 'online' AS channel, '154-0000' AS postal_code, '東京都' AS prefecture, '世田谷区' AS city, '佐藤 太郎' AS recipient_name, '090-1000-0001' AS phone, 'ノートPC Pro 14' AS product_name, 'PC' AS category),
  STRUCT('O0002','C001','P007',DATE '2025-01-06',NUMERIC '42000',1,0.00,'completed','credit_card','online','154-0000','東京都','世田谷区','佐藤 太郎','090-1000-0001','スマートウォッチ','ウェアラブル'),
  STRUCT('O0003','C001','P004',DATE '2025-01-07',NUMERIC '32000',2,0.10,'completed','credit_card','store','154-0000','東京都','世田谷区','佐藤 太郎','090-1000-0001','ワイヤレススピーカー','AV'),
  STRUCT('O0004','C001','P006',DATE '2025-02-10',NUMERIC '68000',1,0.00,'refunded','credit_card','online','154-0000','東京都','世田谷区','佐藤 太郎','090-1000-0001','ロボット掃除機','家電'),
  STRUCT('O0005','C002','P005',DATE '2025-01-12',NUMERIC '218000',1,0.08,'completed','bank_transfer','store','220-0000','神奈川県','横浜市','鈴木 花子','090-1000-0002','ドラム式洗濯乾燥機','家電'),
  STRUCT('O0006','C002','P003',DATE '2025-02-15',NUMERIC '128000',1,0.05,'completed','bank_transfer','store','220-0000','神奈川県','横浜市','鈴木 花子','090-1000-0002','4Kテレビ 55型','AV'),
  STRUCT('O0007','C002','P004',DATE '2025-03-01',NUMERIC '32000',3,0.10,'completed','invoice','online','220-0000','神奈川県','横浜市','鈴木 花子','090-1000-0002','ワイヤレススピーカー','AV'),
  STRUCT('O0008','C002','P008',DATE '2025-03-20',NUMERIC '18000',5,0.15,'returned','invoice','online','220-0000','神奈川県','横浜市','鈴木 花子','090-1000-0002','フィットネスバンド','ウェアラブル'),
  STRUCT('O0009','C003','P002',DATE '2025-01-20',NUMERIC '98000',1,0.00,'completed','credit_card','online','530-0000','大阪府','大阪市','高橋 健','090-1000-0003','ノートPC Air 13','PC'),
  STRUCT('O0010','C003','P007',DATE '2025-01-21',NUMERIC '42000',1,0.05,'completed','credit_card','online','530-0000','大阪府','大阪市','高橋 健','090-1000-0003','スマートウォッチ','ウェアラブル'),
  STRUCT('O0011','C003','P006',DATE '2025-01-22',NUMERIC '68000',1,0.10,'completed','wallet','online','530-0000','大阪府','大阪市','高橋 健','090-1000-0003','ロボット掃除機','家電'),
  STRUCT('O0012','C003','P004',DATE '2025-04-05',NUMERIC '32000',1,0.00,'completed','wallet','online','530-0000','大阪府','大阪市','高橋 健','090-1000-0003','ワイヤレススピーカー','AV'),
  STRUCT('O0013','C004','P008',DATE '2025-02-01',NUMERIC '18000',1,0.00,'completed','cash','store','650-0000','兵庫県','神戸市','田中 美咲','090-1000-0004','フィットネスバンド','ウェアラブル'),
  STRUCT('O0014','C004','P004',DATE '2025-02-18',NUMERIC '32000',1,0.00,'completed','cash','store','650-0000','兵庫県','神戸市','田中 美咲','090-1000-0004','ワイヤレススピーカー','AV'),
  STRUCT('O0015','C004','P003',DATE '2025-05-03',NUMERIC '128000',1,0.12,'cancelled','credit_card','online','650-0000','兵庫県','神戸市','田中 美咲','090-1000-0004','4Kテレビ 55型','AV'),
  STRUCT('O0016','C005','P001',DATE '2025-01-08',NUMERIC '158000',2,0.10,'completed','invoice','store','460-0000','愛知県','名古屋市','伊藤 誠','090-1000-0005','ノートPC Pro 14','PC'),
  STRUCT('O0017','C005','P005',DATE '2025-02-08',NUMERIC '218000',1,0.05,'completed','invoice','store','460-0000','愛知県','名古屋市','伊藤 誠','090-1000-0005','ドラム式洗濯乾燥機','家電'),
  STRUCT('O0018','C005','P003',DATE '2025-03-08',NUMERIC '128000',2,0.08,'completed','bank_transfer','online','460-0000','愛知県','名古屋市','伊藤 誠','090-1000-0005','4Kテレビ 55型','AV'),
  STRUCT('O0019','C005','P007',DATE '2025-04-08',NUMERIC '42000',4,0.10,'completed','bank_transfer','online','460-0000','愛知県','名古屋市','伊藤 誠','090-1000-0005','スマートウォッチ','ウェアラブル'),
  STRUCT('O0020','C006','P007',DATE '2025-02-11',NUMERIC '42000',1,0.00,'completed','credit_card','online','420-0000','静岡県','静岡市','渡辺 彩','090-1000-0006','スマートウォッチ','ウェアラブル'),
  STRUCT('O0021','C006','P008',DATE '2025-02-12',NUMERIC '18000',2,0.05,'completed','credit_card','online','420-0000','静岡県','静岡市','渡辺 彩','090-1000-0006','フィットネスバンド','ウェアラブル'),
  STRUCT('O0022','C006','P002',DATE '2025-06-01',NUMERIC '98000',1,0.10,'completed','wallet','store','420-0000','静岡県','静岡市','渡辺 彩','090-1000-0006','ノートPC Air 13','PC'),
  STRUCT('O0023','C007','P001',DATE '2025-01-15',NUMERIC '158000',1,0.00,'completed','credit_card','online','810-0000','福岡県','福岡市','山本 翔','090-1000-0007','ノートPC Pro 14','PC'),
  STRUCT('O0024','C007','P002',DATE '2025-01-16',NUMERIC '98000',1,0.05,'completed','credit_card','online','810-0000','福岡県','福岡市','山本 翔','090-1000-0007','ノートPC Air 13','PC'),
  STRUCT('O0025','C007','P004',DATE '2025-01-17',NUMERIC '32000',2,0.00,'completed','wallet','online','810-0000','福岡県','福岡市','山本 翔','090-1000-0007','ワイヤレススピーカー','AV'),
  STRUCT('O0026','C007','P007',DATE '2025-03-10',NUMERIC '42000',1,0.00,'refunded','wallet','online','810-0000','福岡県','福岡市','山本 翔','090-1000-0007','スマートウォッチ','ウェアラブル'),
  STRUCT('O0027','C008','P006',DATE '2025-02-06',NUMERIC '68000',1,0.05,'completed','cash','store','860-0000','熊本県','熊本市','中村 恵','090-1000-0008','ロボット掃除機','家電'),
  STRUCT('O0028','C008','P005',DATE '2025-04-10',NUMERIC '218000',1,0.10,'completed','credit_card','store','860-0000','熊本県','熊本市','中村 恵','090-1000-0008','ドラム式洗濯乾燥機','家電'),
  STRUCT('O0029','C008','P008',DATE '2025-05-10',NUMERIC '18000',3,0.00,'completed','credit_card','online','860-0000','熊本県','熊本市','中村 恵','090-1000-0008','フィットネスバンド','ウェアラブル'),
  STRUCT('O0030','C009','P003',DATE '2025-01-25',NUMERIC '128000',2,0.10,'completed','invoice','store','060-0000','北海道','札幌市','小林 直樹','090-1000-0009','4Kテレビ 55型','AV'),
  STRUCT('O0031','C009','P004',DATE '2025-02-25',NUMERIC '32000',4,0.05,'completed','invoice','store','060-0000','北海道','札幌市','小林 直樹','090-1000-0009','ワイヤレススピーカー','AV'),
  STRUCT('O0032','C009','P001',DATE '2025-03-25',NUMERIC '158000',1,0.08,'completed','bank_transfer','online','060-0000','北海道','札幌市','小林 直樹','090-1000-0009','ノートPC Pro 14','PC'),
  STRUCT('O0033','C009','P006',DATE '2025-04-25',NUMERIC '68000',1,0.00,'returned','bank_transfer','online','060-0000','北海道','札幌市','小林 直樹','090-1000-0009','ロボット掃除機','家電'),
  STRUCT('O0034','C010','P008',DATE '2025-03-02',NUMERIC '18000',1,0.00,'completed','wallet','online','040-0000','北海道','函館市','加藤 由美','090-1000-0010','フィットネスバンド','ウェアラブル'),
  STRUCT('O0035','C010','P007',DATE '2025-03-03',NUMERIC '42000',1,0.00,'completed','wallet','online','040-0000','北海道','函館市','加藤 由美','090-1000-0010','スマートウォッチ','ウェアラブル'),
  STRUCT('O0036','C010','P002',DATE '2025-03-04',NUMERIC '98000',1,0.05,'completed','credit_card','online','040-0000','北海道','函館市','加藤 由美','090-1000-0010','ノートPC Air 13','PC'),
  STRUCT('O0037','C010','P004',DATE '2025-05-15',NUMERIC '32000',1,0.00,'completed','credit_card','store','040-0000','北海道','函館市','加藤 由美','090-1000-0010','ワイヤレススピーカー','AV'),
  STRUCT('O0038','C003','P005',DATE '2025-06-15',NUMERIC '218000',1,0.15,'completed','credit_card','online','530-0000','大阪府','大阪市','高橋 健','090-1000-0003','ドラム式洗濯乾燥機','家電'),
  STRUCT('O0039','C006','P003',DATE '2025-06-20',NUMERIC '128000',1,0.05,'refunded','credit_card','online','420-0000','静岡県','静岡市','渡辺 彩','090-1000-0006','4Kテレビ 55型','AV'),
  STRUCT('O0040','C008','P001',DATE '2025-06-25',NUMERIC '158000',1,0.10,'completed','credit_card','online','860-0000','熊本県','熊本市','中村 恵','090-1000-0008','ノートPC Pro 14','PC')
]);

-- ============================================================
-- 作成結果の簡易確認
-- ============================================================
SELECT 'customer_master' AS table_name, COUNT(*) AS row_count
FROM `audeodb.sample_ds.customer_master`
UNION ALL
SELECT 'product_master', COUNT(*)
FROM `audeodb.sample_ds.product_master`
UNION ALL
SELECT 'customer_purchase_history', COUNT(*)
FROM `audeodb.sample_ds.customer_purchase_history`
ORDER BY table_name;

-- COLUMN_FIELD_PATHS確認例
SELECT
  table_name,
  column_name,
  field_path,
  data_type
FROM `audeodb.sample_ds.INFORMATION_SCHEMA.COLUMN_FIELD_PATHS`
WHERE table_name IN (
  'customer_master',
  'product_master',
  'customer_purchase_history'
)
ORDER BY table_name, column_name, field_path;
