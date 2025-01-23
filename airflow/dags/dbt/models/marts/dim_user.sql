{{ config(
    materialized='incremental',
    unique_key='user_id',
    on_schema_change='sync_all_columns'
) }}

WITH mr_reviewee AS (
  SELECT
    CAST(reviewee_id AS INT) AS user_id,
    CAST(updated_at AS TIMESTAMP) AS updated_at
  FROM {{ ref('stg_manual_reviews') }}
  WHERE reviewee_id IS NOT NULL
),

mr_reviewer AS (
  SELECT
    CAST(reviewer_id AS INT) AS user_id,
    CAST(updated_at AS TIMESTAMP) AS updated_at
  FROM {{ ref('stg_manual_reviews') }}
  WHERE reviewer_id IS NOT NULL
),

conv_assignee AS (
  SELECT
    assignee_id AS user_id,
    CAST(updated_at AS TIMESTAMP) AS updated_at
  FROM {{ ref('stg_conversations') }}
  WHERE assignee_id IS NOT NULL
),

aqa_reviews AS (
  SELECT
    CAST(reviewee_internal_id AS INT) AS user_id,
    CAST(updated_at AS TIMESTAMP) AS updated_at
  FROM {{ ref('stg_autoqa_reviews') }}
  WHERE reviewee_internal_id IS NOT NULL
),

-- stg_autoqa_ratings has no updated_at => sentinel
aqa_ratings AS (
  SELECT
    CAST(reviewee_internal_id AS INT) AS user_id,
    TIMESTAMP('1970-01-01') AS updated_at
  FROM {{ ref('stg_autoqa_ratings') }}
  WHERE reviewee_internal_id IS NOT NULL
),

union_users AS (
  SELECT * FROM mr_reviewee
  UNION ALL
  SELECT * FROM mr_reviewer
  UNION ALL
  SELECT * FROM conv_assignee
  UNION ALL
  SELECT * FROM aqa_reviews
  UNION ALL
  SELECT * FROM aqa_ratings
),

grouped AS (
  SELECT
    user_id,
    MAX(updated_at) AS updated_at
  FROM union_users
  WHERE user_id IS NOT NULL
  GROUP BY user_id
)

SELECT
  MD5(CAST(user_id AS STRING)) AS user_key,
  user_id,
  updated_at
FROM grouped
{% if is_incremental() %}
  WHERE updated_at > (
    SELECT IFNULL(MAX(updated_at), TIMESTAMP('1900-01-01'))
    FROM {{ this }}
  )
{% endif %}
