# v1.4.0-002

## Added
- Parser/Resolver例外を構造化する診断情報を追加。
- `parser_stage`, `token_seq`, `line_no`, `column_no`, `token`, `context_tokens` を診断JSONへ出力。
- `analysis.error_detail_json` を追加し、最初のERROR診断を分析行から直接確認可能にした。

## Changed
- `FromParser` の JOIN期待エラーに、失敗Tokenを付与。
- 今回の複雑SQLでは `PIVOT (` の開き括弧位置を特定可能。

## Compatibility
- 既存フィールドと公開APIは維持。
- 保存テーブルには `error_detail_json JSON` の追加が必要。
