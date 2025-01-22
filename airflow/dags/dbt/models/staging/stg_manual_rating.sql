SELECT
    payment_id,
    team_id,
    review_id,
    category_id,
    rating,
    cause,
    rating_max,
    weight,
    critical,
    category_name
FROM {{  source('zendesk_assessment', 'manual_rating') }}
