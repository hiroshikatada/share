SET @@location = 'asia-northeast1';

-- ============================================================================
-- VIEW definitions -> lineage_definition_registry
-- 対象データセットを増やす場合は source_views を UNION ALL で追加します。
-- ============================================================================

DECLARE sync_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP();

CREATE TEMP TABLE source_views AS
SELECT
  table_catalog AS object_project,
  table_schema AS object_dataset,
  table_name AS object_name,
  'VIEW' AS object_type,
  'VIEW_DEFINITION' AS generation_type,
  'INFORMATION_SCHEMA.VIEWS' AS definition_source,
  view_definition AS definition_text,
  TO_HEX(SHA256(COALESCE(view_definition, ''))) AS definition_hash,
  CAST(NULL AS STRING) AS source_job_id,
  CAST(NULL AS TIMESTAMP) AS source_job_time,
  CAST(NULL AS STRING) AS source_user_email
FROM `audeodb.sample_ds.INFORMATION_SCHEMA.VIEWS`;

MERGE `audeodb.lineage_repository.lineage_definition_registry` AS target
USING source_views AS source
ON target.object_project = source.object_project
AND target.object_dataset = source.object_dataset
AND target.object_name = source.object_name
AND target.object_type = source.object_type
AND target.generation_type = source.generation_type
WHEN MATCHED THEN
  UPDATE SET
    previous_definition_hash = IF(
      target.definition_hash != source.definition_hash,
      target.definition_hash,
      target.previous_definition_hash
    ),
    definition_text = source.definition_text,
    definition_hash = source.definition_hash,
    definition_source = source.definition_source,
    source_job_id = source.source_job_id,
    source_job_time = source.source_job_time,
    source_user_email = source.source_user_email,
    is_changed = (
      target.definition_hash != source.definition_hash
      OR target.last_analyzed_hash IS NULL
      OR target.last_analyzed_hash != source.definition_hash
    ),
    is_active = TRUE,
    last_seen_at = sync_timestamp,
    updated_at = sync_timestamp
WHEN NOT MATCHED THEN
  INSERT (
    object_project,
    object_dataset,
    object_name,
    object_type,
    generation_type,
    definition_source,
    definition_text,
    definition_hash,
    previous_definition_hash,
    source_job_id,
    source_job_time,
    source_user_email,
    is_changed,
    is_active,
    analysis_status,
    last_analyzed_hash,
    first_seen_at,
    last_seen_at,
    last_analyzed_at,
    updated_at
  )
  VALUES (
    source.object_project,
    source.object_dataset,
    source.object_name,
    source.object_type,
    source.generation_type,
    source.definition_source,
    source.definition_text,
    source.definition_hash,
    NULL,
    source.source_job_id,
    source.source_job_time,
    source.source_user_email,
    TRUE,
    TRUE,
    'PENDING',
    NULL,
    sync_timestamp,
    sync_timestamp,
    NULL,
    sync_timestamp
  );

-- 今回取得できなかったVIEWを非アクティブ化します。
UPDATE `audeodb.lineage_repository.lineage_definition_registry` AS registry
SET
  is_active = FALSE,
  updated_at = sync_timestamp
WHERE registry.generation_type = 'VIEW_DEFINITION'
  AND registry.object_dataset = 'sample_ds'
  AND NOT EXISTS (
    SELECT 1
    FROM source_views AS source
    WHERE source.object_project = registry.object_project
      AND source.object_dataset = registry.object_dataset
      AND source.object_name = registry.object_name
      AND source.object_type = registry.object_type
  );
