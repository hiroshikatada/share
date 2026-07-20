# v1.5.0-004

## Issue #1: UNION / UNION ALL all-branch lineage merge

### Process

1. Added a small golden case for UNION ALL.
2. Confirmed the existing implementation failed because only the first branch dependency was returned.
3. Updated `LineageResolver` to merge dependencies from the same output-column position in every set-operation branch.
4. Added UNION DISTINCT and three-branch-with-CTE regression cases.
5. Confirmed the complete Node.js regression suite passes.

### Design

The public output column continues to use the name and position of the first SELECT branch.
Its `dependencies` array now contains the deduplicated physical dependencies collected from all branches.

### Golden cases added

- `union_all_branches`
- `union_distinct_branches`
- `union_three_branches_cte`

### Verified locally

- Golden cases: 12
- Golden outputs: 24
- All existing `test/test_*.js`: PASS
