# v1.5.0-006

## Issue-0003: Correlated Subquery propagation

### Labels

- Resolver
- Lineage
- Regression

### Definition of Done

- [x] Add small correlated-subquery golden cases.
- [x] Confirm the current implementation fails before the fix.
- [x] Resolve outer-scope column references from the child query.
- [x] Propagate correlated predicate dependencies to the parent SELECT output.
- [x] Confirm all new golden cases pass.
- [x] Confirm all existing Node.js regression tests pass.
- [x] Update README, VERSION, and changelog.
- [ ] Close Issue-0003 after user-environment verification.

### Failure reproduced

The scalar child query's SELECT expression was propagated to the parent output, but references in the correlated predicate were omitted. For example, `MAX(o.order_total)` contributed `ORDERS.ORDER_TOTAL`, while `o.customer_id = c.customer_id` contributed neither side.

### Implementation

`LineageResolver` now indexes column references by scope. For each scalar expression subquery, it checks whether a non-SELECT reference resolves to a source in an ancestor scope. When such an outer reference exists, all column references in the child query's predicate clauses are resolved and merged into the parent output dependencies. This retains both the inner correlation key and the outer correlation key.

Normal non-correlated scalar subqueries are unchanged: predicate dependencies are added only when an ancestor-scope reference is present.

### Golden cases added

- `correlated_subquery_basic`
- `correlated_subquery_expression`
- `correlated_subquery_cte`
- `correlated_subquery_exists`

### Local verification

- Golden cases: 19
- Golden outputs: 37
- All `test/test_*.js`: PASS
