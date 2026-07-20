# v1.5.0-002

## Added

- Expression-subquery lineage propagation for `ARRAY(SELECT ... FROM UNNEST(...))`.
- Golden lineage assertions for `CATEGORIES_BOUGHT` and `RECENT_CHAIN`.
- Regression test `test/test_v1_5_0_002.js`.

## Changed

- `LineageResolver` now resolves the UNNEST collection column in the parent scope and recursively propagates its physical dependencies.
- Outputs with no direct SELECT-level column reference can be `RESOLVED` when expression-subquery dependencies exist.
- Golden known gaps are now empty.

## Verified lineage

- `CATEGORIES_BOUGHT` -> `PRODUCT_MASTER.CATEGORY`
- `RECENT_CHAIN` -> `CUSTOMER_PURCHASE_HISTORY.ORDER_ID`, `CUSTOMER_PURCHASE_HISTORY.PURCHASE_DATE`
