# v1.4.0-006

- PIVOT生成列を外側SUBQUERYで明示列挙した際、親SUBQUERY Sourceを誤採用して同一scopeへ戻る自己循環を修正。
- derivedScopeIdが参照元scope自身を指した場合、現在scope内の実CTE/SUBQUERY Sourceへ補正。
- 複雑VIEW SQLを回帰対象として維持。
