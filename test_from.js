const tokenize = require("./lexer");
const { parseClauses } = require("./parser_clause");
const { parseFrom } = require("./parser_from");

const sql = `
SELECT
    c.customer_id,
    SUM(s.amount) AS total_amount,
    item.product_id
FROM \`project.dataset.customer\` c
LEFT JOIN project.dataset.sales AS s
  ON c.customer_id = s.customer_id
LEFT JOIN UNNEST(s.items) item
  ON item.product_id IS NOT NULL
`;

const tokens = tokenize(sql);
const clauses = parseClauses(tokens);
const fromClause = clauses.find((c) => c.clause === "FROM");

console.table(parseFrom(tokens, fromClause));