{{ config(
    materialized='incremental',
    unique_key='autoqa_rating_id',
    on_schema_change='sync_all_columns'
) }}

WITH base AS (
  SELECT
    autoqa_rating_id,
    autoqa_review_id,
    payment_id,
    team_id,
    payment_token_id,
    external_ticket_id,
    rating_category_id,
    rating_category_name,
    rating_scale_score,
    score,
    reviewee_internal_id
  FROM {{ ref('stg_autoqa_ratings') }}

  {% if is_incremental() %}
    WHERE autoqa_rating_id NOT IN (
      SELECT autoqa_rating_id FROM {{ this }}
    )
  {% endif %}
)

SELECT
  MD5(autoqa_rating_id) AS autoqa_rating_key,
  autoqa_rating_id,
  MD5(autoqa_review_id) AS autoqa_review_key,
  dp.payment_key,
  dt.team_key,
  du.user_key AS reviewee_key,
  dr.rating_category_key,

  external_ticket_id,
  payment_token_id,
  rating_scale_score,
  score

FROM base b
LEFT JOIN {{ ref('dim_payment') }} dp
  ON MD5(CAST(b.payment_id AS STRING)) = dp.payment_key
LEFT JOIN {{ ref('dim_team') }} dt
  ON MD5(CAST(b.team_id AS STRING)) = dt.team_key
LEFT JOIN {{ ref('dim_user') }} du
  ON MD5(CAST(b.reviewee_internal_id AS STRING)) = du.user_key
LEFT JOIN {{ ref('dim_rating_category') }} dr
  ON MD5(CAST(b.rating_category_id AS STRING)) = dr.rating_category_key
