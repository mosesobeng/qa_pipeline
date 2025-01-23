{{ config(
    materialized='incremental',
    unique_key='autoqa_root_cause_key',
    on_schema_change='sync_all_columns'
) }}

WITH base AS (
  SELECT
    autoqa_rating_id,
    category,
    count,
    root_cause
  FROM {{ ref('stg_autoqa_root_cause') }}
  WHERE autoqa_rating_id IS NOT NULL

  {% if is_incremental() %}
    AND CONCAT(autoqa_rating_id, COALESCE(root_cause, '')) NOT IN (
      SELECT CONCAT(autoqa_rating_id, COALESCE(root_cause, '')) FROM {{ this }}
    )
  {% endif %}
)

SELECT
  MD5(CONCAT(autoqa_rating_id, COALESCE(root_cause, ''))) AS autoqa_root_cause_key,
  autoqa_rating_id,
  MD5(autoqa_rating_id) AS autoqa_rating_key, 
  category,
  count AS root_cause_count,
  root_cause
FROM base
