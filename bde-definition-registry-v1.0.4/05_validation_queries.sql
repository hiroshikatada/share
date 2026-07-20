SET @@location = 'asia-northeast1';

-- ============================================================================
-- Validation queries
-- ============================================================================

DECLARE search_project STRING DEFAULT 'audeodb';
DECLARE search_dataset STRING DEFAULT 'sample_ds';
DECLARE search_table STRING DEFAULT 'customer_purchase_history';
DECLARE search_column STRING DEFAULT 'unit_price';

-- 1. Definition Registry chain
SELECT
  object_type,
  generation_type,
  object_project,
  object_dataset,
  object_name,
  definition_hash,
  is_changed,
  analysis_status,
  source_user_email,
  source_job_time
FROM `audeodb.lineage_repository.lineage_definition_registry`
WHERE object_dataset = 'sample_ds'
  AND object_name IN (
    'v_ec_complex_union',
    't_ec_complex_union',
    'v_ec_complex_union_2',
    'v_ec_complex_union_3'
  )
ORDER BY object_name;

-- 2. Scheduled Query job confirmation
SELECT
  job_id,
  user_email,
  end_time,
  destination_table,
  query
FROM `audeodb`.`region-asia-northeast1`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE user_email = 'audeodb@appspot.gserviceaccount.com'
  AND destination_table.table_id = 't_ec_complex_union'
  AND state = 'DONE'
  AND error_result IS NULL
ORDER BY end_time DESC
LIMIT 10;

-- 3. Expected path for txn_total
SELECT
  impact_rank,
  CONCAT(
    impacted_project, '.',
    impacted_dataset, '.',
    impacted_object, '.',
    COALESCE(impacted_column, '*')
  ) AS impacted_node,
  dependency_path,
  generation_type,
  resolution_status
FROM `audeodb.lineage_repository.lineage_impact`
WHERE origin_project = 'audeodb'
  AND origin_dataset = 'sample_ds'
  AND origin_object = 'customer_purchase_history'
  AND origin_column IN ('unit_price', 'quantity', 'discount_rate')
  AND impacted_object IN (
    'v_ec_complex_union',
    't_ec_complex_union',
    'v_ec_complex_union_2',
    'v_ec_complex_union_3'
  )
ORDER BY origin_column, impact_rank, impacted_node;

-- 4. Looker Studio equivalent search example
SELECT
  impact_rank,
  impacted_project,
  impacted_dataset,
  impacted_object,
  impacted_object_type,
  impacted_column,
  dependency_path,
  resolution_status
FROM `audeodb.lineage_repository.lineage_impact`
WHERE origin_project = search_project
  AND origin_dataset = search_dataset
  AND origin_object = search_table
  AND origin_column = search_column
ORDER BY impact_rank, impacted_object, impacted_column;
