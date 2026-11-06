WITH monthly AS (
    SELECT
        region_id
        ,period_start
        ,SUM(assessed_within_3_days) / SUM(total_assessments) AS share
    FROM {{ ref('stg_waiting_times__medical_assessment') }}
    WHERE health_center = 'Alla vårdcentraler'
    GROUP BY region_id, period_start
)
SELECT
    m.region_id
    ,m.period_start
    ,m.share - s.share AS diff_from_national
FROM monthly AS m
LEFT JOIN monthly AS s
    ON s.period_start = m.period_start
    AND s.region_id = '0000'
WHERE m.region_id IN ('0004','0013','0018','0020','0021','0022','0023','0024','0025')
ORDER BY m.region_id, m.period_start