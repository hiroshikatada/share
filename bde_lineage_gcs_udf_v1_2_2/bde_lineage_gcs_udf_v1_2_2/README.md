# BigQuery Lineage GCS UDF v1.2

## v1.2 changes

- Supports `ARRAY(SELECT ...)` as an array-subquery expression.
- Parses scalar subqueries inside expressions as complete `QUERY` AST nodes.
- Supports nested combinations such as `CASE -> ARRAY_TO_STRING -> ARRAY(SELECT ...)`.
- Keeps existing `FROM/JOIN UNNEST(...)` support and connects UNNEST expressions to lineage analysis.
- Creates child query scopes for expression subqueries.
- Resolves correlated references by searching the current scope and then parent scopes.
- Retains the v1.1 JSON contract:
  - `analysis`: one analysis object
  - `exported_tables`: normalized row arrays
- Retains BigQuery trailing commas in SELECT lists as valid syntax.

## Deployment

1. Upload `build/lineage_udf_bundle.js` to the GCS object referenced by the UDF.
2. Run `bigquery/create_persistent_lineage_udf.sql` again.
3. Run `bigquery/test_persistent_lineage_udf_v1_2.sql`.
4. Re-run `bigquery/run_single_view_analysis.sql` using a new `analysis_id`.
5. Validate and publish the new staging result.

Existing staging rows created by an older bundle are not re-parsed automatically.

## Node.js tests

```bash
node test/test_v1_1.js
node test/test_v1_2.js
```

## v1.2.2 correction

- Fixed CTE visibility across nested query scopes in `SourceResolver`.
- A later CTE can now resolve a previously defined sibling CTE, such as `customer_summary ... FROM base`.
- Prevents visible CTE names from being misclassified as physical tables and removes resulting `PHYSICAL_METADATA_NOT_FOUND` warnings.

## v1.2.1 correction

- FromParser now accepts `BACKTICK_IDENTIFIER` as a valid name token.
- Fully qualified BigQuery table names such as `` `project.dataset.table` `` are parsed as normal table sources.
- Regression tests cover both backtick-qualified tables and the v1.2 nested-query cases.
