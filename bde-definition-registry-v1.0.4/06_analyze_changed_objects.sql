SET @@location = 'asia-northeast1';

-- ============================================================================
-- Changed definitions -> persistent lineage UDF -> direct dependency repository
--
-- Prerequisites:
--   1. 01_create_repository_tables.sql
--   2. 02_sync_view_registry.sql
--   3. 03_sync_scheduled_ctas_registry.sql
--   4. audeodb.sample_ds.analyze_lineage_json persistent UDF
--
-- Current metadata scope:
--   Physical column metadata is loaded from audeodb.sample_ds.
--   Add other datasets to physical_columns_source when analysis coverage expands.
-- ============================================================================

DECLARE run_started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
DECLARE strict_mode BOOL DEFAULT FALSE;
DECLARE physical_columns_json STRING;
DECLARE analyzed_object_count INT64 DEFAULT 0;
DECLARE failed_object_count INT64 DEFAULT 0;

-- --------------------------------------------------------------------------
-- Build physical-column metadata passed to the JavaScript lineage engine.
-- The engine expects uppercase fully qualified table names and column names.
-- --------------------------------------------------------------------------
SET physical_columns_json = (
  WITH physical_columns_source AS (
    SELECT
      table_catalog AS table_project,
      table_schema AS table_dataset,
      table_name,
      column_name,
      column_name AS field_path,
      ordinal_position
    FROM `audeodb.sample_ds.INFORMATION_SCHEMA.COLUMNS`
  )
  SELECT COALESCE(
    TO_JSON_STRING(
      ARRAY_AGG(
        STRUCT(
          UPPER(FORMAT(
            '%s.%s.%s',
            table_project,
            table_dataset,
            table_name
          )) AS table_name,
          UPPER(column_name) AS column_name,
          UPPER(COALESCE(field_path, column_name)) AS field_path
        )
        ORDER BY
          table_project,
          table_dataset,
          table_name,
          ordinal_position,
          field_path
      )
    ),
    '[]'
  )
  FROM physical_columns_source
);

