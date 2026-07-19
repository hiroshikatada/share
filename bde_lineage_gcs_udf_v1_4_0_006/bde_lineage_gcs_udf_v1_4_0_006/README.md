# BDE Lineage GCS UDF v1.3.6

## 変更内容

v1.3.4は、CTEまたはサブクエリの`SELECT *` / `SELECT alias.*`で継承された列を、LineageResolverが上流の物理列まで再帰的に追跡できるようにしたリリースです。

### 主な修正

- `wildcard_expansions`の項目名不一致を修正
  - `select_item_seq`を正しく参照
- 派生Sourceのワイルドカード展開を再帰化
- 明示的なOutputColumnが存在しない展開列を、展開情報から解決
- 複数段CTEの`alias.*`を物理列まで追跡
- 循環防止と列名重複排除を追加

## 対象例

```sql
WITH base AS (
  SELECT customer_id, amount AS txn_total
  FROM project.dataset.sales
),
level_2 AS (
  SELECT b.* FROM base AS b
),
level_3 AS (
  SELECT l2.* FROM level_2 AS l2
)
SELECT final.customer_id, final.txn_total
FROM level_3 AS final;
```

v1.3.3では列参照自体は`RESOLVED`でも、Lineageが`PARTIALLY_RESOLVED`になる場合がありました。v1.3.4では物理列まで到達します。

## 実行

GCS上の`build/lineage_udf_bundle.js`を差し替え、既存の`bigquery/run_single_view_analysis.sql`を実行してください。

## v1.3.5

派生列の上流が文字列リテラル、NULL、COUNT(1)などで物理カラム依存を持たない場合、
下流CTEで参照された際に空のdependenciesがUNRESOLVEDへ変換される問題を修正しました。

LineageResolverは`DERIVED_NO_COLUMN_DEPENDENCY`を内部依存として伝播し、
CTE、UNION、ワイルドカードを経由しても正常な依存なしとして扱います。

複雑VIEW回帰テストではLineage警告が11件から4件へ減少しました。
残る4件はFROM句の匿名サブクエリに`subquery_scope_id`が設定されないケースです。

## v1.3.6

### 匿名FROMサブクエリのスコープ接続

`FROM (SELECT ...)`を、従来の部分的な`clauses/select_items`概要ではなく、
完全な`QUERY` ASTとして再帰解析するように変更しました。これにより、
`SourceResolver`が子スコープを生成し、`SUBQUERY`ソースへ
`subquery_scope_id`を設定できます。

`LineageResolver`は外側の列参照を匿名サブクエリの出力列へ接続し、
その先の物理列まで再帰追跡できるようになりました。

回帰テストでは次を確認しています。

- 匿名FROMサブクエリを経由する`customer_id`
- `AVG(amount)`から物理列`AMOUNT`までの追跡
- サブクエリ内の`ROW_NUMBER()`依存
- `V_EC_UNION_TRANSACTIONS`の物理メタデータがある場合、複雑SQLのLineage警告が0件

## v1.3.7

- `SELECT`句内の`SELECT AS STRUCT`サブクエリを回帰テストへ追加。
- 型付き配列リテラル`ARRAY<STRUCT<...>>[...]`をRAW_EXPRESSIONとして安全に保持。
- `SELECT * EXCEPT(...)`をWildcardとして認識し、除外列情報を保持。
- `STRUCT(... AS field)`および`ARRAY_AGG(... ORDER BY ... LIMIT ...)`など、ExpressionParser未対応のBigQuery固有構文で解析全体を停止しないフォールバックASTを追加。
- フォールバックAST内の識別子はColumnResolverが回収できる形で保持。


## v1.3.8

- RAW_EXPRESSION内の関数名を列参照から除外
  - `ARRAY_AGG`
  - `ARRAY_CONCAT`
  - 名前空間付き関数
- UNION / UNION ALL / UNION DISTINCTの後続branchで、無名式の出力列名を先頭branchから列位置で継承
- `alias.struct_column.field`をsource alias、トップレベル列、field pathへ分解
- `SELECT AS STRUCT`の子QueryをOutputColumnResolverの対象scopeへ追加
- STRUCT field参照を子Queryの同名出力列へ接続し、物理カラムまで追跡

主な回帰対象:

```sql
WITH x AS (
  SELECT (SELECT AS STRUCT amount AS detail_amount) AS txn_info
  FROM sales
)
SELECT t.txn_info.detail_amount AS total
FROM x AS t
```

期待経路:

```text
TOTAL
→ TXN_INFO.DETAIL_AMOUNT
→ SALES.AMOUNT
```

## v1.4.0-002

### 再帰CTEの自己参照をCTEとして解決

`WITH RECURSIVE`では、CTE本文の解析前に対象CTE名を仮登録します。
これにより、再帰branch内の`FROM order_path`などを物理テーブルではなく、
同一CTEのQuery Scopeへ接続された`CTE` Sourceとして扱います。

修正前:

```text
ORDER_PATH
→ PHYSICAL_TABLE
→ PHYSICAL_METADATA_NOT_FOUND
```

修正後:

```text
ORDER_PATH
→ CTE
→ cte_query_scope_id
```

### Wildcard経由のSTRUCT field lineage

`SELECT *`または`SELECT * EXCEPT(...)`を経由してSTRUCT列が継承された場合も、
元の`field_path`を保持して子Queryの同名フィールドへ接続します。

対象例:

```sql
WITH structured_txns AS (
  SELECT *, (
    SELECT AS STRUCT sales_amount AS detail_amount
  ) AS txn_info
  FROM all_txns
),
pure_struct_txns AS (
  SELECT * EXCEPT(sales_amount)
  FROM structured_txns
)
SELECT SUM(t.txn_info.detail_amount) AS txn_total
FROM pure_struct_txns AS t;
```

期待経路:

```text
TXN_TOTAL
→ T.TXN_INFO.DETAIL_AMOUNT
→ DETAIL_AMOUNT
→ SALES_AMOUNT
→ physical column
```

`DERIVED_NO_COLUMN_DEPENDENCY`を成功として返す偽の`RESOLVED`も回帰テストで検出します。

### 回帰テスト

- v1.1〜v1.3.8: PASS
- 再帰CTE自己参照: PASS
- Wildcard経由STRUCT field lineage: PASS
