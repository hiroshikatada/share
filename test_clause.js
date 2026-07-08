const tokenize = require("./lexer");
const { parseClauses } = require("./parser_clause");

const sql = `
SELECT
    c.customer_id,
    SUM(s.amount) AS total_amount
FROM customer c
JOIN sales s
  ON c.customer_id = s.customer_id
WHERE s.status = 'ACTIVE'
GROUP BY c.customer_id
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY c.customer_id
    ORDER BY s.sales_date DESC
) = 1
`;

const tokens = tokenize(sql);
const clauses = parseClauses(tokens);

console.table(clauses);