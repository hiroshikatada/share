const tokenize = require("./lexer");
const { parseClauses } = require("./parser_clause");
const { parseSelect } = require("./parser_select");

const sql = `
SELECT
    c.customer_id,
    c.customer_name AS name,
    SUM(s.amount) AS total_amount,
    COUNT(*) cnt
FROM customer c
JOIN sales s
  ON c.customer_id = s.customer_id
`;

const tokens = tokenize(sql);
const clauses = parseClauses(tokens);

const selectClause = clauses.find((c) => c.clause === "SELECT");
const selectItems = parseSelect(tokens, selectClause);

console.table(selectItems);