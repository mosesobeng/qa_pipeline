WITH dates AS (
  SELECT
      CAST(date_day AS DATE) AS calendar_date
  FROM UNNEST(
      GENERATE_DATE_ARRAY('2022-01-01','2030-12-31', INTERVAL 1 DAY)
  ) AS date_day
)

SELECT
    CAST(FORMAT_DATE('%Y%m%d', calendar_date) AS INT) AS date_key,
    calendar_date,
    EXTRACT(YEAR FROM calendar_date)               AS year,
    EXTRACT(MONTH FROM calendar_date)              AS month,
    EXTRACT(DAY FROM calendar_date)                AS day,
    EXTRACT(DAYOFWEEK FROM calendar_date)          AS day_of_week,
    CASE EXTRACT(DAYOFWEEK FROM calendar_date)
      WHEN 1 THEN 'Sunday'
      WHEN 2 THEN 'Monday'
      WHEN 3 THEN 'Tuesday'
      WHEN 4 THEN 'Wednesday'
      WHEN 5 THEN 'Thursday'
      WHEN 6 THEN 'Friday'
      WHEN 7 THEN 'Saturday'
    END                                            AS day_name,
    EXTRACT(QUARTER FROM calendar_date)            AS quarter
FROM dates
