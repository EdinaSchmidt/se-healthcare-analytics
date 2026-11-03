SELECT 
    region_id
    ,period_start
    ,year
    ,answered_calls
    ,total_calls
FROM 
    {{ ref('stg_waiting_times__first_contact') }}
WHERE
    type = 'all_calls' 
    AND health_center = 'Alla vårdcentraler'