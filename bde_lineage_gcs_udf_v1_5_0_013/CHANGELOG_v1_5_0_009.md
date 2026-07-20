# v1.5.0-009

## Issue-0004-3 Wildcard Expansion (`* EXCEPT`)

### Added
- Golden cases for physical tables, qualified JOIN sources, CTEs, and subqueries.
- Verification for single and multiple excluded columns.
- Verification that expanded output lineage preserves the original `* EXCEPT(...)` expression.

### Changed
- Wildcard expansion now records `EXCEPT` column names in `wildcard_expression`.
- Qualified wildcard expressions retain both the source alias and exclusion list.

### Regression
- 30 golden cases.
- 64 verified outputs.
- All existing Node.js tests pass.
