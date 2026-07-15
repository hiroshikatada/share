/**
 * 現在位置以降で、最初の非COMMENT Tokenを探す。
 *
 * 現在位置は変更しない。
 *
 * 戻り値:
 *
 * {
 *   index: 非COMMENT Tokenの配列index,
 *   token: 非COMMENT Token本体
 * }
 *
 * 見つからなければnullを返す。
 *
 * startOffset=0:
 *   現在位置から検索する。
 *
 * startOffset=1:
 *   現在位置の次のTokenから検索する。
 *
 * @param {number} startOffset
 * @returns {{index: number, token: object}|null}
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
    const targetToken =
      this.tokens[targetIndex];

    if (
      targetToken.token_type !==
      "COMMENT"
    ) {
      return {
        index: targetIndex,
        token: targetToken
      };
    }

    targetIndex++;
  }

  return null;
}