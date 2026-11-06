SELECT 
    region_id
    ,year
    ,SUM(answered_calls) AS answered_calls
    ,SUM(total_calls) AS total_calls
    ,COUNTIF(total_calls IS NOT NULL) AS months_reported
    ,COUNT(DISTINCT period_start) AS months_in_data
    ,COUNT(DISTINCT period_start) - COUNTIF(total_calls IS NOT NULL) AS missing_months
FROM 
    {{ ref('stg_waiting_times__first_contact') }}
WHERE
    type = 'all_calls' 
    AND health_center = 'Alla vårdcentraler'
GROUP BY ALL