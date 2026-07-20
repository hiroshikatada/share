# v1.5.0-001

## Lineage correctness golden tests

- Added the production-scale `v_ec_complex_union` VIEW SQL as a permanent fixture.
- Added a declarative JSON expectation manifest for physical-column lineage.
- Added semantic assertions for 12 final output columns.
- Added semantic assertions for the four PIVOT-generated columns.
- Recorded two known semantic gaps separately:
  - `CATEGORIES_BOUGHT` should reach `PRODUCT_MASTER.CATEGORY`.
  - `RECENT_CHAIN` should reach purchase `ORDER_ID` and `PURCHASE_DATE`.

This release starts the v1.5 correctness-validation phase. It does not change the parser or resolver implementation.
