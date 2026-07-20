# v1.4.0-004

## Changed

- BigQuery date-part keywords such as `DAY`, `MONTH`, and `YEAR` are no longer collected as column references.
- `DATE_DIFF(..., DAY)` lineage no longer produces a false unresolved-column dependency.
- Added regression coverage using `v_ec_complex_union.sql`.

## Expected result

The complex regression SQL warning count decreases from 7 to 4. The remaining warnings are the four PIVOT-generated columns and will be handled separately.
