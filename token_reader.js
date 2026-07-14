"use strict";

/**
 * Lexerが生成したToken配列を読み取るための補助クラス。
 *
 * TokenReaderの目的:
 *
 * - 現在位置のTokenを取得する
 * - 前後のTokenを確認する
 * - 読み取り位置を移動する
 * - コメントを読み飛ばす
 * - 対応する閉じ括弧を探す
 * - Token範囲を切り出す
 * - 特定のTokenを前方検索する
 *
 * Token配列そのものは変更しない。
 * TokenReaderが変更するのは、現在位置を表すindexだけ。
 */
class TokenReader {
  /**
   * TokenReaderを作成する。
   *
   * @param {Array<object>} tokens
   *   Lexerが生成したToken配列。
   *
   * @param {number} startIndex
   *   読み取りを開始する配列index。
   *   省略時は0。
   */
  constructor(tokens, startIndex = 0) {
    if (!Array.isArray(tokens)) {
      throw new TypeError(
        "TokenReader: tokens must be an array."
      );
    }

    if (
      !Number.isInteger(startIndex) ||
      startIndex < 0 ||
      startIndex > tokens.length
    ) {
      throw new RangeError(
        "TokenReader: startIndex is out of range."
      );
    }

    /**
     * Lexerが生成したToken配列。
     *
     * TokenReaderでは配列の内容を書き換えないため、
     * コピーせず元の配列をそのまま参照する。
     */
    this.tokens = tokens;

    /**
     * 現在読み取っているTokenの配列index。
     *
     * 注意:
     *
     * indexはJavaScript配列上の位置で、0始まり。
     *
     * token_seqはLexerがTokenへ付けた論理連番で、
     * 通常は1始まり。
     */
    this.index = startIndex;
  }

  /**
   * Token配列の要素数を返す。
   *
   * @returns {number}
   */
  get length() {
    return this.tokens.length;
  }

  /**
   * 現在の配列indexを返す。
   *
   * @returns {number}
   */
  get position() {
    return this.index;
  }

  /**
   * 現在位置がToken配列内にあるか判定する。
   *
   * @returns {boolean}
   */
  hasCurrent() {
    return (
      this.index >= 0 &&
      this.index < this.tokens.length
    );
  }

  /**
   * 読み取り位置がToken配列の末尾を超えているか判定する。
   *
   * @returns {boolean}
   */
  isEnd() {
    return this.index >= this.tokens.length;
  }

  /**
   * 現在位置のTokenを返す。
   *
   * 現在位置が配列外ならnullを返す。
   *
   * @returns {object|null}
   */
  current() {
    return this.tokens[this.index] || null;
  }

  /**
   * 現在位置から相対的な場所にあるTokenを返す。
   *
   * reader.peek(0)
   *   現在のToken
   *
   * reader.peek(1)
   *   1つ先のToken
   *
   * reader.peek(2)
   *   2つ先のToken
   *
   * reader.peek(-1)
   *   1つ前のToken
   *
   * 読み取り位置this.indexは変更しない。
   *
   * @param {number} offset
   * @returns {object|null}
   */
  peek(offset = 0) {
    if (!Number.isInteger(offset)) {
      throw new TypeError(
        "TokenReader.peek: offset must be an integer."
      );
    }

    const targetIndex =
      this.index + offset;

    return this.tokens[targetIndex] || null;
  }

  /**
   * 1つ前のTokenを返す。
   *
   * 読み取り位置は変更しない。
   *
   * @returns {object|null}
   */
  previous() {
    return this.peek(-1);
  }

  /**
   * 1つ先のTokenを返す。
   *
   * 読み取り位置は変更しない。
   *
   * @returns {object|null}
   */
  nextToken() {
    return this.peek(1);
  }

  /**
   * 現在のTokenを取得したあと、indexを1つ進める。
   *
   * 例えば現在位置がSELECTの場合、
   *
   * const token = reader.consume();
   *
   * とすると、
   *
   * tokenにはSELECT Tokenが入り、
   * readerの現在位置は次のTokenへ移動する。
   *
   * @returns {object|null}
   */
  consume() {
    const token = this.current();

    if (this.hasCurrent()) {
      this.index++;
    }

    return token;
  }

