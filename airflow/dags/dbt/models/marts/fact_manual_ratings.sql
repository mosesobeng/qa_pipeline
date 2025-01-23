{{ config(
    materialized='incremental',
    unique_key='manual_rating_key',
    on_schema_change='sync_all_columns'
) }}

WITH base AS (
  SELECT
    payment_id,
    team_id,
    review_id,
    category_id,
    rating,
    cause,
    rating_max,
    weight,
    critical,
    category_name
  FROM {{ ref('stg_manual_rating') }}
  
  {% if is_incremental() %}
    WHERE CONCAT(CAST(review_id AS STRING), '_', CAST(category_id AS STRING)) NOT IN (
      SELECT CONCAT(CAST(review_id AS STRING), '_', CAST(category_id AS STRING))
      FROM {{ this }}
    )
  {% endif %}
)

SELECT
  MD5(CONCAT(CAST(review_id AS STRING), '_', CAST(b.category_id AS STRING))) AS manual_rating_key,
  review_id,
  b.category_id,
  dp.payment_key,
  dt.team_key,
  dr.rating_category_key,
  rating,
  cause,
  rating_max,
  weight,
  critical,
  b.category_name
FROM base b
LEFT JOIN {{ ref('dim_payment') }} dp
  ON MD5(CAST(b.payment_id AS STRING)) = dp.payment_key
LEFT JOIN {{ ref('dim_team') }} dt
  ON MD5(CAST(b.team_id AS STRING)) = dt.team_key
LEFT JOIN {{ ref('dim_rating_category') }} dr
  ON MD5(CAST(b.category_id AS STRING)) = dr.rating_category_key
