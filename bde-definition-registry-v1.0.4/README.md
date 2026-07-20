# BDE Definition Registry v1.0.3

BigQuery Lineage Engine の運用レイヤー初版です。

## 実行順

1. `01_create_repository_tables.sql`
2. `02_sync_view_registry.sql`
3. `03_sync_scheduled_ctas_registry.sql`
4. 既存の `parse_dependencies_with_field_paths` UDF を使って変更定義を解析
5. `04_rebuild_impact_table.sql`
6. `05_validation_queries.sql`

## 方針

- VIEW definition は `INFORMATION_SCHEMA.VIEWS` から取得します。
- SQL本文の `SHA256` を保持し、変更された定義だけを再解析します。
- Scheduled QueryによるCTASは `INFORMATION_SCHEMA.JOBS_BY_PROJECT` から取得します。
- JOBSは `user_email = 'audeodb@appspot.gserviceaccount.com'` で絞ります。
- 直接依存と間接依存は `lineage_impact` 1テーブルに保持します。
- 初版では解析処理だけ差分化し、Rank展開は全件再構築します。

## 置換箇所

SQL中の以下を実環境に合わせて置換してください。

- `audeodb.lineage_repository`
- `region-asia-northeast1`

`sample_ds` は検証対象データセットとして記載しています。


## v1.0.3 corrections

- Removed `NOT NULL` from `dependency_path ARRAY<STRING>` because BigQuery does not allow `NOT NULL` on ARRAY fields.
- Reduced `lineage_impact` clustering fields from five to four, matching BigQuery's clustering limit.

## v1.0.3 changes

- Added `SET @@location = 'asia-northeast1';` to the beginning of SQL files 01–05.
- Renamed the timestamp variable in synchronization scripts from `current_time` to `sync_timestamp` to avoid confusion with `CURRENT_TIME()`.
- All assignments to `first_seen_at`, `last_seen_at`, and `updated_at` now use a value initialized by `CURRENT_TIMESTAMP()`.

## 6. Analyze changed objects

After running 01 through 03 and creating the persistent UDF, execute:

```text
06_analyze_changed_objects.sql
04_rebuild_impact_table.sql
05_validation_queries.sql
```

`06_analyze_changed_objects.sql` analyzes only active Registry rows where
`is_changed = TRUE`, refreshes direct dependencies, records diagnostics, and
updates the Registry analysis state.
