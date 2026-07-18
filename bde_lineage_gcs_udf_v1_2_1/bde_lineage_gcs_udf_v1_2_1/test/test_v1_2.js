const path = require("path");
const bundle = require(path.join(__dirname, "../build/lineage_udf_bundle.js"));

const physicalColumns = [
  { table_name: "PROJECT.DATASET.CUSTOMERS", column_name: "CUSTOMER_ID", field_path: "CUSTOMER_ID" },
  { table_name: "PROJECT.DATASET.SALES", column_name: "CUSTOMER_ID", field_path: "CUSTOMER_ID" },
  { table_name: "PROJECT.DATASET.CUSTOMERS", column_name: "ITEMS", field_path: "ITEMS" },
  { table_name: "PROJECT.DATASET.ORDERS", column_name: "CUSTOMER_ID", field_path: "CUSTOMER_ID" },
  { table_name: "PROJECT.DATASET.ORDERS", column_name: "ORDER_DATE", field_path: "ORDER_DATE" }
];

const metadata = {
  analysis_id: "v1_2_test",
  view_project: "PROJECT",
  view_dataset: "DATASET",
  view_name: "TEST_VIEW",
  analyzed_at: "2026-07-17T00:00:00Z"
};

const cases = [
  {
    name: "backtick qualified table name",
    minimumScopes: 1,
    sql: `
SELECT
  s.customer_id,
FROM ` + "`project.dataset.sales`" + ` AS s
`
  },
  {
    name: "array subquery inside case and array_to_string",
    sql: `
SELECT
  CASE
    WHEN c.customer_id IS NOT NULL THEN ARRAY_TO_STRING(
      ARRAY(
        SELECT item
        FROM UNNEST(c.items) AS item
      ),
      ','
    )
    ELSE ''
  END AS item_list,
FROM project.dataset.customers AS c
`
  },
  {
    name: "correlated scalar subquery",
    sql: `
SELECT
  c.customer_id,
  (
    SELECT MAX(o.order_date)
    FROM project.dataset.orders AS o
    WHERE o.customer_id = c.customer_id
  ) AS last_order_date,
FROM project.dataset.customers AS c
`
  }
];

for (const testCase of cases) {
  const result = JSON.parse(bundle.analyzeLineageForBigQuery(
    testCase.sql,
    JSON.stringify(physicalColumns),
    JSON.stringify({ strict_mode: false }),
    JSON.stringify({ ...metadata, analysis_id: `v1_2_${testCase.name.replace(/\W+/g, "_")}` })
  ));

  if (!result.analysis) throw new Error(`${testCase.name}: analysis missing`);
  if (result.analysis.analysis_status === "PARTIAL_FAILURE") {
    throw new Error(`${testCase.name}: ${result.analysis.failed_stage || "unknown stage"}`);
  }

  const scopes = result.exported_tables.query_scopes || [];
  const minimumScopes = testCase.minimumScopes || 2;
  if (scopes.length < minimumScopes) {
    throw new Error(`${testCase.name}: expected at least ${minimumScopes} query scope(s)`);
  }

  console.log(JSON.stringify({
    name: testCase.name,
    status: result.analysis.analysis_status,
    scopes: scopes.length,
    sources: result.exported_tables.sources.length,
    columnReferences: result.exported_tables.column_references.length,
    diagnostics: result.exported_tables.diagnostics.length
  }, null, 2));
}
