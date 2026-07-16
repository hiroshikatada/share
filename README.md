# Select Parser v1

## 構成

- `lexer.js`
- `token_reader.js`
- `clause_parser.js`
- `select_parser.js`
- `test_clause_parser.js`
- `test_token_reader.js`
- `test_select_parser.js`

## 実行

```bash
node test_select_parser.js
```

## Select Parserの役割

SELECT句を同じ`paren_depth`のカンマで項目分割し、各項目について次を返します。

- 項目全体のtoken_seq範囲
- 式部分のtoken_seq範囲
- 確認用の式文字列
- 明示的・暗黙的alias
- 単純カラムから導出した出力名
- `*`または`table.*`のWildcard情報

位置情報はすべて`token_seq`です。
