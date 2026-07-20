# BigQuery Physical Lineage Repository 引き継ぎ資料

## 概要

BigQueryで物理カラム変更時の影響範囲を解析するRepositoryシステム。

構成: Definition Registry → lineage_udf_bundle.js →
lineage_direct_dependency → lineage_impact

## Repository

Dataset: audeodb.lineage_repository

テーブル: - lineage_definition_registry - lineage_direct_dependency -
lineage_impact - lineage_diagnostic

解析対象: - audeodb.sample_ds の View - Scheduled Query

## SQL

1.  01_create_repository_tables.sql
2.  02_sync_view_registry.sql
3.  03_sync_scheduled_ctas_registry.sql
4.  04_rebuild_impact_table.sql
5.  05_validation_queries.sql
6.  06_analyze_changed_objects.sql（未実装）

## v1.0.3までの修正

-   ARRAY NOT NULL削除
-   CLUSTER BYを4列へ
-   全SQLへSET @@location='asia-northeast1'
-   CURRENT_TIMESTAMPへ統一
-   DECLAREを先頭へ移動

## 動作確認

01〜05正常終了。 definition_registry=12件 direct_dependency=0件
impact=0件 diagnostic=0件

## 既知課題

-   06_analyze_changed_objects.sql未実装
-   lineage_impactはorigin\_*が大文字、impacted\_*は小文字混在。Repository全体で大文字小文字の正規化が必要。
-   Validation SQLはLOWER()/UPPER()対応予定。

## 次フェーズ

1.  06_analyze_changed_objects.sql実装
2.  UDF解析→direct_dependency登録
3.  impact再構築
4.  diagnostics更新