-- --------------------------------------------------------------------------
-- Analyze only active definitions whose current hash has not been published.
-- Each object is isolated in a BEGIN...EXCEPTION block so one failure does not
-- prevent the remaining changed objects from being analyzed.
-- --------------------------------------------------------------------------
FOR target IN (
  SELECT
    object_project,
    object_dataset,
    object_name,
    object_type,
    generation_type,
    definition_text,
    definition_hash
  FROM `audeodb.lineage_repository.lineage_definition_registry`
  WHERE is_active = TRUE
    AND is_changed = TRUE
    AND definition_text IS NOT NULL
  ORDER BY
    object_project,
    object_dataset,
    object_name,
    generation_type
)
DO
  BEGIN
    DECLARE analysis_id STRING DEFAULT GENERATE_UUID();
    DECLARE analyzed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    DECLARE exported_json STRING;
    DECLARE udf_analysis_status STRING;

    -- analysis_id, object identity, and analyzed_at are required by
    -- BigQueryExporter and are embedded in every exported row.
    SET exported_json = `audeodb.sample_ds.analyze_lineage_json`(
      target.definition_text,
      physical_columns_json,
      TO_JSON_STRING(STRUCT(
        strict_mode AS strict_mode,
        TRUE AS compact_export
      )),
      TO_JSON_STRING(STRUCT(
        analysis_id AS analysis_id,
        target.object_project AS view_project,
        target.object_dataset AS view_dataset,
        target.object_name AS view_name,
        FORMAT_TIMESTAMP(
          '%FT%H:%M:%E*S%Ez',
          analyzed_at
        ) AS analyzed_at
      ))
    );

    SET udf_analysis_status = COALESCE(
      JSON_VALUE(exported_json, '$.analysis.analysis_status'),
      'UNKNOWN'
    );

    -- Replace only the edges produced by the current target definition.
    DELETE FROM `audeodb.lineage_repository.lineage_direct_dependency`
    WHERE target_project = target.object_project
      AND target_dataset = target.object_dataset
      AND target_object = target.object_name
      AND target_object_type = target.object_type
      AND generation_type = target.generation_type;

    INSERT INTO `audeodb.lineage_repository.lineage_direct_dependency` (
      definition_hash,
      source_project,
      source_dataset,
      source_object,
      source_object_type,
      source_column,
      target_project,
      target_dataset,
      target_object,
      target_object_type,
      target_column,
      generation_type,
      dependency_type,
      expression,
      usage_type,
      resolution_status,
      resolution_reason,
      edge_key,
      analyzed_at
    )
    WITH lineage_path_rows AS (
      SELECT
        SAFE_CAST(JSON_VALUE(path_row, '$.output_column_id') AS INT64)
          AS output_column_id,
        SAFE_CAST(JSON_VALUE(path_row, '$.output_scope_id') AS INT64)
          AS output_scope_id,
        JSON_VALUE(path_row, '$.output_column_name') AS output_column_name,
        JSON_VALUE(path_row, '$.physical_table_name') AS physical_table_name,
        JSON_VALUE(path_row, '$.physical_column_name') AS physical_column_name,
        JSON_VALUE(path_row, '$.field_path') AS field_path,
        JSON_VALUE_ARRAY(path_row, '$.lineage_path') AS lineage_path
      FROM UNNEST(
        JSON_QUERY_ARRAY(exported_json, '$.exported_tables.lineage_paths')
      ) AS path_row
    ),
    output_lineage_rows AS (
      SELECT
        SAFE_CAST(JSON_VALUE(output_row, '$.output_column_id') AS INT64)
          AS output_column_id,
        SAFE_CAST(JSON_VALUE(output_row, '$.output_scope_id') AS INT64)
          AS output_scope_id,
        JSON_VALUE(output_row, '$.expression_text') AS expression_text,
        JSON_VALUE(output_row, '$.lineage_status') AS lineage_status
      FROM UNNEST(
        JSON_QUERY_ARRAY(exported_json, '$.exported_tables.output_lineages')
      ) AS output_row
    ),
    normalized_edges AS (
      SELECT
        target.definition_hash AS definition_hash,

        CASE ARRAY_LENGTH(SPLIT(path.physical_table_name, '.'))
          WHEN 3 THEN SPLIT(path.physical_table_name, '.')[SAFE_OFFSET(0)]
          ELSE UPPER(target.object_project)
        END AS source_project,

        CASE ARRAY_LENGTH(SPLIT(path.physical_table_name, '.'))
          WHEN 3 THEN SPLIT(path.physical_table_name, '.')[SAFE_OFFSET(1)]
          WHEN 2 THEN SPLIT(path.physical_table_name, '.')[SAFE_OFFSET(0)]
          ELSE UPPER(target.object_dataset)
        END AS source_dataset,

        CASE ARRAY_LENGTH(SPLIT(path.physical_table_name, '.'))
          WHEN 3 THEN SPLIT(path.physical_table_name, '.')[SAFE_OFFSET(2)]
          WHEN 2 THEN SPLIT(path.physical_table_name, '.')[SAFE_OFFSET(1)]
          ELSE SPLIT(path.physical_table_name, '.')[SAFE_OFFSET(0)]
        END AS source_object,

        'TABLE' AS source_object_type,
        COALESCE(path.field_path, path.physical_column_name) AS source_column,

        target.object_project AS target_project,
        target.object_dataset AS target_dataset,
        target.object_name AS target_object,
        target.object_type AS target_object_type,
        path.output_column_name AS target_column,

        target.generation_type AS generation_type,
        'COLUMN' AS dependency_type,
        output.expression_text AS expression,
        'SELECT' AS usage_type,
        COALESCE(output.lineage_status, 'RESOLVED') AS resolution_status,
        CAST(NULL AS STRING) AS resolution_reason,
        analyzed_at AS analyzed_at
      FROM lineage_path_rows AS path
      LEFT JOIN output_lineage_rows AS output
        ON output.output_column_id = path.output_column_id
       AND output.output_scope_id = path.output_scope_id
      WHERE path.physical_table_name IS NOT NULL
        AND path.output_column_name IS NOT NULL
    )
    SELECT DISTINCT
      definition_hash,
      source_project,
      source_dataset,
      source_object,
      source_object_type,
      source_column,
      target_project,
      target_dataset,
      target_object,
      target_object_type,
      target_column,
      generation_type,
      dependency_type,
      expression,
      usage_type,
      resolution_status,
      resolution_reason,
      TO_HEX(SHA256(CONCAT(
        COALESCE(source_project, ''), '|',
        COALESCE(source_dataset, ''), '|',
        COALESCE(source_object, ''), '|',
        COALESCE(source_column, '*'), '|',
        COALESCE(target_project, ''), '|',
        COALESCE(target_dataset, ''), '|',
        COALESCE(target_object, ''), '|',
        COALESCE(target_column, '*'), '|',
        generation_type
      ))) AS edge_key,
      analyzed_at
    FROM normalized_edges;

    -- Replace diagnostics for the current definition hash.
    DELETE FROM `audeodb.lineage_repository.lineage_diagnostic`
    WHERE object_project = target.object_project
      AND object_dataset = target.object_dataset
      AND object_name = target.object_name
      AND object_type = target.object_type;

    INSERT INTO `audeodb.lineage_repository.lineage_diagnostic` (
      definition_hash,
      object_project,
      object_dataset,
      object_name,
      object_type,
      diagnostic_code,
      engine_stage,
      severity,
      output_column,
      expression,
      message,
      diagnostic_json,
      analyzed_at
    )
    SELECT
      target.definition_hash,
      target.object_project,
      target.object_dataset,
      target.object_name,
      target.object_type,
      COALESCE(JSON_VALUE(diagnostic_row, '$.code'), 'UNKNOWN'),
      JSON_VALUE(diagnostic_row, '$.stage'),
      COALESCE(JSON_VALUE(diagnostic_row, '$.severity'), 'INFO'),
      CAST(NULL AS STRING),
      CAST(NULL AS STRING),
      JSON_VALUE(diagnostic_row, '$.message'),
      SAFE.PARSE_JSON(JSON_VALUE(diagnostic_row, '$.diagnostic_json')),
      analyzed_at
    FROM UNNEST(
      JSON_QUERY_ARRAY(exported_json, '$.exported_tables.diagnostics')
    ) AS diagnostic_row;

    UPDATE `audeodb.lineage_repository.lineage_definition_registry`
    SET
      is_changed = FALSE,
      analysis_status = udf_analysis_status,
      last_analyzed_hash = definition_hash,
      last_analyzed_at = analyzed_at,
      updated_at = analyzed_at
    WHERE object_project = target.object_project
      AND object_dataset = target.object_dataset
      AND object_name = target.object_name
      AND object_type = target.object_type
      AND generation_type = target.generation_type
      AND definition_hash = target.definition_hash;

    SET analyzed_object_count = analyzed_object_count + 1;

  EXCEPTION WHEN ERROR THEN
    UPDATE `audeodb.lineage_repository.lineage_definition_registry`
    SET
      is_changed = TRUE,
      analysis_status = 'FAILED',
      updated_at = CURRENT_TIMESTAMP()
    WHERE object_project = target.object_project
      AND object_dataset = target.object_dataset
      AND object_name = target.object_name
      AND object_type = target.object_type
      AND generation_type = target.generation_type
      AND definition_hash = target.definition_hash;

    INSERT INTO `audeodb.lineage_repository.lineage_diagnostic` (
      definition_hash,
      object_project,
      object_dataset,
      object_name,
      object_type,
      diagnostic_code,
      engine_stage,
      severity,
      output_column,
      expression,
      message,
      diagnostic_json,
      analyzed_at
    )
    VALUES (
      target.definition_hash,
      target.object_project,
      target.object_dataset,
      target.object_name,
      target.object_type,
      'ANALYSIS_EXECUTION_FAILED',
      '06_analyze_changed_objects',
      'ERROR',
      NULL,
      NULL,
      @@error.message,
      JSON_OBJECT(
        'statement_text', @@error.statement_text,
        'formatted_stack_trace', @@error.formatted_stack_trace
      ),
      CURRENT_TIMESTAMP()
    );

    SET failed_object_count = failed_object_count + 1;
  END;
END FOR;

-- --------------------------------------------------------------------------
-- Run summary.
-- 04_rebuild_impact_table.sql should be executed after successful analysis.
-- --------------------------------------------------------------------------
SELECT
  run_started_at,
  CURRENT_TIMESTAMP() AS run_finished_at,
  analyzed_object_count,
  failed_object_count,
  (
    SELECT COUNT(*)
    FROM `audeodb.lineage_repository.lineage_definition_registry`
    WHERE is_active = TRUE
      AND is_changed = TRUE
  ) AS remaining_changed_object_count,
  (
    SELECT COUNT(*)
    FROM `audeodb.lineage_repository.lineage_direct_dependency`
  ) AS direct_dependency_count,
  (
    SELECT COUNT(*)
    FROM `audeodb.lineage_repository.lineage_diagnostic`
    WHERE severity = 'ERROR'
  ) AS error_diagnostic_count;
