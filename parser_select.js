function sliceTokensBySeq(tokens, startSeq, endSeq) {
  return tokens.filter(
    (t) => t.token_seq >= startSeq && t.token_seq <= endSeq
  );
}

function tokensToText(tokens) {
  return tokens.map((t) => t.token).join("");
}

function trimTokenArray(tokens) {
  let start = 0;
  let end = tokens.length - 1;

  while (start <= end && tokens[start].token_type === "COMMENT") start++;
  while (end >= start && tokens[end].token_type === "COMMENT") end--;

  return tokens.slice(start, end + 1);
}

function splitTopLevelByComma(tokens) {
  const result = [];
  let current = [];

  for (const token of tokens) {
    if (
      token.token === "," &&
      token.paren_depth === 0
    ) {
      const item = trimTokenArray(current);
      if (item.length > 0) result.push(item);
      current = [];
      continue;
    }

    current.push(token);
  }

  const last = trimTokenArray(current);
  if (last.length > 0) result.push(last);

  return result;
}

function parseAlias(itemTokens) {
  if (itemTokens.length === 0) {
    return {
      expression_tokens: [],
      expression: "",
      output_alias: null,
      alias_type: "NONE",
    };
  }

  // AS alias
  for (let i = itemTokens.length - 2; i >= 0; i--) {
    const t = itemTokens[i];

    if (
      t.normalized_token === "AS" &&
      t.paren_depth === 0
    ) {
      const aliasToken = itemTokens[i + 1];

      return {
        expression_tokens: itemTokens.slice(0, i),
        expression: tokensToText(itemTokens.slice(0, i)),
        output_alias: aliasToken ? aliasToken.normalized_token : null,
        alias_type: "EXPLICIT_AS",
      };
    }
  }

  // implicit alias: SUM(amount) total_amount
  const last = itemTokens[itemTokens.length - 1];
  const prev = itemTokens[itemTokens.length - 2];

  if (
    last &&
    last.token_type === "IDENTIFIER" &&
    prev &&
    prev.token !== "." &&
    itemTokens.length >= 2
  ) {
    return {
      expression_tokens: itemTokens.slice(0, itemTokens.length - 1),
      expression: tokensToText(itemTokens.slice(0, itemTokens.length - 1)),
      output_alias: last.normalized_token,
      alias_type: "IMPLICIT",
    };
  }

  // direct column alias: c.customer_id -> customer_id
  if (itemTokens.length >= 3) {
    const a = itemTokens[itemTokens.length - 3];
    const dot = itemTokens[itemTokens.length - 2];
    const col = itemTokens[itemTokens.length - 1];

    if (
      dot.token === "." &&
      col.token_type === "IDENTIFIER"
    ) {
      return {
        expression_tokens: itemTokens,
        expression: tokensToText(itemTokens),
        output_alias: col.normalized_token,
        alias_type: "DERIVED_COLUMN",
      };
    }
  }

  // single column: customer_id -> customer_id
  if (
    itemTokens.length === 1 &&
    itemTokens[0].token_type === "IDENTIFIER"
  ) {
    return {
      expression_tokens: itemTokens,
      expression: tokensToText(itemTokens),
      output_alias: itemTokens[0].normalized_token,
      alias_type: "DERIVED_COLUMN",
    };
  }

  return {
    expression_tokens: itemTokens,
    expression: tokensToText(itemTokens),
    output_alias: null,
    alias_type: "NONE",
  };
}

function parseSelect(tokens, selectClause) {
  const selectTokens = sliceTokensBySeq(
    tokens,
    selectClause.body_start_seq,
    selectClause.body_end_seq
  );

  const items = splitTopLevelByComma(selectTokens);

  return items.map((itemTokens, index) => {
    const parsed = parseAlias(itemTokens);

    return {
      select_item_seq: index + 1,
      expression: parsed.expression,
      output_alias: parsed.output_alias,
      alias_type: parsed.alias_type,
      start_token_seq: itemTokens[0].token_seq,
      end_token_seq: itemTokens[itemTokens.length - 1].token_seq,
    };
  });
}

module.exports = {
  parseSelect,
};