  /**
   * indexを指定数だけ進める。
   *
   * 配列の末尾を超えないように制御する。
   *
   * @param {number} count
   * @returns {TokenReader}
   */
  advance(count = 1) {
    if (
      !Number.isInteger(count) ||
      count < 0
    ) {
      throw new TypeError(
        "TokenReader.advance: count must be a non-negative integer."
      );
    }

    this.index = Math.min(
      this.index + count,
      this.tokens.length
    );

    /**
     * thisを返すため、次のように処理を連結できる。
     *
     * reader
     *   .advance()
     *   .skipComments();
     */
    return this;
  }

  /**
   * indexを指定数だけ戻す。
   *
   * indexが0未満にならないように制御する。
   *
   * @param {number} count
   * @returns {TokenReader}
   */
  rewind(count = 1) {
    if (
      !Number.isInteger(count) ||
      count < 0
    ) {
      throw new TypeError(
        "TokenReader.rewind: count must be a non-negative integer."
      );
    }

    this.index = Math.max(
      this.index - count,
      0
    );

    return this;
  }

  /**
   * 読み取り位置を指定indexへ移動する。
   *
   * tokens.lengthと同じ位置も許可する。
   * その場合、isEnd()はtrueになる。
   *
   * @param {number} targetIndex
   * @returns {TokenReader}
   */
  moveTo(targetIndex) {
    if (
      !Number.isInteger(targetIndex) ||
      targetIndex < 0 ||
      targetIndex > this.tokens.length
    ) {
      throw new RangeError(
        "TokenReader.moveTo: targetIndex is out of range."
      );
    }

    this.index = targetIndex;

    return this;
  }

  /**
   * 読み取り位置を先頭へ戻す。
   *
   * @returns {TokenReader}
   */
  reset() {
    this.index = 0;

    return this;
  }

  /**
   * 現在位置を保存する。
   *
   * mark()が返す値は単なる配列index。
   * 後でrestore()へ渡して元の位置へ戻せる。
   *
   * @returns {number}
   */
  mark() {
    return this.index;
  }

  /**
   * mark()で保存した位置へ戻る。
   *
   * @param {number} markedIndex
   * @returns {TokenReader}
   */
  restore(markedIndex) {
    return this.moveTo(markedIndex);
  }

  /**
   * 現在Tokenが指定文字列と一致するか判定する。
   *
   * normalized=trueの場合:
   *   normalized_tokenで比較する。
   *   比較対象valueも大文字化する。
   *
   * normalized=falseの場合:
   *   元のtoken文字列で比較する。
   *
   * 例:
   *
   * reader.matches("select")
   *
   * normalized=trueなので、
   * SELECTと大文字小文字を無視して一致する。
   *
   * @param {string} value
   * @param {boolean} normalized
   * @returns {boolean}
   */
  matches(value, normalized = true) {
    const token = this.current();

    if (!token) {
      return false;
    }

    const actualValue =
      normalized
        ? token.normalized_token
        : token.token;

    const expectedValue =
      normalized
        ? String(value).toUpperCase()
        : String(value);

    return actualValue === expectedValue;
  }

  /**
   * 現在Tokenのtoken_typeが指定値と一致するか判定する。
   *
   * @param {string} tokenType
   * @returns {boolean}
   */
  matchesType(tokenType) {
    const token = this.current();

    return (
      token !== null &&
      token.token_type === tokenType
    );
  }

  /**
   * 現在Tokenが、指定した候補のどれかと一致するか判定する。
   *
   * 例:
   *
   * reader.matchesAny([
   *   "LEFT",
   *   "RIGHT",
   *   "INNER"
   * ]);
   *
   * Array.prototype.some()は、
   * 1つでも条件を満たせばtrueを返す。
   *
   * @param {string[]} values
   * @param {boolean} normalized
   * @returns {boolean}
   */
  matchesAny(
    values,
    normalized = true
  ) {
    if (!Array.isArray(values)) {
      throw new TypeError(
        "TokenReader.matchesAny: values must be an array."
      );
    }

    return values.some(
      (value) =>
        this.matches(
          value,
          normalized
        )
    );
  }

  /**
   * 現在Tokenが指定値なら、そのTokenを返して1つ進む。
   *
   * 一致しなければnullを返し、現在位置は変更しない。
   *
   * @param {string} value
   * @param {boolean} normalized
   * @returns {object|null}
   */
  consumeIf(
    value,
    normalized = true
  ) {
    if (
      !this.matches(
        value,
        normalized
      )
    ) {
      return null;
    }

    return this.consume();
  }

