{{ config(materialized='view') }}

SELECT
    autoqa_rating_id,
    category,
    count,
    root_cause
FROM {{  source('zendesk_assessment', 'autoqa_root_cause') }}
WHERE autoqa_rating_id IS NOT NULL
