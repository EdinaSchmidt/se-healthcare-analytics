SELECT 
    region_id
    ,year
    ,SUM(assessed_within_3_days) AS assessed_within_3_days
    ,SUM(total_assessments) AS total_assessments
    ,COUNTIF(total_assessments IS NOT NULL) AS months_reported
    ,COUNT(DISTINCT period_start) AS months_in_data
    ,COUNT(DISTINCT period_start) - COUNTIF(total_assessments IS NOT NULL) AS missing_months
FROM 
    {{ ref('stg_waiting_times__medical_assessment') }}
WHERE 
    health_center = 'Alla vårdcentraler'
GROUP BY ALL