-- BDE Lexer / Token table version
-- Depth rule: SUM(amount) -> SUM=0, (=0, amount=1, )=0

CREATE TABLE IF NOT EXISTS `your_project.your_dataset.bde_token`
(
  parse_id STRING NOT NULL,
  object_catalog STRING,
  object_schema STRING,
  object_name STRING,
  object_type STRING,
  sql_hash STRING,
  token_seq INT64 NOT NULL,
  line_no INT64,
  column_no INT64,
  token STRING,
  normalized_token STRING,
  token_type STRING,
  paren_depth INT64,
  created_at TIMESTAMP NOT NULL
)
PARTITION BY DATE(created_at)
CLUSTER BY object_catalog, object_schema, object_name, parse_id;

CREATE OR REPLACE FUNCTION `your_project.your_dataset.tokenize_sql`(sql_text STRING)
RETURNS ARRAY<STRUCT<
  token_seq INT64,
  line_no INT64,
  column_no INT64,
  token STRING,
  normalized_token STRING,
  token_type STRING,
  paren_depth INT64
>>
LANGUAGE js
AS r"""
function tokenize(sqlText) {
  const tokens = [];
  let tokenSeq = 0;
  let line = 1;
  let column = 1;
  let parenDepth = 0;
  let index = 0;

  const KEYWORDS = new Set([
    "SELECT", "FROM", "WHERE", "GROUP", "BY", "HAVING", "QUALIFY",
    "ORDER", "LIMIT", "JOIN", "LEFT", "RIGHT", "FULL", "INNER",
    "OUTER", "CROSS", "ON", "USING", "WITH", "RECURSIVE", "AS",
    "UNION", "ALL", "DISTINCT", "AND", "OR", "NOT", "IN", "IS",
    "NULL", "TRUE", "FALSE", "CASE", "WHEN", "THEN", "ELSE", "END",
    "OVER", "PARTITION", "UNNEST", "STRUCT", "ARRAY", "EXCEPT",
    "REPLACE", "INTERSECT", "OFFSET", "ORDINAL", "ASC", "DESC",
    "ROWS", "RANGE", "GROUPS", "NULLS", "FIRST", "LAST", "BETWEEN",
    "PRECEDING", "FOLLOWING", "CURRENT", "ROW"
  ]);

  const SYMBOLS = new Set(["(", ")", ",", ".", ";", "[", "]"]);
  const SINGLE_OPERATORS = new Set(["=", "+", "-", "*", "/", "%", "<", ">", "!"]);
  const DOUBLE_OPERATORS = new Set([">=", "<=", "!=", "<>", "||"]);

  function pushToken(token, normalizedToken, tokenType, tokenLine, tokenColumn) {
    tokens.push({
      token_seq: ++tokenSeq,
      line_no: tokenLine,
      column_no: tokenColumn,
      token: token,
      normalized_token: normalizedToken,
      token_type: tokenType,
      paren_depth: parenDepth
    });
  }

  function isSpace(character) {
    return /\s/.test(character);
  }

  function isIdentifierStart(character) {
    return /[A-Za-z_]/.test(character);
  }

  function isIdentifierPart(character) {
    return /[A-Za-z0-9_$]/.test(character);
  }

  function isDigit(character) {
    return /[0-9]/.test(character);
  }

  function advanceCharacter(character) {
    if (character === "\n") {
      line++;
      column = 1;
    } else {
      column++;
    }
    index++;
  }

  while (index < sqlText.length) {
    const character = sqlText[index];

    if (isSpace(character)) {
      advanceCharacter(character);
      continue;
    }

    const startLine = line;
    const startColumn = column;

    if (character === "-" && sqlText[index + 1] === "-") {
      let value = "";
      while (index < sqlText.length && sqlText[index] !== "\n") {
        const current = sqlText[index];
        value += current;
        advanceCharacter(current);
      }
      pushToken(value, value, "COMMENT", startLine, startColumn);
      continue;
    }

    if (character === "/" && sqlText[index + 1] === "*") {
      let value = "";
      while (index < sqlText.length) {
        const current = sqlText[index];
        value += current;

        if (current === "*" && sqlText[index + 1] === "/") {
          advanceCharacter(current);
          const closingSlash = sqlText[index];
          value += closingSlash;
          advanceCharacter(closingSlash);
          break;
        }

        advanceCharacter(current);
      }
      pushToken(value, value, "COMMENT", startLine, startColumn);
      continue;
    }

    if (character === "`") {
      let value = character;
      advanceCharacter(character);

      while (index < sqlText.length) {
        const current = sqlText[index];
        value += current;
        advanceCharacter(current);
        if (current === "`") break;
      }

      const normalizedValue =
        value.length >= 2
          ? value.substring(1, value.length - 1)
          : value;

      pushToken(value, normalizedValue, "BACKTICK_IDENTIFIER", startLine, startColumn);
      continue;
    }

    if (character === "'" || character === '"') {
      const quoteCharacter = character;
      let value = character;
      advanceCharacter(character);

      while (index < sqlText.length) {
        const current = sqlText[index];
        value += current;
        advanceCharacter(current);

        if (current === quoteCharacter && sqlText[index] === quoteCharacter) {
          const escapedQuote = sqlText[index];
          value += escapedQuote;
          advanceCharacter(escapedQuote);
          continue;
        }

        if (current === quoteCharacter) break;
      }

      const normalizedValue =
        value.length >= 2
          ? value.substring(1, value.length - 1)
          : value;

      pushToken(value, normalizedValue, "STRING", startLine, startColumn);
      continue;
    }

    if (isIdentifierStart(character)) {
      let value = "";

      while (index < sqlText.length && isIdentifierPart(sqlText[index])) {
        const current = sqlText[index];
        value += current;
        advanceCharacter(current);
      }

      const normalizedValue = value.toUpperCase();
      const tokenType = KEYWORDS.has(normalizedValue) ? "KEYWORD" : "IDENTIFIER";

      pushToken(value, normalizedValue, tokenType, startLine, startColumn);
      continue;
    }

    if (isDigit(character)) {
      let value = "";

      while (index < sqlText.length && /[0-9.]/.test(sqlText[index])) {
        const current = sqlText[index];
        value += current;
        advanceCharacter(current);
      }

      pushToken(value, value, "NUMBER", startLine, startColumn);
      continue;
    }

    const twoCharacters = sqlText.substring(index, index + 2);

    if (DOUBLE_OPERATORS.has(twoCharacters)) {
      pushToken(twoCharacters, twoCharacters, "OPERATOR", startLine, startColumn);
      advanceCharacter(sqlText[index]);
      advanceCharacter(sqlText[index]);
      continue;
    }

    if (SYMBOLS.has(character)) {
      // Closing delimiters return to the outer depth before being stored.
      if (character === ")" || character === "]") {
        parenDepth--;
        if (parenDepth < 0) parenDepth = 0;
      }

      pushToken(character, character, "SYMBOL", startLine, startColumn);

      // Opening delimiters are stored at the outer depth; following contents are deeper.
      if (character === "(" || character === "[") {
        parenDepth++;
      }

      advanceCharacter(character);
      continue;
    }

    if (SINGLE_OPERATORS.has(character)) {
      pushToken(character, character, "OPERATOR", startLine, startColumn);
      advanceCharacter(character);
      continue;
    }

    pushToken(character, character, "UNKNOWN", startLine, startColumn);
    advanceCharacter(character);
  }

  return tokens;
}

if (sql_text === null) return [];
return tokenize(sql_text);
""";

