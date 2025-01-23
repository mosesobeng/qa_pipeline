{{ config(
    materialized='incremental',
    unique_key='review_id',
    on_schema_change='sync_all_columns'
) }}

WITH base AS (
  SELECT
    review_id,
    payment_id,
    payment_token_id,
    created,
    conversation_created_at,
    conversation_created_date,
    conversation_external_id,
    team_id,
    reviewer_id,
    reviewee_id,
    comment_id,
    scorecard_id,
    scorecard_tag,
    score,
    CAST(updated_at AS TIMESTAMP) AS updated_at,
    updated_by,
    assignment_review,
    seen,
    disputed,
    review_time_seconds,
    assignment_name,
    imported_at
  FROM {{ ref('stg_manual_reviews') }}
),

filtered AS (
  SELECT *
  FROM base
  {% if is_incremental() %}
    WHERE updated_at > (
      SELECT IFNULL(MAX(updated_at), TIMESTAMP('1900-01-01'))
      FROM {{ this }}
    )
  {% endif %}
)

SELECT
  MD5(CAST(review_id AS STRING)) AS manual_review_key,
  review_id,
  dp.payment_key,
  payment_token_id,
  dt.team_key,
  du_reviewer.user_key AS reviewer_key,
  du_reviewee.user_key AS reviewee_key,

  SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', created) AS created_ts,
  SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', conversation_created_at) AS conversation_created_ts,
  SAFE.PARSE_DATE('%Y-%m-%d', conversation_created_date) AS conversation_created_dt,
  conversation_external_id,
  comment_id,
  scorecard_id,
  scorecard_tag,
  score,
  r.updated_at,
  updated_by,
  assignment_review,
  seen,
  disputed,
  review_time_seconds,
  assignment_name,
  imported_at,

  -- date keys if you like
  CAST(FORMAT_TIMESTAMP('%Y%m%d', SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', created)) AS INT) AS date_key_created,
  CAST(FORMAT_TIMESTAMP('%Y%m%d', r.updated_at) AS INT) AS date_key_updated,
  CAST(FORMAT_DATE('%Y%m%d', SAFE.PARSE_DATE('%Y-%m-%d', conversation_created_date)) AS INT) AS date_key_conversation

FROM filtered r
LEFT JOIN {{ ref('dim_payment') }} dp
  ON MD5(CAST(r.payment_id AS STRING)) = dp.payment_key
LEFT JOIN {{ ref('dim_team') }} dt
  ON MD5(CAST(r.team_id AS STRING)) = dt.team_key
LEFT JOIN {{ ref('dim_user') }} du_reviewer
  ON MD5(CAST(r.reviewer_id AS STRING)) = du_reviewer.user_key
LEFT JOIN {{ ref('dim_user') }} du_reviewee
  ON MD5(CAST(r.reviewee_id AS STRING)) = du_reviewee.user_key
