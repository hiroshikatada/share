function sliceTokensBySeq(tokens, startSeq, endSeq) {
  return tokens.filter(
    (t) => t.token_seq >= startSeq && t.token_seq <= endSeq
  );
}

function tokensToText(tokens) {
  return tokens.map((t) => t.token).join("");
}

function norm(token) {
  return token ? token.normalized_token : "";
}

const JOIN_PREFIX = new Set([
  "JOIN",
  "LEFT",
  "RIGHT",
  "FULL",
  "INNER",
  "OUTER",
  "CROSS",
]);

const STOP_KEYWORDS = new Set([
  "ON",
  "WHERE",
  "GROUP",
  "HAVING",
  "QUALIFY",
  "ORDER",
  "LIMIT",
]);

function isJoinStart(token) {
  return token && token.token_type === "KEYWORD" && JOIN_PREFIX.has(norm(token));
}

function isSourceStart(token) {
  return token && (
    norm(token) === "FROM" ||
    isJoinStart(token)
  );
}

function skipJoinWords(tokens, index) {
  let i = index;

  // FROMはそのまま1つ進める
  if (norm(tokens[i]) === "FROM") {
    return i + 1;
  }

  // LEFT OUTER JOIN / INNER JOIN / CROSS JOIN などをJOINまで読み飛ばす
  while (i < tokens.length) {
    if (norm(tokens[i]) === "JOIN") {
      return i + 1;
    }

    if (!JOIN_PREFIX.has(norm(tokens[i]))) {
      return i;
    }

    i++;
  }

  return i;
}

function parseAlias(tokens, index) {
  if (!tokens[index]) {
    return { alias: null, nextIndex: index };
  }

  if (norm(tokens[index]) === "AS" && tokens[index + 1]) {
    return {
      alias: tokens[index + 1].normalized_token,
      nextIndex: index + 2,
    };
  }

  const t = tokens[index];

  if (
    t.token_type === "IDENTIFIER" &&
    !STOP_KEYWORDS.has(norm(t)) &&
    !JOIN_PREFIX.has(norm(t))
  ) {
    return {
      alias: t.normalized_token,
      nextIndex: index + 1,
    };
  }

  return { alias: null, nextIndex: index };
}

function parseDottedIdentifier(tokens, index) {
  const parts = [];
  let i = index;

  if (tokens[i] && tokens[i].token_type === "BACKTICK_IDENTIFIER") {
    return {
      source_name: tokens[i].normalized_token,
      source_type: "BACKTICK_IDENTIFIER",
      nextIndex: i + 1,
    };
  }

  while (i < tokens.length) {
    const t = tokens[i];

    if (!t) break;

    if (t.token_type === "IDENTIFIER" || t.token_type === "KEYWORD") {
      parts.push(t.token);
      i++;

      if (tokens[i] && tokens[i].token === ".") {
        i++;
        continue;
      }

      break;
    }

    break;
  }

  if (parts.length === 0) {
    return null;
  }

  return {
    source_name: parts.join("."),
    source_type: "IDENTIFIER",
    nextIndex: i,
  };
}

function findMatchingParen(tokens, openIndex) {
  const openDepth = tokens[openIndex].paren_depth;

  for (let i = openIndex + 1; i < tokens.length; i++) {
    if (
      tokens[i].token === ")" &&
      tokens[i].paren_depth === openDepth + 1
    ) {
      return i;
    }
  }

  return -1;
}

function parseSource(tokens, index) {
  const t = tokens[index];

  if (!t) {
    return null;
  }

  // FROM (SELECT ...) x
  if (t.token === "(") {
    const closeIndex = findMatchingParen(tokens, index);

    if (closeIndex >= 0) {
      const innerTokens = tokens.slice(index + 1, closeIndex);
      const aliasInfo = parseAlias(tokens, closeIndex + 1);

      return {
        source_type: "SUBQUERY",
        source_name: tokensToText(innerTokens),
        alias: aliasInfo.alias,
        start_token_seq: t.token_seq,
        end_token_seq: tokens[closeIndex].token_seq,
        nextIndex: aliasInfo.nextIndex,
      };
    }
  }

  // UNNEST(...)
  if (norm(t) === "UNNEST") {
    const openIndex = index + 1;

    if (tokens[openIndex] && tokens[openIndex].token === "(") {
      const closeIndex = findMatchingParen(tokens, openIndex);
      const innerTokens = closeIndex >= 0
        ? tokens.slice(openIndex + 1, closeIndex)
        : [];

      const aliasInfo = parseAlias(tokens, closeIndex + 1);

      return {
        source_type: "UNNEST",
        source_name: tokensToText(innerTokens),
        alias: aliasInfo.alias,
        start_token_seq: t.token_seq,
        end_token_seq: closeIndex >= 0 ? tokens[closeIndex].token_seq : t.token_seq,
        nextIndex: aliasInfo.nextIndex,
      };
    }
  }

  const source = parseDottedIdentifier(tokens, index);

  if (!source) {
    return null;
  }

  const aliasInfo = parseAlias(tokens, source.nextIndex);

  return {
    source_type: source.source_type,
    source_name: source.source_name,
    alias: aliasInfo.alias,
    start_token_seq: tokens[index].token_seq,
    end_token_seq: tokens[source.nextIndex - 1].token_seq,
    nextIndex: aliasInfo.nextIndex,
  };
}

function parseFrom(tokens, fromClause) {
  const fromTokens = sliceTokensBySeq(
    tokens,
    fromClause.clause_start_seq,
    fromClause.body_end_seq
  );

  const sources = [];

  for (let i = 0; i < fromTokens.length; i++) {
    const t = fromTokens[i];

    if (!isSourceStart(t)) {
      continue;
    }

    const sourceIndex = skipJoinWords(fromTokens, i);
    const source = parseSource(fromTokens, sourceIndex);

    if (!source) {
      continue;
    }

    sources.push({
      source_seq: sources.length + 1,
      join_type: norm(t) === "FROM" ? "FROM" : "JOIN",
      source_type: source.source_type,
      source_name: source.source_name,
      alias: source.alias,
      start_token_seq: source.start_token_seq,
      end_token_seq: source.end_token_seq,
    });
  }

  return sources;
}

module.exports = {
  parseFrom,
};