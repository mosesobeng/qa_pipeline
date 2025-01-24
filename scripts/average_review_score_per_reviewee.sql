SELECT
  reviewee_id,
  COUNT(*) AS total_reviews,
  AVG(score) AS avg_score
FROM `zendesk-assessment.raw.manual_reviews`
GROUP BY reviewee_id
HAVING COUNT(*) >= 2
