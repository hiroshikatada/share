SET @@location = 'asia-northeast1';

-- ============================================================================
-- Scheduled Query CTAS -> lineage_definition_registry
-- 実行主体をサービスアカウントで限定します。
-- ============================================================================

DECLARE sync_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
DECLARE scheduled_query_user STRING DEFAULT 'audeodb@appspot.gserviceaccount.com';

CREATE TEMP TABLE latest_ctas_jobs AS
WITH candidate_jobs AS (
  SELECT
    job_id,
    user_email,
    creation_time,
    end_time,
    query,
    destination_table,
    statement_type,
    ROW_NUMBER() OVER (
      PARTITION BY
        destination_table.project_id,
        destination_table.dataset_id,
        destination_table.table_id
      ORDER BY end_time DESC
    ) AS row_number
  FROM `audeodb`.`region-asia-northeast1`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
  WHERE user_email = scheduled_query_user
    AND job_type = 'QUERY'
    AND state = 'DONE'
    AND error_result IS NULL
    AND query IS NOT NULL
    AND destination_table IS NOT NULL
    AND REGEXP_CONTAINS(
      UPPER(query),
      r'(?s)^\s*CREATE\s+(OR\s+REPLACE\s+)?TABLE\s+'
    )
    AND REGEXP_CONTAINS(UPPER(query), r'(?s)\s+AS\s+SELECT\s+')
)
SELECT
  destination_table.project_id AS object_project,
  destination_table.dataset_id AS object_dataset,
  destination_table.table_id AS object_name,
  'TABLE' AS object_type,
  'SCHEDULED_QUERY' AS generation_type,
  'INFORMATION_SCHEMA.JOBS' AS definition_source,
  query AS definition_text,
  TO_HEX(SHA256(query)) AS definition_hash,
  job_id AS source_job_id,
  end_time AS source_job_time,
  user_email AS source_user_email
FROM candidate_jobs
WHERE row_number = 1;

MERGE `audeodb.lineage_repository.lineage_definition_registry` AS target
USING latest_ctas_jobs AS source
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
