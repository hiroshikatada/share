# BigQuery Lineage Repository 引き継ぎメモ

## 目的

BigQueryのView/Scheduled Queryを解析し、物理カラムまで展開したLineage
Repositoryを構築する。

## 構成

-   JS: lineage_udf_bundle.js
-   永続UDF: analyze_lineage_json
-   Repository: audeodb.lineage_repository
-   対象: audeodb.sample_ds

## Repositoryテーブル

-   lineage_definition_registry
-   lineage_direct_dependency
-   lineage_impact
-   lineage_diagnostic

## 実行状況

v1.0.3で01〜05はすべて正常終了。

## 実機検証で修正した内容

-   ARRAY列のNOT NULL削除
-   CLUSTER BY 5→4列
-   全SQLへSET @@location='asia-northeast1'
-   CURRENT_TIME→CURRENT_TIMESTAMP
-   DECLAREをスクリプト先頭へ移動

## 現状

-   definition_registry:12件
-   direct_dependency:0件
-   impact:生成済み
-   diagnostic:0件

## 判明している課題

-   lineage_impactのorigin_project/origin_dataset/origin_column等が大文字保存されるため、05_validation_queries.sqlの小文字条件と一致しない。
-   大文字小文字の統一方針が必要。

## UDF

初回エラー: BigQueryExporter: analysis_id is required
analysis_idを渡すよう修正済み。

## 次の実装

06_analyze_changed_objects.sql

処理: 1. is_changed=TRUE抽出 2. analyze_lineage_json実行 3.
lineage_direct_dependency更新 4. lineage_impact再構築 5.
is_changed=FALSE

## アーキテクチャ

Definition Registry → analyze_lineage_json(UDF) →
lineage_direct_dependency → lineage_impact

Parserは完成に近く、今後はRepository側を中心に実装する。