  /**
   * 現在Tokenのtoken_typeが指定値なら、
   * Tokenを返して1つ進む。
   *
   * 一致しなければnullを返し、現在位置は変更しない。
   *
   * @param {string} tokenType
   * @returns {object|null}
   */
  consumeTypeIf(tokenType) {
    if (
      !this.matchesType(
        tokenType
      )
    ) {
      return null;
    }

    return this.consume();
  }

  /**
   * 現在位置から連続するCOMMENT Tokenを読み飛ばす。
   *
   * @returns {TokenReader}
   */
  skipComments() {
    while (
      this.hasCurrent() &&
      this.matchesType("COMMENT")
    ) {
      this.advance();
    }

    return this;
  }

  /**
   * 現在位置以降で最初の非COMMENT Tokenを返す。
   *
   * 現在位置は変更しない。
   *
   * startOffset=0なら現在位置から検索する。
   * startOffset=1なら次のTokenから検索する。
   *
   * @param {number} startOffset
   * @returns {object|null}
   */
  peekNonComment(
    startOffset = 0
  ) {
    if (
      !Number.isInteger(startOffset) ||
      startOffset < 0
    ) {
      throw new TypeError(
        "TokenReader.peekNonComment: startOffset must be a non-negative integer."
      );
    }

    let targetIndex =
      this.index + startOffset;

    while (
      targetIndex <
      this.tokens.length
    ) {
      const token =
        this.tokens[targetIndex];

      if (
        token.token_type !==
        "COMMENT"
      ) {
        return token;
      }

      targetIndex++;
    }

    return null;
  }

  /**
   * 現在位置以降で最初の非COMMENT Tokenのindexを返す。
   *
   * 見つからなければ-1を返す。
   *
   * @param {number} startOffset
   * @returns {number}
   */
  findNextNonCommentIndex(
    startOffset = 0
  ) {
    if (
      !Number.isInteger(startOffset) ||
      startOffset < 0
    ) {
      throw new TypeError(
        "TokenReader.findNextNonCommentIndex: startOffset must be a non-negative integer."
      );
    }

    let targetIndex =
      this.index + startOffset;

    while (
      targetIndex <
      this.tokens.length
    ) {
      if (
        this.tokens[targetIndex]
          .token_type !== "COMMENT"
      ) {
        return targetIndex;
      }

      targetIndex++;
    }

    return -1;
  }

  /**
   * 指定位置の開き括弧"("に対応する閉じ括弧")"を探す。
   *
   * 新しいdepth仕様:
   *
   *   SUM(amount)
   *
   *   SUM     depth 0
   *   (       depth 0
   *   amount  depth 1
   *   )       depth 0
   *
   * 対応する開き括弧と閉じ括弧は同じparen_depthになる。
   *
   * @param {number} openIndex
   * @returns {number}
   */
  findMatchingCloseParenthesis(
    openIndex = this.index
  ) {
    const openToken =
      this.tokens[openIndex];

    if (
      !openToken ||
      openToken.token !== "("
    ) {
      return -1;
    }

    const targetDepth =
      openToken.paren_depth;

    for (
      let tokenIndex =
        openIndex + 1;
      tokenIndex <
        this.tokens.length;
      tokenIndex++
    ) {
      const token =
        this.tokens[tokenIndex];

      if (
        token.token === ")" &&
        token.paren_depth ===
          targetDepth
      ) {
        return tokenIndex;
      }
    }

    return -1;
  }

  /**
   * 指定位置の開き角括弧"["に対応する"]"を探す。
   *
   * 開き角括弧と閉じ角括弧も同じparen_depthになる。
   *
   * @param {number} openIndex
   * @returns {number}
   */
  findMatchingCloseBracket(
    openIndex = this.index
  ) {
    const openToken =
      this.tokens[openIndex];

    if (
      !openToken ||
      openToken.token !== "["
    ) {
      return -1;
    }

    const targetDepth =
      openToken.paren_depth;

    for (
      let tokenIndex =
        openIndex + 1;
      tokenIndex <
        this.tokens.length;
      tokenIndex++
    ) {
      const token =
        this.tokens[tokenIndex];

      if (
        token.token === "]" &&
        token.paren_depth ===
          targetDepth
      ) {
        return tokenIndex;
      }
    }

    return -1;
  }

