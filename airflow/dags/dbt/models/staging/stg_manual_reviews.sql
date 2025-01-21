{{ config(materialized='view') }}

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
    updated_at,
    updated_by,
    assignment_review,
    seen,
    disputed,
    review_time_seconds,
    assignment_name,
    imported_at
FROM {{ source('zendesk_assessment', 'manual_reviews') }}
