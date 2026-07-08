function isTopLevel(token) {
  return token.paren_depth === 0;
}

function tokenAt(tokens, index) {
  return tokens[index] || null;
}

function norm(tokens, index) {
  const token = tokenAt(tokens, index);
  return token ? token.normalized_token : "";
}

function detectClause(tokens, index) {
  const t1 = norm(tokens, index);
  const t2 = norm(tokens, index + 1);

  if (t1 === "SELECT") {
    return { clause: "SELECT", length: 1 };
  }

  if (t1 === "FROM") {
    return { clause: "FROM", length: 1 };
  }

  if (t1 === "WHERE") {
    return { clause: "WHERE", length: 1 };
  }

  if (t1 === "HAVING") {
    return { clause: "HAVING", length: 1 };
  }

  if (t1 === "QUALIFY") {
    return { clause: "QUALIFY", length: 1 };
  }

  if (t1 === "LIMIT") {
    return { clause: "LIMIT", length: 1 };
  }

  if (t1 === "GROUP" && t2 === "BY") {
    return { clause: "GROUP_BY", length: 2 };
  }

  if (t1 === "ORDER" && t2 === "BY") {
    return { clause: "ORDER_BY", length: 2 };
  }

  return null;
}

function parseClauses(tokens) {
  const clauses = [];

  for (let i = 0; i < tokens.length; i++) {
    const token = tokens[i];

    if (!isTopLevel(token)) {
      continue;
    }

    const detected = detectClause(tokens, i);

    if (!detected) {
      continue;
    }

    clauses.push({
      clause_seq: clauses.length + 1,
      clause: detected.clause,
      clause_start_seq: token.token_seq,
      body_start_seq: token.token_seq + detected.length,
      body_end_seq: null,
      paren_depth: token.paren_depth,
    });
  }

  for (let i = 0; i < clauses.length; i++) {
    const current = clauses[i];
    const next = clauses[i + 1];

    current.body_end_seq = next
      ? next.clause_start_seq - 1
      : tokens[tokens.length - 1].token_seq;
  }

  return clauses;
}

module.exports = {
  parseClauses,
};