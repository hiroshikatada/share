# v1.4.0-005

## PIVOT generated-column lineage

- PIVOT `IN` aliases are added as explicit generated output columns.
- Each generated column retains the aggregate input column and input query scope.
- LineageResolver follows generated columns through the aggregate input column to physical columns.
- Prevents false self-cycle detection for columns such as `PC_SALES`, `AV_SALES`, `HOME_SALES`, and `WEARABLE_SALES`.
- Adds a regression test confirming `PIVOT(SUM(sales_amount))` resolves to the physical `SALES_AMOUNT` column.
