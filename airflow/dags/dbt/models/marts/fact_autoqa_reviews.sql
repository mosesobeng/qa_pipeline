{{ config(
    materialized='incremental',
    unique_key='autoqa_review_id',
    on_schema_change='sync_all_columns'
) }}

WITH base AS (
  SELECT
    autoqa_review_id,
    payment_id,
    payment_token_id,
    external_ticket_id,
    created_at,
    conversation_created_at,
    conversation_created_date,
    team_id,
    reviewee_internal_id,
    CAST(updated_at AS TIMESTAMP) AS updated_at
  FROM {{ ref('stg_autoqa_reviews') }}
),

filtered AS (
  SELECT
    autoqa_review_id,
    payment_id,
    payment_token_id,
    external_ticket_id,
    created_at,
    conversation_created_at,
    conversation_created_date,
    team_id,
    reviewee_internal_id,
    updated_at
  FROM base
  {% if is_incremental() %}
    WHERE updated_at > (
      SELECT IFNULL(MAX(updated_at), TIMESTAMP('1900-01-01'))
      FROM {{ this }}
    )
  {% endif %}
)

SELECT
  MD5(autoqa_review_id) AS autoqa_review_key,
  autoqa_review_id,
  dp.payment_key,
  payment_token_id,
  dt.team_key,
  du.user_key AS reviewee_key,
  external_ticket_id,

  -- parse times if needed
  SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', created_at) AS created_ts,
  SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', conversation_created_at) AS conversation_created_ts,
  SAFE.PARSE_DATE('%Y-%m-%d', conversation_created_date) AS conversation_created_dt,

  f.updated_at,

  -- date_keys if desired
  CAST(FORMAT_TIMESTAMP('%Y%m%d', SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', created_at)) AS INT) AS date_key_created,
  CAST(FORMAT_TIMESTAMP('%Y%m%d', f.updated_at) AS INT) AS date_key_updated,
  CAST(FORMAT_DATE('%Y%m%d', SAFE.PARSE_DATE('%Y-%m-%d', conversation_created_date)) AS INT) AS date_key_conversation

FROM filtered f
LEFT JOIN {{ ref('dim_payment') }} dp
  ON MD5(CAST(f.payment_id AS STRING)) = dp.payment_key
LEFT JOIN {{ ref('dim_team') }} dt
  ON MD5(CAST(f.team_id AS STRING)) = dt.team_key
LEFT JOIN {{ ref('dim_user') }} du
  ON MD5(CAST(f.reviewee_internal_id AS STRING)) = du.user_key
