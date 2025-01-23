{{ config(
    materialized='incremental',
    unique_key='category_id',
    on_schema_change='sync_all_columns'
) }}

WITH aqa_cat AS (
  SELECT
    rating_category_id AS category_id,
    rating_category_name AS category_name
  FROM {{ ref('stg_autoqa_ratings') }}
  WHERE rating_category_id IS NOT NULL
),

mr_cat AS (
  SELECT
    category_id,
    category_name
  FROM {{ ref('stg_manual_rating') }}
  WHERE category_id IS NOT NULL
),

union_cats AS (
  SELECT * FROM aqa_cat
  UNION ALL
  SELECT * FROM mr_cat
),

dedup AS (
  SELECT
    category_id,
    ANY_VALUE(category_name) AS category_name
  FROM union_cats
  GROUP BY category_id
  HAVING category_id IS NOT NULL
),

filtered AS (
  SELECT
    category_id,
    category_name
  FROM dedup
  {% if is_incremental() %}
    WHERE category_id NOT IN (
      SELECT category_id FROM {{ this }}
    )
  {% endif %}
)

SELECT
  MD5(CAST(category_id AS STRING)) AS rating_category_key,
  category_id,
  category_name
FROM filtered
