# CHANGELOG v1.0.3

## 修正内容

- `05_validation_queries.sql` の全 `DECLARE` 文をスクリプト先頭へ移動。
- BigQuery Script の「変数宣言はブロックまたはスクリプトの先頭に配置する」制約に対応。
- v1.0.2までの以下の修正を継承。
  - 全SQLに `SET @@location = 'asia-northeast1';` を設定。
  - TIMESTAMP列への代入を `CURRENT_TIMESTAMP()` に統一。
  - ARRAY列から `NOT NULL` 制約を削除。
  - `CLUSTER BY` を最大4列に修正。
