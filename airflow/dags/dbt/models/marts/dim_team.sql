{{ config(
    materialized='incremental',
    unique_key='team_id',
    on_schema_change='sync_all_columns'
) }}

WITH from_autoqa_reviews AS (
  SELECT
    team_id,
    CAST(updated_at AS TIMESTAMP) AS updated_at
  FROM {{ ref('stg_autoqa_reviews') }}
  WHERE team_id IS NOT NULL
),

from_manual_reviews AS (
  SELECT
    team_id,
    CAST(updated_at AS TIMESTAMP) AS updated_at
  FROM {{ ref('stg_manual_reviews') }}
  WHERE team_id IS NOT NULL
),

-- stg_manual_rating has team_id but NO updated_at => use a sentinel
from_manual_rating AS (
  SELECT
    team_id,
    TIMESTAMP('1970-01-01') AS updated_at
  FROM {{ ref('stg_manual_rating') }}
  WHERE team_id IS NOT NULL
),

union_teams AS (
  SELECT * FROM from_autoqa_reviews
  UNION ALL
  SELECT * FROM from_manual_reviews
  UNION ALL
  SELECT * FROM from_manual_rating
),

-- Aggregate to get the row with the max updated_at per team_id
grouped AS (
  SELECT
    team_id,
    MAX(updated_at) AS updated_at
  FROM union_teams
  GROUP BY team_id
  HAVING team_id IS NOT NULL
)

SELECT
  MD5(CAST(team_id AS STRING)) AS team_key,
  team_id,
  updated_at
FROM grouped
{% if is_incremental() %}
  WHERE updated_at > (
    SELECT IFNULL(MAX(updated_at), TIMESTAMP('1900-01-01')) 
    FROM {{ this }}
  )
{% endif %}
