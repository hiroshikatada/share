# Boss SQL Notes

## CTE責務

1. customer_base — 顧客マスタ正規化
2. purchase_base — 有効購買抽出
3. product_base — 商品マスタ正規化
4. purchase_fact — 購買Fact
5. customer_sales — 顧客別集計
6. latest_purchase — 最新購買
7. purchase_chain — ARRAY<STRUCT>直近購買
8. category_sales_source — PIVOT入力とUNION ALL
9. category_sales — カテゴリ別PIVOT
10. customer_business — 業務指標、EXISTS、Scalar Subquery
11. customer_rank — Window集計と地域順位
12. customer_dashboard — 表示統合
13. final_output — EXCEPT、REPLACE、UNNESTによる出力整形

## 構文カバレッジ

CTE、LEFT JOIN、UNION ALL、ARRAY_AGG、STRUCT、UNNEST、CASE、COALESCE、集約、Window、ROW_NUMBER、QUALIFY、PIVOT、Scalar Subquery、Correlated EXISTS、Wildcard、EXCEPT、REPLACE。
