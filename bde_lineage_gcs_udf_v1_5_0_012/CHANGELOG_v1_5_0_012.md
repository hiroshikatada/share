# v1.5.0-012

## Issue-0100-2 Deep Nested SQL

- Added four deep-nesting Golden Cases covering five-stage CTE chains, three-stage derived tables, nested correlated `EXISTS`, and nested `UNION ALL` propagation.
- Fixed nested correlated-subquery dependency propagation so physical columns from inner correlated scopes are included in the outer output lineage.
- Preserved current diagnostic behavior for `EXISTS(SELECT 1)` internal scopes.
