SET @@location = 'asia-northeast1';

-- =============================================================================
-- 指定したTABLE / VIEWカラムから影響を受ける後続カラムをRank順に取得する
--
-- 手元確認時は、以下のDECLARE値を書き換えて実行してください。
-- project / datasetを空文字にすると、その条件では絞り込みません。
-- object_nameにはTABLE名またはVIEW名を指定します。
-- column_nameには通常列またはSTRUCT/RECORDのfield_pathを指定できます。
--
-- 例:
--   input_object_name = 'customer_purchase_history'
--   input_column_name = 'unit_price'
--
-- STRUCT子フィールド例:
--   input_object_name = 'customer_purchase_history'
--   input_column_name = 'delivery_address.contact.phone'
-- =============================================================================

DECLARE input_project STRING DEFAULT 'audeodb';
DECLARE input_dataset STRING DEFAULT 'sample_ds';
DECLARE input_object_name STRING DEFAULT 'customer_purchase_history';
DECLARE input_column_name STRING DEFAULT 'unit_price';

-- 同一の影響先へ複数経路が存在する場合:
--   TRUE  : 最短Rankの経路だけを表示
--   FALSE : すべての経路を表示
DECLARE show_shortest_path_only BOOL DEFAULT TRUE;

WITH parameters AS (
  SELECT
    NULLIF(LOWER(TRIM(input_project)), '') AS project_name,
    NULLIF(LOWER(TRIM(input_dataset)), '') AS dataset_name,
    NULLIF(LOWER(TRIM(input_object_name)), '') AS object_name,
    NULLIF(LOWER(TRIM(input_column_name)), '') AS column_name
),
matched_impact AS (
  SELECT
    impact.snapshot_at,

    impact.origin_project,
    impact.origin_dataset,
    impact.origin_object,
    impact.origin_object_type,
    impact.origin_column,

    impact.impact_rank,

    impact.impacted_project,
    impact.impacted_dataset,
    impact.impacted_object,
    impact.impacted_object_type,
    impact.impacted_column,

    impact.direct_source_project,
    impact.direct_source_dataset,
    impact.direct_source_object,
    impact.direct_source_object_type,
    impact.direct_source_column,

    impact.dependency_path,
    ARRAY_TO_STRING(impact.dependency_path, ' -> ') AS dependency_path_text,
    impact.path_hash,
    impact.generation_type,
    impact.resolution_status,
    impact.is_cycle
  FROM `audeodb.lineage_repository.lineage_impact` AS impact
  CROSS JOIN parameters AS parameter
  WHERE parameter.object_name IS NOT NULL
    AND parameter.column_name IS NOT NULL
    AND (
      parameter.project_name IS NULL
      OR LOWER(impact.origin_project) = parameter.project_name
    )
    AND (
      parameter.dataset_name IS NULL
      OR LOWER(impact.origin_dataset) = parameter.dataset_name
    )
    AND LOWER(impact.origin_object) = parameter.object_name
    AND LOWER(impact.origin_column) = parameter.column_name
),
ranked_paths AS (
  SELECT
    matched_impact.*,
    ROW_NUMBER() OVER (
      PARTITION BY
        LOWER(matched_impact.impacted_project),
        LOWER(matched_impact.impacted_dataset),
        LOWER(matched_impact.impacted_object),
        LOWER(COALESCE(matched_impact.impacted_column, ''))
      ORDER BY
        matched_impact.impact_rank,
        ARRAY_LENGTH(matched_impact.dependency_path),
        matched_impact.path_hash
    ) AS shortest_path_number
  FROM matched_impact
)
SELECT
  impact_rank AS rank,

  origin_project AS changed_project,
  origin_dataset AS changed_dataset,
  origin_object AS changed_object,
  origin_object_type AS changed_object_type,
  origin_column AS changed_column,

  impacted_project,
  impacted_dataset,
  impacted_object,
  impacted_object_type,
  impacted_column,

  CONCAT(
    COALESCE(impacted_project, ''), '.',
    COALESCE(impacted_dataset, ''), '.',
    impacted_object, '.',
    COALESCE(impacted_column, '*')
  ) AS impacted_column_full_name,

  direct_source_project,
  direct_source_dataset,
  direct_source_object,
  direct_source_object_type,
  direct_source_column,

  dependency_path_text,
  generation_type,
  resolution_status,
  is_cycle,
  snapshot_at
FROM ranked_paths
WHERE show_shortest_path_only = FALSE
   OR shortest_path_number = 1
ORDER BY
  rank,
  impacted_project,
  impacted_dataset,
  impacted_object,
  impacted_column;