  /**
   * token_seqを指定して、JavaScript配列上のindexを探す。
   *
   * 見つからなければ-1を返す。
   *
   * @param {number} tokenSeq
   * @returns {number}
   */
  findIndexByTokenSeq(tokenSeq) {
    if (!Number.isInteger(tokenSeq)) {
      throw new TypeError(
        "TokenReader.findIndexByTokenSeq: tokenSeq must be an integer."
      );
    }

    return this.tokens.findIndex(
      (token) =>
        token.token_seq ===
        tokenSeq
    );
  }

  /**
   * token_seqを指定してTokenを取得する。
   *
   * 見つからなければnull。
   *
   * @param {number} tokenSeq
   * @returns {object|null}
   */
  findByTokenSeq(tokenSeq) {
    const foundIndex =
      this.findIndexByTokenSeq(
        tokenSeq
      );

    if (foundIndex < 0) {
      return null;
    }

    return this.tokens[foundIndex];
  }

  /**
   * 配列indexでToken範囲を切り出す。
   *
   * startIndexとendIndexの両方を結果へ含める。
   *
   * JavaScriptのslice()は第2引数を含まないため、
   * endIndex + 1を渡す。
   *
   * @param {number} startIndex
   * @param {number} endIndex
   * @returns {Array<object>}
   */
  sliceByIndex(
    startIndex,
    endIndex
  ) {
    if (
      !Number.isInteger(startIndex) ||
      !Number.isInteger(endIndex)
    ) {
      throw new TypeError(
        "TokenReader.sliceByIndex: indexes must be integers."
      );
    }

    if (
      startIndex < 0 ||
      endIndex < startIndex ||
      endIndex >= this.tokens.length
    ) {
      return [];
    }

    return this.tokens.slice(
      startIndex,
      endIndex + 1
    );
  }

  /**
   * token_seqの範囲でTokenを切り出す。
   *
   * startTokenSeqとendTokenSeqの両方を含む。
   *
   * token_seqが飛び飛びでも利用できる。
   *
   * @param {number} startTokenSeq
   * @param {number} endTokenSeq
   * @returns {Array<object>}
   */
  sliceByTokenSeq(
    startTokenSeq,
    endTokenSeq
  ) {
    if (
      !Number.isInteger(startTokenSeq) ||
      !Number.isInteger(endTokenSeq)
    ) {
      throw new TypeError(
        "TokenReader.sliceByTokenSeq: token sequences must be integers."
      );
    }

    return this.tokens.filter(
      (token) =>
        token.token_seq >=
          startTokenSeq &&
        token.token_seq <=
          endTokenSeq
    );
  }

  /**
   * 指定した文字列のTokenを前方検索する。
   *
   * options:
   *
   * startIndex
   *   検索開始index。
   *   省略時は現在位置。
   *
   * normalized
   *   trueならnormalized_tokenで比較。
   *
   * targetDepth
   *   数値を指定すると、そのdepthのTokenだけを検索。
   *   nullならdepthを限定しない。
   *
   * skipComments
   *   trueならCOMMENTを検索対象から外す。
   *
   * @param {string} value
   * @param {object} options
   * @returns {number}
   */
  findForward(
    value,
    options = {}
  ) {
    const {
      startIndex = this.index,
      normalized = true,
      targetDepth = null,
      skipComments = true
    } = options;

    if (
      !Number.isInteger(startIndex) ||
      startIndex < 0
    ) {
      throw new TypeError(
        "TokenReader.findForward: startIndex must be a non-negative integer."
      );
    }

    const expectedValue =
      normalized
        ? String(value).toUpperCase()
        : String(value);

    for (
      let tokenIndex = startIndex;
      tokenIndex <
        this.tokens.length;
      tokenIndex++
    ) {
      const token =
        this.tokens[tokenIndex];

      if (
        skipComments &&
        token.token_type ===
          "COMMENT"
      ) {
        continue;
      }

      if (
        targetDepth !== null &&
        token.paren_depth !==
          targetDepth
      ) {
        continue;
      }

      const actualValue =
        normalized
          ? token.normalized_token
          : token.token;

      if (
        actualValue === expectedValue
      ) {
        return tokenIndex;
      }
    }

    return -1;
  }

  /**
   * 現在のTokenReaderとは独立した読み取り位置を持つ、
   * 新しいTokenReaderを作成する。
   *
   * Token配列は同じ配列を参照する。
   * indexだけが独立する。
   *
   * @param {number} startIndex
   * @returns {TokenReader}
   */
  clone(
    startIndex = this.index
  ) {
    return new TokenReader(
      this.tokens,
      startIndex
    );
  }
}


module.exports = {
  TokenReader
};