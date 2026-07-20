SET @@location = 'asia-northeast1';

-- ============================================================================
-- BDE Definition Registry / Impact Repository
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS `audeodb.lineage_repository`;

CREATE TABLE IF NOT EXISTS `audeodb.lineage_repository.lineage_definition_registry`
(
  object_project STRING NOT NULL,
  object_dataset STRING NOT NULL,
  object_name STRING NOT NULL,
  object_type STRING NOT NULL,              -- VIEW / TABLE
  generation_type STRING NOT NULL,          -- VIEW_DEFINITION / SCHEDULED_QUERY
  definition_source STRING NOT NULL,        -- INFORMATION_SCHEMA.VIEWS / INFORMATION_SCHEMA.JOBS
  definition_text STRING,
  definition_hash STRING NOT NULL,
  previous_definition_hash STRING,
  source_job_id STRING,
  source_job_time TIMESTAMP,
  source_user_email STRING,
  is_changed BOOL NOT NULL,
  is_active BOOL NOT NULL,
  analysis_status STRING,
  last_analyzed_hash STRING,
  first_seen_at TIMESTAMP NOT NULL,
  last_seen_at TIMESTAMP NOT NULL,
  last_analyzed_at TIMESTAMP,
  updated_at TIMESTAMP NOT NULL
)
CLUSTER BY object_project, object_dataset, object_name;

CREATE TABLE IF NOT EXISTS `audeodb.lineage_repository.lineage_direct_dependency`
(
  definition_hash STRING NOT NULL,

  source_project STRING,
  source_dataset STRING,
  source_object STRING NOT NULL,
  source_object_type STRING NOT NULL,        -- TABLE / VIEW
  source_column STRING,

  target_project STRING NOT NULL,
  target_dataset STRING NOT NULL,
  target_object STRING NOT NULL,
  target_object_type STRING NOT NULL,        -- VIEW / TABLE
  target_column STRING,

  generation_type STRING NOT NULL,
  dependency_type STRING NOT NULL,           -- COLUMN / OBJECT
  expression STRING,
  usage_type STRING,
  resolution_status STRING,
  resolution_reason STRING,

  edge_key STRING NOT NULL,
  analyzed_at TIMESTAMP NOT NULL
)
CLUSTER BY source_project, source_dataset, source_object, source_column;

CREATE TABLE IF NOT EXISTS `audeodb.lineage_repository.lineage_impact`
(
  snapshot_at TIMESTAMP NOT NULL,

  origin_project STRING,
  origin_dataset STRING,
  origin_object STRING NOT NULL,
  origin_object_type STRING NOT NULL,
  origin_column STRING,

  impact_rank INT64 NOT NULL,

  impacted_project STRING,
  impacted_dataset STRING,
  impacted_object STRING NOT NULL,
  impacted_object_type STRING NOT NULL,
  impacted_column STRING,

  direct_source_project STRING,
  direct_source_dataset STRING,
  direct_source_object STRING NOT NULL,
  direct_source_object_type STRING NOT NULL,
  direct_source_column STRING,

  dependency_path ARRAY<STRING>,
  path_hash STRING NOT NULL,
  generation_type STRING,
  resolution_status STRING,
  is_cycle BOOL NOT NULL
)
PARTITION BY DATE(snapshot_at)
CLUSTER BY origin_project, origin_dataset, origin_object, origin_column;

CREATE TABLE IF NOT EXISTS `audeodb.lineage_repository.lineage_diagnostic`
(
  definition_hash STRING NOT NULL,
  object_project STRING NOT NULL,
  object_dataset STRING NOT NULL,
  object_name STRING NOT NULL,
  object_type STRING NOT NULL,
  diagnostic_code STRING NOT NULL,
  engine_stage STRING,
  severity STRING NOT NULL,
  output_column STRING,
  expression STRING,
  message STRING,
  diagnostic_json JSON,
  analyzed_at TIMESTAMP NOT NULL
)
CLUSTER BY object_project, object_dataset, object_name, diagnostic_code;
