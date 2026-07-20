# Changelog v1.0.2

## Fixed

- Added `SET @@location = 'asia-northeast1';` to SQL files 01 through 05.
- Renamed the synchronization timestamp variable from `current_time` to `sync_timestamp`.
- Ensured TIMESTAMP columns (`first_seen_at`, `last_seen_at`, `updated_at`) are populated from `CURRENT_TIMESTAMP()` via `sync_timestamp`.

## Retained fixes from v1.0.1

- Removed `NOT NULL` from the ARRAY field `dependency_path`.
- Reduced `CLUSTER BY` on `lineage_impact` from five fields to four fields.
