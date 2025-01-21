{{ config(materialized='view') }}

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
FROM {{ source('zendesk_assessment', 'autoqa_reviews') }}
