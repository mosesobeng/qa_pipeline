SELECT
    autoqa_review_id,
    autoqa_rating_id,
    payment_id,
    team_id,
    payment_token_id,
    external_ticket_id,
    rating_category_id,
    rating_category_name,
    rating_scale_score,
    score,
    reviewee_internal_id
FROM {{ source('zendesk_assessment', 'autoqa_ratings') }}
