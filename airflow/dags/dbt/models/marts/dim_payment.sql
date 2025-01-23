{{ config(
    materialized='incremental',
    unique_key='payment_id',
    on_schema_change='sync_all_columns'
) }}

WITH from_autoqa_reviews AS (
  SELECT
    payment_id,
    CAST(updated_at AS TIMESTAMP) AS updated_at
  FROM {{ ref('stg_autoqa_reviews') }}
  WHERE payment_id IS NOT NULL
),

from_manual_reviews AS (
  SELECT
    payment_id,
    CAST(updated_at AS TIMESTAMP) AS updated_at
  FROM {{ ref('stg_manual_reviews') }}
  WHERE payment_id IS NOT NULL
),

from_conversations AS (
  SELECT
    payment_id,
    CAST(updated_at AS TIMESTAMP) AS updated_at
  FROM {{ ref('stg_conversations') }}
  WHERE payment_id IS NOT NULL
),

-- stg_manual_rating has no updated_at => sentinel
from_manual_rating AS (
  SELECT
    payment_id,
    TIMESTAMP('1970-01-01') AS updated_at
  FROM {{ ref('stg_manual_rating') }}
  WHERE payment_id IS NOT NULL
),

-- stg_autoqa_ratings has no updated_at => sentinel
from_autoqa_ratings AS (
  SELECT
    payment_id,
    TIMESTAMP('1970-01-01') AS updated_at
  FROM {{ ref('stg_autoqa_ratings') }}
  WHERE payment_id IS NOT NULL
),

union_payments AS (
  SELECT * FROM from_autoqa_reviews
  UNION ALL
  SELECT * FROM from_manual_reviews
  UNION ALL
  SELECT * FROM from_conversations
  UNION ALL
  SELECT * FROM from_manual_rating
  UNION ALL
  SELECT * FROM from_autoqa_ratings
),

grouped AS (
  SELECT
    payment_id,
    MAX(updated_at) AS updated_at
  FROM union_payments
  GROUP BY payment_id
  HAVING payment_id IS NOT NULL
)

SELECT
  MD5(CAST(payment_id AS STRING)) AS payment_key,
  payment_id,
  updated_at
FROM grouped
{% if is_incremental() %}
  WHERE updated_at > (
    SELECT IFNULL(MAX(updated_at), TIMESTAMP('1900-01-01'))
    FROM {{ this }}
  )
{% endif %}
