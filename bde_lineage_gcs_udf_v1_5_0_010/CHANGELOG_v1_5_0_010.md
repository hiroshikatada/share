# v1.5.0-010

## Implemented

- Issue-0004-4 Wildcard Expansion (`* REPLACE`).
- Single and multiple replacement expressions.
- Qualified wildcard replacement such as `alias.* REPLACE(...)`.
- Replacement lineage propagation through physical tables and derived CTE sources.
- Full wildcard audit expression retention in expanded output lineages.

## Tests

- Added four golden cases:
  - `wildcard_replace_physical`
  - `wildcard_replace_multiple`
  - `wildcard_replace_alias`
  - `wildcard_replace_cte`
- Golden cases: 34
- Verified outputs: 75
