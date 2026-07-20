# Changelog v1.0.4

- Added `06_analyze_changed_objects.sql`.
- Supplies the required `analysis_id`, object metadata, and `analyzed_at` values to `analyze_lineage_json`.
- Loads physical-column metadata from `audeodb.sample_ds.INFORMATION_SCHEMA.COLUMNS`.
- Converts `exported_tables.lineage_paths` into `lineage_direct_dependency` rows.
- Publishes engine diagnostics to `lineage_diagnostic`.
- Marks successful registry definitions as analyzed and keeps failed definitions changed for retry.