-- Lexer-only test
SELECT
  token_seq,
  token,
  normalized_token,
  token_type,
  paren_depth,
  line_no,
  column_no
FROM UNNEST(
  `your_project.your_dataset.tokenize_sql`(
    """
SELECT
  customer_id,
  SUM(IF(amount > 0, amount, 0)) AS total_amount
FROM `project.dataset.sales`
WHERE status = 'COMPLETE';
    """
  )
)
ORDER BY token_seq;

-- Save one test SQL
DECLARE current_parse_id STRING DEFAULT GENERATE_UUID();
DECLARE test_sql STRING DEFAULT """
SELECT
  customer_id,
  SUM(IF(amount > 0, amount, 0)) AS total_amount
FROM `project.dataset.sales`
WHERE status = 'COMPLETE';
""";

INSERT INTO `your_project.your_dataset.bde_token`
(
  parse_id,
  object_catalog,
  object_schema,
  object_name,
  object_type,
  sql_hash,
  token_seq,
  line_no,
  column_no,
  token,
  normalized_token,
  token_type,
  paren_depth,
  created_at
)
SELECT
  current_parse_id,
  'project',
  'dataset',
  '__TEST__',
  'TEST_SQL',
  TO_HEX(SHA256(test_sql)),
  token.token_seq,
  token.line_no,
  token.column_no,
  token.token,
  token.normalized_token,
  token.token_type,
  token.paren_depth,
  CURRENT_TIMESTAMP()
FROM UNNEST(
  `your_project.your_dataset.tokenize_sql`(test_sql)
) AS token;

SELECT *
FROM `your_project.your_dataset.bde_token`
WHERE parse_id = current_parse_id
ORDER BY token_seq;

-- Save all View definitions
DECLARE view_parse_id STRING DEFAULT GENERATE_UUID();

INSERT INTO `your_project.your_dataset.bde_token`
(
  parse_id,
  object_catalog,
  object_schema,
  object_name,
  object_type,
  sql_hash,
  token_seq,
  line_no,
  column_no,
  token,
  normalized_token,
  token_type,
  paren_depth,
  created_at
)
SELECT
  view_parse_id,
  views.table_catalog,
  views.table_schema,
  views.table_name,
  'VIEW',
  TO_HEX(SHA256(views.view_definition)),
  token.token_seq,
  token.line_no,
  token.column_no,
  token.token,
  token.normalized_token,
  token.token_type,
  token.paren_depth,
  CURRENT_TIMESTAMP()
FROM `your_project.your_dataset.INFORMATION_SCHEMA.VIEWS` AS views
CROSS JOIN UNNEST(
  `your_project.your_dataset.tokenize_sql`(views.view_definition)
) AS token;
