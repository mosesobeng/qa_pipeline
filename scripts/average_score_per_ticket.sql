SELECT
  external_ticket_id,
  AVG(score) AS avg_score
FROM `zendesk-assessment.raw.autoqa_ratings`
GROUP BY external_ticket_id
