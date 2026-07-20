# v1.5.0-013

## Issue-0100-3 Production SQL

- Added four production-oriented Golden Cases:
  - `production_etl_daily`
  - `production_reporting_view`
  - `production_data_mart`
  - `production_incremental_load`
- Certified ETL, reporting-view, data-mart and incremental-load SQL patterns.
- Added 24 verified output columns, increasing the suite to 46 Golden Cases and 121 Verified Outputs.
- No LineageEngine source change was required.
- Recorded the existing internal scalar-subquery warning behavior for the incremental-load case while all published outputs remain physically resolved.
