# v1.5.0-008

## Issue-0004-2 Wildcard Expansion (`alias.*`)

### Added

- Added physical-table, JOIN, CTE, and subquery golden cases for qualified wildcard expansion.
- Added optional `expression_text` verification to the shared golden runner.
- Added `test/test_v1_5_0_008.js`.

### Changed

- Qualified wildcard expansion is restricted to the source resolved by its alias.
- Expanded output lineage preserves the originating wildcard expression, such as `C.*`, instead of reducing it to `*`.
- Physical dependency audit records preserve the qualified wildcard source expression.

### Verification

- Golden cases: 26
- Verified outputs: 55
- All Node.js regression tests passed.
