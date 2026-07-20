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

## v1.5 lineage correctness test

Run the production-scale semantic golden test:

```bash
node test/test_v1_5_0_001.js
```

Expected physical paths are stored in:

```text
test/expected/v_ec_complex_union_lineage.json
```

The manifest separates verified paths from known gaps so that already-correct lineage cannot regress while unresolved semantic cases remain visible.

## Golden lineage regression suite (v1.5.0-003)

Run the syntax-focused golden suite:

```bash
node test/test_v1_5_0_003.js
```

Each case consists of:

```text
test/golden/fixtures/<case>.sql
test/golden/expected/<case>.json
```

The shared runner is:

```text
test/lib/golden_lineage_runner.js
```

Current coverage:

- basic expressions
- CASE expressions
- multi-level CTE propagation
- JOIN and aggregate lineage
- QUALIFY and window functions
- ARRAY_AGG / ARRAY / UNNEST propagation
- STRUCT outputs
- PIVOT generated columns
- SELECT * EXCEPT exclusion plus explicit expression lineage

Known follow-up targets discovered by isolated testing:

- merge dependencies from every UNION branch
- propagate scalar/correlated subquery dependencies to the parent output
- emit UNPIVOT generated columns
- emit standalone SELECT * expansion as named root output columns

## v1.5.0-004: UNION all-branch lineage

Issue #1 adds position-based dependency merging for `UNION`, `UNION ALL`, and `UNION DISTINCT`.
The output column name remains inherited from the first branch, while physical dependencies are collected from every branch into the lineage dependency array.

Run:

```bash
node test/test_v1_5_0_004.js
```

## Scalar Subquery lineage (v1.5.0-005)

Run Issue #2 regression tests:

```bash
node test/test_v1_5_0_005.js
```

Covered cases:

- a standalone scalar aggregate subquery
- a scalar subquery combined with an outer physical column
- a scalar subquery reading a derived column from a CTE

The child query's first output-column dependencies are propagated to the parent SELECT output.

## Correlated Subquery lineage (v1.5.0-006)

Issue numbers are independent from version numbers. Issue-0003 adds lineage propagation for correlated scalar subqueries and correlated `EXISTS` expressions.

Run:

```bash
node test/test_v1_5_0_006.js
```

Covered cases:

- a basic correlated scalar aggregate
- a correlated scalar subquery combined with an outer expression
- a correlated scalar subquery reading through a CTE
- a correlated `EXISTS` expression whose child SELECT returns a constant

When a child query contains an outer-scope reference, dependencies from the child query's predicate clauses are merged into the parent output. Both sides of the correlation condition are retained because both determine the resulting value.

## v1.5.0-007 — Issue-0004-1 Wildcard Expansion (`SELECT *`)

Unqualified `SELECT *` is expanded into independent output-column lineage records.
The expansion works for physical tables, CTEs, and subqueries, while preserving
one-to-one physical dependencies and source column order. The original wildcard
lineage is retained as structural audit information; expanded records include
`expanded_from_wildcard: true`.

Issue workflow and Definition of Done:

- Golden cases added
- Pre-fix failure reproduced
- Implementation completed
- New golden suite passed
- Full regression suite passed
- Performance sanity check completed
- CHANGELOG and VERSION updated
- User verification pending

## v1.5.0-008 — Issue-0004-2

Qualified wildcard expressions such as `c.*` are expanded only from the resolved alias source. Physical-table, JOIN, CTE, and subquery paths are covered by golden tests. Expanded lineage preserves the originating qualified expression in `expression_text` for auditability.

## v1.5.0-009: Issue-0004-3 Wildcard Expansion (`* EXCEPT`)

`SELECT * EXCEPT(...)` and `SELECT alias.* EXCEPT(...)` are expanded into independent output-column lineage rows while excluded columns remain absent. The original wildcard expression, including its alias and exclusion list, is retained in `expression_text` for auditability.

Golden coverage includes physical tables, JOIN source qualification, CTEs, subqueries, and multiple exclusions.

## v1.5.0-010 — Issue-0004-4

Wildcard Expansion now supports BigQuery `* REPLACE(...)` syntax. Replaced
columns retain their output position and name while their physical dependencies
are resolved from the replacement expression. Single, multiple, qualified,
and CTE-backed replacements are covered by golden regression tests.

With Issue-0004-1 through Issue-0004-4 complete, the Wildcard Expansion Epic
covers `SELECT *`, `alias.*`, `* EXCEPT(...)`, and `* REPLACE(...)`.

## v1.5.0-012 — Issue-0100-1 Complex SQL

Golden cases now require `purpose` and `coverage` metadata. Four combination cases certify CTE/JOIN/Wildcard/QUALIFY, UNION/Scalar Subquery, Correlated EXISTS/CASE, and PIVOT/CTE behavior.


## v1.5.0-013

Issue-0100-3 Production SQL adds ETL, Reporting View, Data Mart, and Incremental Load certification cases.

- Golden Cases: 46
- Verified Outputs: 121

## Performance Regression

Run the versioned performance certification with:

```bash
node test/test_v1_5_0_014.js
```

The performance contract uses warm-up runs, median and p95 latency, stability ratio, heap delta, and full-suite throughput. Thresholds are intentionally environment-tolerant while still detecting hangs, severe slowdowns, unstable execution and abnormal memory growth.
