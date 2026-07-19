# v1.4.0-003

## 変更内容

- `FromParser`でBigQueryの`PIVOT`および`UNPIVOT`をFROMソースに適用される後置演算子として認識するよう修正。
- `PIVOT`と`UNPIVOT`を暗黙のテーブル別名として消費しないよう、予約語判定を修正。
- PIVOT/UNPIVOT本文の開始・終了token_seqを`relation_operators`としてFROMソースASTへ保持。
- v1.4.0-002のDiagnosticsテストを意図的な不正JOIN SQLへ切り替え、診断機能の回帰テストとして独立化。
- 複雑なWITH RECURSIVE / UNION / ARRAY / PIVOT / UNPIVOT / QUALIFY SQLを回帰テストへ追加。

## 修正した不具合

旧実装では次の構文の`PIVOT`を暗黙Aliasとして読み、その直後の`(`をJOIN開始として誤認していました。

```sql
SELECT * FROM (...)
PIVOT (...)
```

このため`FromParser: JOIN was expected, but found "(".`で停止していました。

## テスト結果

- 既存テスト: PASS
- Parser Diagnostics回帰テスト: PASS
- `v_ec_complex_union.sql`: `COMPLETED_WITH_WARNINGS`
- QUERY_PARSERエラー: 解消

`COMPLETED_WITH_WARNINGS`の警告は、テスト環境で物理カラムメタデータが渡されていないことによる`PHYSICAL_METADATA_NOT_FOUND`であり、Parserエラーではありません。
