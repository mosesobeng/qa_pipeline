WITH raw_calc AS (
  SELECT
    review_id,
    SUM(
      CASE WHEN rating = 42 THEN 0
           ELSE (rating / rating_max)*weight
      END
    ) AS weighted_score_sum,
    SUM(
      CASE WHEN rating = 42 THEN 0 ELSE weight END
    ) AS weight_sum
  FROM `zendesk-assessment.raw.manual_rating`
  GROUP BY review_id
)
SELECT
  review_id,
  CASE WHEN weight_sum = 0 THEN 0
       ELSE 100*(weighted_score_sum / weight_sum)
  END AS final_score_percentage
FROM raw_calc
