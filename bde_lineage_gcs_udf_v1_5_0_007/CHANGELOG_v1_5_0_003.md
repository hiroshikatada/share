# v1.5.0-003

## Golden lineage suite

Added small, syntax-focused golden regression cases in addition to the existing comprehensive VIEW regression.

### New shared runner

- `test/lib/golden_lineage_runner.js`
- Loads one SQL fixture and one expected JSON file per case.
- Verifies analysis status, diagnostics counts, lineage status, exact physical dependencies, and explicitly absent outputs.

### New golden cases

- `basic_expression`
- `case_expression`
- `cte_chain`
- `join_aggregate`
- `qualify_window`
- `array_unnest`
- `struct_output`
- `pivot`
- `wildcard_except`

The suite currently verifies 18 output columns across 9 independent cases.

### Newly identified follow-up gaps

The isolated cases exposed behaviors that should not yet be frozen as correct expectations:

- UNION / UNION ALL output lineage currently keeps only the first branch dependency.
- Scalar and correlated subquery output lineage is not propagated to the parent output.
- UNPIVOT generated columns are not emitted as named output lineage rows.
- SELECT * physical column expansion is not yet emitted as individual root output columns in the small standalone case.

These are documented as the next resolver improvements rather than accepted as golden behavior.
