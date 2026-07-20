SET @@location = 'asia-northeast1';

-- ============================================================================
-- Direct dependency -> ranked impact paths
-- 初版は毎回全件再構築します。
-- ============================================================================

DECLARE snapshot_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
DECLARE max_rank INT64 DEFAULT 100;

CREATE OR REPLACE TABLE `audeodb.lineage_repository.lineage_impact`
PARTITION BY DATE(snapshot_at)
CLUSTER BY origin_project, origin_dataset, origin_object, origin_column
AS
WITH RECURSIVE impact_tree AS (
  -- Rank 1: direct dependency
  SELECT
    edge.source_project AS origin_project,
    edge.source_dataset AS origin_dataset,
    edge.source_object AS origin_object,
    edge.source_object_type AS origin_object_type,
    edge.source_column AS origin_column,

    1 AS impact_rank,

    edge.target_project AS impacted_project,
    edge.target_dataset AS impacted_dataset,
    edge.target_object AS impacted_object,
    edge.target_object_type AS impacted_object_type,
    edge.target_column AS impacted_column,

    edge.source_project AS direct_source_project,
    edge.source_dataset AS direct_source_dataset,
    edge.source_object AS direct_source_object,
    edge.source_object_type AS direct_source_object_type,
    edge.source_column AS direct_source_column,

    [
      CONCAT(
        COALESCE(edge.source_project, ''), '.',
        COALESCE(edge.source_dataset, ''), '.',
        edge.source_object, '.',
        COALESCE(edge.source_column, '*')
      ),
      CONCAT(
        COALESCE(edge.target_project, ''), '.',
        COALESCE(edge.target_dataset, ''), '.',
        edge.target_object, '.',
        COALESCE(edge.target_column, '*')
      )
    ] AS dependency_path,

    edge.generation_type,
    edge.resolution_status,
    FALSE AS is_cycle
  FROM `audeodb.lineage_repository.lineage_direct_dependency` AS edge
  WHERE edge.resolution_status IN ('RESOLVED', 'SOURCE_RESOLVED', 'PARTIALLY_RESOLVED')

  UNION ALL

  SELECT
    parent.origin_project,
    parent.origin_dataset,
    parent.origin_object,
    parent.origin_object_type,
    parent.origin_column,

    parent.impact_rank + 1,

    child.target_project,
    child.target_dataset,
    child.target_object,
    child.target_object_type,
    child.target_column,

    child.source_project,
    child.source_dataset,
    child.source_object,
    child.source_object_type,
    child.source_column,

    ARRAY_CONCAT(
      parent.dependency_path,
      [CONCAT(
        COALESCE(child.target_project, ''), '.',
        COALESCE(child.target_dataset, ''), '.',
        child.target_object, '.',
        COALESCE(child.target_column, '*')
      )]
    ),

    child.generation_type,
    child.resolution_status,

    CONCAT(
      COALESCE(child.target_project, ''), '.',
      COALESCE(child.target_dataset, ''), '.',
      child.target_object, '.',
      COALESCE(child.target_column, '*')
    ) IN UNNEST(parent.dependency_path) AS is_cycle
  FROM impact_tree AS parent
  JOIN `audeodb.lineage_repository.lineage_direct_dependency` AS child
    ON child.source_project = parent.impacted_project
   AND child.source_dataset = parent.impacted_dataset
   AND child.source_object = parent.impacted_object
   AND (
     child.source_column = parent.impacted_column
     OR child.source_column IS NULL
     OR parent.impacted_column IS NULL
   )
  WHERE parent.impact_rank < max_rank
    AND parent.is_cycle = FALSE
    AND child.resolution_status IN ('RESOLVED', 'SOURCE_RESOLVED', 'PARTIALLY_RESOLVED')
)
SELECT DISTINCT
  snapshot_time AS snapshot_at,
  origin_project,
  origin_dataset,
  origin_object,
  origin_object_type,
  origin_column,
  impact_rank,
  impacted_project,
  impacted_dataset,
  impacted_object,
  impacted_object_type,
  impacted_column,
  direct_source_project,
  direct_source_dataset,
  direct_source_object,
  direct_source_object_type,
  direct_source_column,
  dependency_path,
  TO_HEX(SHA256(ARRAY_TO_STRING(dependency_path, ' -> '))) AS path_hash,
  generation_type,
  resolution_status,
  is_cycle
FROM impact_tree;
