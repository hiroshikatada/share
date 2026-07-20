# v1.5.0-007

## Issue-0004-1 Wildcard Expansion (`SELECT *`)

### Added

- Promoted `wildcard_expansions` into independent output-column lineage records.
- Added physical-table, CTE, and subquery golden cases for unqualified `SELECT *`.
- Added `test/test_v1_5_0_007.js`.

### Changed

- Expanded wildcard columns now appear in `output_lineages` and `root_output_lineages` with `expanded_from_wildcard: true`.
- Physical wildcard expansion preserves physical column name and field path.
- Existing wildcard exclusions remain excluded when expanded output lineages are generated.

### Verification

- Golden cases: 22
- Verified outputs: 44
- All Node.js regression tests passed.
