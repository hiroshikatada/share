# v1.5.0-005

## Issue #2: Scalar Subquery lineage propagation

### Definition of Done

- [x] Add small scalar-subquery golden cases.
- [x] Confirm the current implementation fails before the fix.
- [x] Propagate the scalar child query's first output lineage to the parent SELECT item.
- [x] Confirm all new golden cases pass.
- [x] Confirm all existing Node.js regression tests pass.
- [x] Update README, VERSION, and changelog.

### Failure reproduced

The child `EXPRESSION_SUBQUERY` scope resolved its physical columns correctly, but the parent output column returned `NO_COLUMN_DEPENDENCY`.

### Implementation

For `SUBQUERY_EXPRESSION`, `LineageResolver` now locates the child query scope, resolves output-column position 1, and merges its dependencies into the parent expression. Existing direct references in expressions such as `credit_limit + (SELECT AVG(...))` remain included and are deduplicated with the scalar-subquery dependencies.

### Golden cases added

- `scalar_subquery_basic`
- `scalar_subquery_expression`
- `scalar_subquery_cte`

### Verified locally

- Golden cases: 15
- Golden outputs: 29
- All `test/test_*.js`: PASS
