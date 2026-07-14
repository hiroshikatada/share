"use strict";

const tokenize =
  require("./lexer");

const {
  TokenReader
} = require("./token_reader");


const sql = `
SELECT
  customer_id,
  SUM(IF(amount > 0, amount, 0))
    AS total_amount
FROM project.dataset.sales
WHERE status = 'COMPLETE';
`;


/*
 * Lexerを実行してToken配列を取得する。
 */
const tokens =
  tokenize(sql);


/*
 * Token配列全体を確認する。
 */
console.log(
  "\n===== Lexer result ====="
);

console.table(
  tokens.map(
    (token, index) => ({
      index,
      token_seq:
        token.token_seq,
      token:
        token.token,
      normalized_token:
        token.normalized_token,
      token_type:
        token.token_type,
      paren_depth:
        token.paren_depth
    })
  )
);


/*
 * TokenReaderを作成する。
 *
 * 現在位置はindex=0。
 */
const reader =
  new TokenReader(tokens);


console.log(
  "\n===== Basic information ====="
);

console.log(
  "Token数:",
  reader.length
);

console.log(
  "現在位置:",
  reader.position
);

console.log(
  "現在Token:",
  reader.current()
);

console.log(
  "次Token:",
  reader.peek(1)
);

console.log(
  "末尾か:",
  reader.isEnd()
);


/*
 * matches()とconsume()の確認。
 */
console.log(
  "\n===== matches / consume ====="
);

if (reader.matches("SELECT")) {
  const consumedToken =
    reader.consume();

  console.log(
    "読み取ったToken:",
    consumedToken
  );

  console.log(
    "consume後の位置:",
    reader.position
  );

  console.log(
    "consume後の現在Token:",
    reader.current()
  );
}


/*
 * SUMを前方検索する。
 */
console.log(
  "\n===== findForward ====="
);

const sumIndex =
  reader.findForward("SUM");

console.log(
  "SUMのindex:",
  sumIndex
);

console.log(
  "SUMのToken:",
  tokens[sumIndex]
);


/*
 * SUM位置へ移動する。
 */
reader.moveTo(sumIndex);

console.log(
  "移動後の現在Token:",
  reader.current()
);

console.log(
  "SUMの次のToken:",
  reader.peek(1)
);


/*
 * SUMの次にある開き括弧に対応する
 * 閉じ括弧を検索する。
 */
console.log(
  "\n===== Parenthesis matching ====="
);

const sumOpenIndex =
  sumIndex + 1;

const sumCloseIndex =
  reader.findMatchingCloseParenthesis(
    sumOpenIndex
  );

console.log(
  "SUMの開き括弧index:",
  sumOpenIndex
);

console.log(
  "SUMの開き括弧:",
  tokens[sumOpenIndex]
);

console.log(
  "SUMの閉じ括弧index:",
  sumCloseIndex
);

console.log(
  "SUMの閉じ括弧:",
  tokens[sumCloseIndex]
);


/*
 * SUM(...)全体を切り出す。
 */
console.log(
  "\n===== SUM expression ====="
);

const sumExpressionTokens =
  reader.sliceByIndex(
    sumIndex,
    sumCloseIndex
  );

console.table(
  sumExpressionTokens.map(
    (token) => ({
      token_seq:
        token.token_seq,
      token:
        token.token,
      token_type:
        token.token_type,
      paren_depth:
        token.paren_depth
    })
  )
);


/*
 * SUMの内部にあるIFを検索する。
 *
 * SUMの開き括弧はdepth=0。
 * SUM内部のIFはdepth=1。
 */
console.log(
  "\n===== Search by depth ====="
);

const ifIndex =
  reader.findForward(
    "IF",
    {
      startIndex:
        sumOpenIndex + 1,

      targetDepth:
        tokens[sumOpenIndex]
          .paren_depth + 1
    }
  );

console.log(
  "IFのindex:",
  ifIndex
);

console.log(
  "IFのToken:",
  tokens[ifIndex]
);


/*
 * IFの開き括弧と閉じ括弧を探す。
 */
const ifOpenIndex =
  ifIndex + 1;

const ifCloseIndex =
  reader.findMatchingCloseParenthesis(
    ifOpenIndex
  );

console.log(
  "IFの開き括弧:",
  tokens[ifOpenIndex]
);

console.log(
  "IFの閉じ括弧:",
  tokens[ifCloseIndex]
);


/*
 * IF(...)全体を表示する。
 */
const ifExpressionTokens =
  reader.sliceByIndex(
    ifIndex,
    ifCloseIndex
  );

console.table(
  ifExpressionTokens.map(
    (token) => ({
      token_seq:
        token.token_seq,
      token:
        token.token,
      paren_depth:
        token.paren_depth
    })
  )
);


/*
 * mark()とrestore()の確認。
 */
console.log(
  "\n===== mark / restore ====="
);

reader.reset();

const savedPosition =
  reader.mark();

console.log(
  "保存した位置:",
  savedPosition
);

reader.advance(5);

console.log(
  "5つ進んだ位置:",
  reader.position
);

console.log(
  "現在Token:",
  reader.current()
);

reader.restore(
  savedPosition
);

console.log(
  "restore後の位置:",
  reader.position
);

console.log(
  "restore後の現在Token:",
  reader.current()
);


/*
 * clone()の確認。
 *
 * 元readerとcloneReaderは、
 * 同じToken配列を参照するが、
 * 現在位置はそれぞれ独立している。
 */
console.log(
  "\n===== clone ====="
);

const cloneReader =
  reader.clone();

cloneReader.advance(3);

console.log(
  "元readerの位置:",
  reader.position
);

console.log(
  "cloneReaderの位置:",
  cloneReader.position
);


/*
 * token_seqによる検索。
 */
console.log(
  "\n===== token_seq search ====="
);

const targetTokenSeq = 5;

console.log(
  "token_seq=5のindex:",
  reader.findIndexByTokenSeq(
    targetTokenSeq
  )
);

console.log(
  "token_seq=5のToken:",
  reader.findByTokenSeq(
    targetTokenSeq
  )
);


/*
 * consumeIf()の確認。
 */
console.log(
  "\n===== consumeIf ====="
);

reader.reset();

const selectToken =
  reader.consumeIf("SELECT");

console.log(
  "consumeIfの結果:",
  selectToken
);

console.log(
  "consumeIf後の位置:",
  reader.position
);


/*
 * すべてのTokenをconsume()で読み取る例。
 */
console.log(
  "\n===== consume all tokens ====="
);

const sequentialReader =
  new TokenReader(tokens);

while (!sequentialReader.isEnd()) {
  const token =
    sequentialReader.consume();

  console.log(
    token.token_seq,
    token.token,
    token.paren_depth
  );
}