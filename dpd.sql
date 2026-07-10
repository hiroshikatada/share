CREATE TEMP FUNCTION parse_select_and_from(sql_text STRING)
RETURNS ARRAY<
  STRUCT<
    record_seq INT64,
    record_type STRING,

    expression STRING,
    output_alias STRING,
    alias_type STRING,

    source_type STRING,
    source_name STRING,
    source_alias STRING,
    join_type STRING,

    start_token_seq INT64,
    end_token_seq INT64
  >
>
LANGUAGE js
AS r"""
/* ============================================================
 * Lexer
 * ============================================================ */

function tokenize(sqlText) {
  const tokens = [];

  let tokenSeq = 0;
  let line = 1;
  let column = 1;
  let parenDepth = 0;
  let index = 0;

  const KEYWORDS = new Set([
    "SELECT", "FROM", "WHERE", "GROUP", "BY", "HAVING",
    "QUALIFY", "ORDER", "LIMIT", "JOIN", "LEFT", "RIGHT",
    "FULL", "INNER", "OUTER", "CROSS", "ON", "WITH",
    "RECURSIVE", "AS", "UNION", "ALL", "DISTINCT", "AND",
    "OR", "NOT", "IN", "IS", "NULL", "TRUE", "FALSE",
    "CASE", "WHEN", "THEN", "ELSE", "END", "OVER",
    "PARTITION", "UNNEST", "STRUCT", "ARRAY", "EXCEPT",
    "REPLACE", "INTERSECT", "OFFSET", "ORDINAL", "ASC",
    "DESC"
  ]);

  const SYMBOLS = new Set([
    "(", ")", ",", ".", ";", "[", "]"
  ]);

  const SINGLE_OPERATORS = new Set([
    "=", "+", "-", "*", "/", "%", "<", ">", "!"
  ]);

  const DOUBLE_OPERATORS = new Set([
    ">=", "<=", "!=", "<>", "||"
  ]);

  function pushToken(
    token,
    normalizedToken,
    tokenType,
    tokenLine,
    tokenColumn
  ) {
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

    /* 1行コメント */
    if (
      character === "-" &&
      sqlText[index + 1] === "-"
    ) {
      let value = "";

      while (
        index < sqlText.length &&
        sqlText[index] !== "\n"
      ) {
        const currentCharacter = sqlText[index];

        value += currentCharacter;
        advanceCharacter(currentCharacter);
      }

      pushToken(
        value,
        value,
        "COMMENT",
        startLine,
        startColumn
      );

      continue;
    }

    /* ブロックコメント */
    if (
      character === "/" &&
      sqlText[index + 1] === "*"
    ) {
      let value = "";

      while (index < sqlText.length) {
        const currentCharacter = sqlText[index];

        value += currentCharacter;

        if (
          currentCharacter === "*" &&
          sqlText[index + 1] === "/"
        ) {
          advanceCharacter(currentCharacter);

          const closingSlash = sqlText[index];
          value += closingSlash;
          advanceCharacter(closingSlash);

          break;
        }

        advanceCharacter(currentCharacter);
      }

      pushToken(
        value,
        value,
        "COMMENT",
        startLine,
        startColumn
      );

      continue;
    }

    /* バッククォート識別子 */
    if (character === "`") {
      let value = character;

      advanceCharacter(character);

      while (index < sqlText.length) {
        const currentCharacter = sqlText[index];

        value += currentCharacter;
        advanceCharacter(currentCharacter);

        if (currentCharacter === "`") {
          break;
        }
      }

      const normalizedValue =
        value.length >= 2
          ? value.substring(1, value.length - 1)
          : value;

      pushToken(
        value,
        normalizedValue,
        "BACKTICK_IDENTIFIER",
        startLine,
        startColumn
      );

      continue;
    }

    /* 文字列リテラル */
    if (
      character === "'" ||
      character === '"'
    ) {
      const quoteCharacter = character;
      let value = character;

      advanceCharacter(character);

      while (index < sqlText.length) {
        const currentCharacter = sqlText[index];

        value += currentCharacter;
        advanceCharacter(currentCharacter);

        /*
         * '' または "" によるエスケープ
         */
        if (
          currentCharacter === quoteCharacter &&
          sqlText[index] === quoteCharacter
        ) {
          const escapedQuote = sqlText[index];

          value += escapedQuote;
          advanceCharacter(escapedQuote);

          continue;
        }

        if (currentCharacter === quoteCharacter) {
          break;
        }
      }

      const normalizedValue =
        value.length >= 2
          ? value.substring(1, value.length - 1)
          : value;

      pushToken(
        value,
        normalizedValue,
        "STRING",
        startLine,
        startColumn
      );

      continue;
    }

    /* 識別子・予約語 */
    if (isIdentifierStart(character)) {
      let value = "";

      while (
        index < sqlText.length &&
        isIdentifierPart(sqlText[index])
      ) {
        const currentCharacter = sqlText[index];

        value += currentCharacter;
        advanceCharacter(currentCharacter);
      }

      const normalizedValue = value.toUpperCase();

      const tokenType =
        KEYWORDS.has(normalizedValue)
          ? "KEYWORD"
          : "IDENTIFIER";

      pushToken(
        value,
        normalizedValue,
        tokenType,
        startLine,
        startColumn
      );

      continue;
    }

    /* 数値 */
    if (isDigit(character)) {
      let value = "";

      while (
        index < sqlText.length &&
        /[0-9.]/.test(sqlText[index])
      ) {
        const currentCharacter = sqlText[index];

        value += currentCharacter;
        advanceCharacter(currentCharacter);
      }

      pushToken(
        value,
        value,
        "NUMBER",
        startLine,
        startColumn
      );

      continue;
    }

    /* 2文字演算子 */
    const twoCharacters =
      sqlText.substring(index, index + 2);

    if (DOUBLE_OPERATORS.has(twoCharacters)) {
      pushToken(
        twoCharacters,
        twoCharacters,
        "OPERATOR",
        startLine,
        startColumn
      );

      advanceCharacter(sqlText[index]);
      advanceCharacter(sqlText[index]);

      continue;
    }

    /* 記号 */
    if (SYMBOLS.has(character)) {
      pushToken(
        character,
        character,
        "SYMBOL",
        startLine,
        startColumn
      );

      if (
        character === "(" ||
        character === "["
      ) {
        parenDepth++;
      } else if (
        character === ")" ||
        character === "]"
      ) {
        parenDepth--;
      }

      advanceCharacter(character);
      continue;
    }

    /* 1文字演算子 */
    if (SINGLE_OPERATORS.has(character)) {
      pushToken(
        character,
        character,
        "OPERATOR",
        startLine,
        startColumn
      );

      advanceCharacter(character);
      continue;
    }

    pushToken(
      character,
      character,
      "UNKNOWN",
      startLine,
      startColumn
    );

    advanceCharacter(character);
  }

  return tokens;
}


/* ============================================================
 * 共通関数
 * ============================================================ */

function normalizedTokenAt(tokens, index) {
  const token = tokens[index];

  if (!token) {
    return "";
  }

  return token.normalized_token || "";
}


function sliceTokensBySequence(
  tokens,
  startSequence,
  endSequence
) {
  return tokens.filter(
    (token) =>
      token.token_seq >= startSequence &&
      token.token_seq <= endSequence
  );
}


function trimCommentTokens(tokens) {
  let startIndex = 0;
  let endIndex = tokens.length - 1;

  while (
    startIndex <= endIndex &&
    tokens[startIndex].token_type === "COMMENT"
  ) {
    startIndex++;
  }

  while (
    endIndex >= startIndex &&
    tokens[endIndex].token_type === "COMMENT"
  ) {
    endIndex--;
  }

  return tokens.slice(startIndex, endIndex + 1);
}


function tokensToText(tokens) {
  let result = "";

  for (
    let tokenIndex = 0;
    tokenIndex < tokens.length;
    tokenIndex++
  ) {
    const currentToken = tokens[tokenIndex];
    const previousToken = tokens[tokenIndex - 1];

    if (!previousToken) {
      result += currentToken.token;
      continue;
    }

    const noSpaceBefore =
      currentToken.token === "." ||
      currentToken.token === "," ||
      currentToken.token === ")" ||
      currentToken.token === "]";

    const noSpaceAfterPrevious =
      previousToken.token === "." ||
      previousToken.token === "(" ||
      previousToken.token === "[";

    if (
      noSpaceBefore ||
      noSpaceAfterPrevious
    ) {
      result += currentToken.token;
    } else {
      result += " " + currentToken.token;
    }
  }

  return result;
}


function isIdentifierToken(token) {
  if (!token) {
    return false;
  }

  return (
    token.token_type === "IDENTIFIER" ||
    token.token_type === "BACKTICK_IDENTIFIER"
  );
}


/* ============================================================
 * Clause Parser
 * ============================================================ */

function detectClause(tokens, index) {
  const firstToken =
    normalizedTokenAt(tokens, index);

  const secondToken =
    normalizedTokenAt(tokens, index + 1);

  if (firstToken === "SELECT") {
    return {
      clause: "SELECT",
      token_length: 1
    };
  }

  if (firstToken === "FROM") {
    return {
      clause: "FROM",
      token_length: 1
    };
  }

  if (firstToken === "WHERE") {
    return {
      clause: "WHERE",
      token_length: 1
    };
  }

  if (firstToken === "HAVING") {
    return {
      clause: "HAVING",
      token_length: 1
    };
  }

  if (firstToken === "QUALIFY") {
    return {
      clause: "QUALIFY",
      token_length: 1
    };
  }

  if (firstToken === "LIMIT") {
    return {
      clause: "LIMIT",
      token_length: 1
    };
  }

  if (
    firstToken === "GROUP" &&
    secondToken === "BY"
  ) {
    return {
      clause: "GROUP_BY",
      token_length: 2
    };
  }

  if (
    firstToken === "ORDER" &&
    secondToken === "BY"
  ) {
    return {
      clause: "ORDER_BY",
      token_length: 2
    };
  }

  return null;
}


function parseClauses(tokens) {
  const clauses = [];

  const effectiveTokens = tokens.filter(
    (token) => token.token_type !== "COMMENT"
  );

  for (
    let tokenIndex = 0;
    tokenIndex < effectiveTokens.length;
    tokenIndex++
  ) {
    const currentToken =
      effectiveTokens[tokenIndex];

    if (currentToken.paren_depth !== 0) {
      continue;
    }

    const detectedClause =
      detectClause(effectiveTokens, tokenIndex);

    if (!detectedClause) {
      continue;
    }

    clauses.push({
      clause_seq: clauses.length + 1,
      clause: detectedClause.clause,
      clause_start_seq: currentToken.token_seq,
      body_start_seq:
        currentToken.token_seq +
        detectedClause.token_length,
      body_end_seq: null
    });
  }

  for (
    let clauseIndex = 0;
    clauseIndex < clauses.length;
    clauseIndex++
  ) {
    const currentClause =
      clauses[clauseIndex];

    const nextClause =
      clauses[clauseIndex + 1];

    if (nextClause) {
      currentClause.body_end_seq =
        nextClause.clause_start_seq - 1;
    } else if (effectiveTokens.length > 0) {
      const lastToken =
        effectiveTokens[
          effectiveTokens.length - 1
        ];

      currentClause.body_end_seq =
        lastToken.token_seq;
    }
  }

  return clauses;
}


/* ============================================================
 * SELECT Parser
 * ============================================================ */

function splitTopLevelByComma(tokens) {
  const result = [];
  let currentItemTokens = [];

  for (const currentToken of tokens) {
    const isTopLevelComma =
      currentToken.token === "," &&
      currentToken.paren_depth === 0;

    if (isTopLevelComma) {
      const completedItem =
        trimCommentTokens(currentItemTokens);

      if (completedItem.length > 0) {
        result.push(completedItem);
      }

      currentItemTokens = [];
      continue;
    }

    currentItemTokens.push(currentToken);
  }

  const lastItem =
    trimCommentTokens(currentItemTokens);

  if (lastItem.length > 0) {
    result.push(lastItem);
  }

  return result;
}


function parseSelectAlias(itemTokens) {
  if (itemTokens.length === 0) {
    return {
      expression: "",
      output_alias: null,
      alias_type: "NONE"
    };
  }

  /*
   * 明示的なAS
   */
  for (
    let tokenIndex = itemTokens.length - 2;
    tokenIndex >= 0;
    tokenIndex--
  ) {
    const currentToken =
      itemTokens[tokenIndex];

    if (
      currentToken.normalized_token === "AS" &&
      currentToken.paren_depth === 0
    ) {
      const aliasToken =
        itemTokens[tokenIndex + 1];

      const expressionTokens =
        itemTokens.slice(0, tokenIndex);

      return {
        expression:
          tokensToText(expressionTokens),
        output_alias:
          aliasToken
            ? aliasToken.normalized_token
            : null,
        alias_type: "EXPLICIT_AS"
      };
    }
  }

  /*
   * table_alias.column_name
   */
  if (itemTokens.length >= 3) {
    const dotToken =
      itemTokens[itemTokens.length - 2];

    const columnToken =
      itemTokens[itemTokens.length - 1];

    if (
      dotToken.token === "." &&
      isIdentifierToken(columnToken)
    ) {
      return {
        expression: tokensToText(itemTokens),
        output_alias:
          columnToken.normalized_token,
        alias_type: "DERIVED_COLUMN"
      };
    }
  }

  /*
   * 単独カラム
   */
  if (
    itemTokens.length === 1 &&
    isIdentifierToken(itemTokens[0])
  ) {
    return {
      expression: tokensToText(itemTokens),
      output_alias:
        itemTokens[0].normalized_token,
      alias_type: "DERIVED_COLUMN"
    };
  }

  /*
   * AS省略
   */
  const lastToken =
    itemTokens[itemTokens.length - 1];

  const previousToken =
    itemTokens[itemTokens.length - 2];

  if (
    itemTokens.length >= 2 &&
    isIdentifierToken(lastToken) &&
    previousToken &&
    previousToken.token !== "."
  ) {
    const expressionTokens =
      itemTokens.slice(
        0,
        itemTokens.length - 1
      );

    return {
      expression:
        tokensToText(expressionTokens),
      output_alias:
        lastToken.normalized_token,
      alias_type: "IMPLICIT"
    };
  }

  return {
    expression: tokensToText(itemTokens),
    output_alias: null,
    alias_type: "NONE"
  };
}


function removeSelectModifiers(selectTokens) {
  const result = selectTokens.slice();

  if (
    result.length > 0 &&
    (
      result[0].normalized_token === "DISTINCT" ||
      result[0].normalized_token === "ALL"
    )
  ) {
    result.shift();
  }

  return result;
}


function parseSelect(tokens, selectClause) {
  let selectTokens =
    sliceTokensBySequence(
      tokens,
      selectClause.body_start_seq,
      selectClause.body_end_seq
    );

  selectTokens =
    removeSelectModifiers(selectTokens);

  const selectItemTokenArrays =
    splitTopLevelByComma(selectTokens);

  const selectItems = [];

  for (
    let itemIndex = 0;
    itemIndex < selectItemTokenArrays.length;
    itemIndex++
  ) {
    const itemTokens =
      selectItemTokenArrays[itemIndex];

    const parsedAlias =
      parseSelectAlias(itemTokens);

    selectItems.push({
      expression: parsedAlias.expression,
      output_alias:
        parsedAlias.output_alias,
      alias_type:
        parsedAlias.alias_type,
      start_token_seq:
        itemTokens[0].token_seq,
      end_token_seq:
        itemTokens[
          itemTokens.length - 1
        ].token_seq
    });
  }

  return selectItems;
}


/* ============================================================
 * FROM Parser
 * ============================================================ */

const JOIN_MODIFIERS = new Set([
  "LEFT",
  "RIGHT",
  "FULL",
  "INNER",
  "OUTER",
  "CROSS"
]);


const SOURCE_STOP_WORDS = new Set([
  "ON",
  "USING",
  "JOIN",
  "LEFT",
  "RIGHT",
  "FULL",
  "INNER",
  "OUTER",
  "CROSS",
  "WHERE",
  "GROUP",
  "HAVING",
  "QUALIFY",
  "ORDER",
  "LIMIT"
]);


function findMatchingCloseParenthesis(
  tokens,
  openIndex
) {
  const openToken = tokens[openIndex];

  if (
    !openToken ||
    openToken.token !== "("
  ) {
    return -1;
  }

  const targetDepth =
    openToken.paren_depth + 1;

  for (
    let tokenIndex = openIndex + 1;
    tokenIndex < tokens.length;
    tokenIndex++
  ) {
    const currentToken =
      tokens[tokenIndex];

    if (
      currentToken.token === ")" &&
      currentToken.paren_depth === targetDepth
    ) {
      return tokenIndex;
    }
  }

  return -1;
}


function parseSourceAlias(tokens, startIndex) {
  const currentToken = tokens[startIndex];

  if (!currentToken) {
    return {
      source_alias: null,
      next_index: startIndex
    };
  }

  /*
   * AS alias
   */
  if (
    currentToken.normalized_token === "AS"
  ) {
    const aliasToken =
      tokens[startIndex + 1];

    if (isIdentifierToken(aliasToken)) {
      return {
        source_alias:
          aliasToken.normalized_token,
        next_index: startIndex + 2
      };
    }
  }

  /*
   * AS省略
   */
  if (
    isIdentifierToken(currentToken) &&
    !SOURCE_STOP_WORDS.has(
      currentToken.normalized_token
    )
  ) {
    return {
      source_alias:
        currentToken.normalized_token,
      next_index: startIndex + 1
    };
  }

  return {
    source_alias: null,
    next_index: startIndex
  };
}


function parseDottedSourceName(tokens, startIndex) {
  const firstToken = tokens[startIndex];

  if (!firstToken) {
    return null;
  }

  /*
   * `project.dataset.table`
   */
  if (
    firstToken.token_type ===
    "BACKTICK_IDENTIFIER"
  ) {
    return {
      source_name:
        firstToken.normalized_token,
      source_type: "OBJECT",
      next_index: startIndex + 1,
      end_token_seq:
        firstToken.token_seq
    };
  }

  if (!isIdentifierToken(firstToken)) {
    return null;
  }

  const parts = [firstToken.token];
  let tokenIndex = startIndex + 1;
  let endToken = firstToken;

  while (
    tokenIndex + 1 < tokens.length &&
    tokens[tokenIndex].token === "." &&
    isIdentifierToken(
      tokens[tokenIndex + 1]
    )
  ) {
    parts.push(tokens[tokenIndex + 1].token);

    endToken = tokens[tokenIndex + 1];
    tokenIndex += 2;
  }

  return {
    source_name: parts.join("."),
    source_type: "OBJECT",
    next_index: tokenIndex,
    end_token_seq:
      endToken.token_seq
  };
}


function parseSource(tokens, startIndex) {
  const firstToken = tokens[startIndex];

  if (!firstToken) {
    return null;
  }

  /*
   * FROM (SELECT ...) alias
   */
  if (firstToken.token === "(") {
    const closeIndex =
      findMatchingCloseParenthesis(
        tokens,
        startIndex
      );

    if (closeIndex < 0) {
      return null;
    }

    const subqueryTokens =
      tokens.slice(
        startIndex + 1,
        closeIndex
      );

    const aliasResult =
      parseSourceAlias(
        tokens,
        closeIndex + 1
      );

    return {
      source_type: "SUBQUERY",
      source_name:
        tokensToText(subqueryTokens),
      source_alias:
        aliasResult.source_alias,
      start_token_seq:
        firstToken.token_seq,
      end_token_seq:
        tokens[closeIndex].token_seq,
      next_index:
        aliasResult.next_index
    };
  }

  /*
   * UNNEST(expression)
   */
  if (
    firstToken.normalized_token === "UNNEST"
  ) {
    const openIndex = startIndex + 1;

    if (
      !tokens[openIndex] ||
      tokens[openIndex].token !== "("
    ) {
      return null;
    }

    const closeIndex =
      findMatchingCloseParenthesis(
        tokens,
        openIndex
      );

    if (closeIndex < 0) {
      return null;
    }

    const unnestExpressionTokens =
      tokens.slice(
        openIndex + 1,
        closeIndex
      );

    const aliasResult =
      parseSourceAlias(
        tokens,
        closeIndex + 1
      );

    return {
      source_type: "UNNEST",
      source_name:
        tokensToText(
          unnestExpressionTokens
        ),
      source_alias:
        aliasResult.source_alias,
      start_token_seq:
        firstToken.token_seq,
      end_token_seq:
        tokens[closeIndex].token_seq,
      next_index:
        aliasResult.next_index
    };
  }

  /*
   * 通常のテーブル・View・CTE名
   */
  const dottedSource =
    parseDottedSourceName(
      tokens,
      startIndex
    );

  if (!dottedSource) {
    return null;
  }

  const aliasResult =
    parseSourceAlias(
      tokens,
      dottedSource.next_index
    );

  return {
    source_type:
      dottedSource.source_type,
    source_name:
      dottedSource.source_name,
    source_alias:
      aliasResult.source_alias,
    start_token_seq:
      firstToken.token_seq,
    end_token_seq:
      dottedSource.end_token_seq,
    next_index:
      aliasResult.next_index
  };
}


function detectJoin(tokens, startIndex) {
  let tokenIndex = startIndex;
  const words = [];

  while (
    tokenIndex < tokens.length &&
    JOIN_MODIFIERS.has(
      tokens[tokenIndex].normalized_token
    )
  ) {
    words.push(
      tokens[tokenIndex].normalized_token
    );

    tokenIndex++;
  }

  if (
    tokens[tokenIndex] &&
    tokens[tokenIndex].normalized_token === "JOIN"
  ) {
    words.push("JOIN");

    return {
      join_type: words.join("_"),
      source_start_index:
        tokenIndex + 1
    };
  }

  return null;
}


function parseFrom(tokens, fromClause) {
  const fromTokens =
    sliceTokensBySequence(
      tokens,
      fromClause.body_start_seq,
      fromClause.body_end_seq
    ).filter(
      (token) =>
        token.token_type !== "COMMENT"
    );

  const sources = [];
  let tokenIndex = 0;

  /*
   * FROM直後の最初のSource
   */
  const firstSource =
    parseSource(
      fromTokens,
      tokenIndex
    );

  if (firstSource) {
    sources.push({
      join_type: "FROM",
      source_type:
        firstSource.source_type,
      source_name:
        firstSource.source_name,
      source_alias:
        firstSource.source_alias,
      start_token_seq:
        firstSource.start_token_seq,
      end_token_seq:
        firstSource.end_token_seq
    });

    tokenIndex =
      firstSource.next_index;
  }

  while (tokenIndex < fromTokens.length) {
    const currentToken =
      fromTokens[tokenIndex];

    /*
     * カンマJOIN
     *
     * FROM table_a a, UNNEST(a.items) item
     */
    if (
      currentToken.token === "," &&
      currentToken.paren_depth === 0
    ) {
      const commaSource =
        parseSource(
          fromTokens,
          tokenIndex + 1
        );

      if (commaSource) {
        sources.push({
          join_type: "COMMA",
          source_type:
            commaSource.source_type,
          source_name:
            commaSource.source_name,
          source_alias:
            commaSource.source_alias,
          start_token_seq:
            commaSource.start_token_seq,
          end_token_seq:
            commaSource.end_token_seq
        });

        tokenIndex =
          commaSource.next_index;

        continue;
      }
    }

    /*
     * JOIN
     */
    const join =
      detectJoin(
        fromTokens,
        tokenIndex
      );

    if (join) {
      const joinedSource =
        parseSource(
          fromTokens,
          join.source_start_index
        );

      if (joinedSource) {
        sources.push({
          join_type:
            join.join_type,
          source_type:
            joinedSource.source_type,
          source_name:
            joinedSource.source_name,
          source_alias:
            joinedSource.source_alias,
          start_token_seq:
            joinedSource.start_token_seq,
          end_token_seq:
            joinedSource.end_token_seq
        });

        tokenIndex =
          joinedSource.next_index;

        continue;
      }
    }

    tokenIndex++;
  }

  return sources;
}


/* ============================================================
 * UDF Entry Point
 * ============================================================ */

if (sql_text === null) {
  return [];
}

const tokens =
  tokenize(sql_text);

const clauses =
  parseClauses(tokens);

const output = [];

/*
 * SELECT項目
 */
const selectClause = clauses.find(
  (clause) =>
    clause.clause === "SELECT"
);

if (selectClause) {
  const selectItems =
    parseSelect(
      tokens,
      selectClause
    );

  for (const selectItem of selectItems) {
    output.push({
      record_seq: output.length + 1,
      record_type: "SELECT_ITEM",

      expression:
        selectItem.expression,
      output_alias:
        selectItem.output_alias,
      alias_type:
        selectItem.alias_type,

      source_type: null,
      source_name: null,
      source_alias: null,
      join_type: null,

      start_token_seq:
        selectItem.start_token_seq,
      end_token_seq:
        selectItem.end_token_seq
    });
  }
}

/*
 * FROM・JOIN
 */
const fromClause = clauses.find(
  (clause) =>
    clause.clause === "FROM"
);

if (fromClause) {
  const sources =
    parseFrom(
      tokens,
      fromClause
    );

  for (const source of sources) {
    output.push({
      record_seq: output.length + 1,
      record_type: "SOURCE",

      expression: null,
      output_alias: null,
      alias_type: null,

      source_type:
        source.source_type,
      source_name:
        source.source_name,
      source_alias:
        source.source_alias,
      join_type:
        source.join_type,

      start_token_seq:
        source.start_token_seq,
      end_token_seq:
        source.end_token_seq
    });
  }
}

return output;
""";