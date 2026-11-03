WITH national AS (
    SELECT 
        period_start
        ,SUM(answered_calls) AS answered_calls_national
        ,SUM(total_calls) AS total_calls_national
    FROM {{ ref('stg_waiting_times__first_contact') }}
    WHERE 
        region_id = '0000'
        AND (type = 'all_calls' OR type IS NULL)
        AND (health_center = 'Alla vårdcentraler' OR health_center IS NULL)
    GROUP BY 
        period_start
)


,regional AS (
    SELECT 
        period_start
        ,SUM(answered_calls) AS answered_calls_regional
        ,SUM(total_calls) AS total_calls_regional
    FROM {{ ref('stg_waiting_times__first_contact') }}
    WHERE NOT 
        region_id = '0000'
        AND (type = 'all_calls' OR type IS NULL)
        AND (health_center = 'Alla vårdcentraler' OR health_center IS NULL)
    GROUP BY 
        period_start
)


SELECT 
    period_start
    ,answered_calls_national
    ,answered_calls_regional
    ,SAFE_DIVIDE(answered_calls_national - answered_calls_regional, answered_calls_national) AS answered_calls_diff

    ,total_calls_national
    ,total_calls_regional
    ,SAFE_DIVIDE(total_calls_national - total_calls_regional, total_calls_national) AS total_calls_diff
FROM national FULL OUTER JOIN regional USING(period_start)
WHERE 
    SAFE_DIVIDE(answered_calls_national - answered_calls_regional, answered_calls_national) >= 0.00001 OR 
    SAFE_DIVIDE(total_calls_national - total_calls_regional, total_calls_national) >= 0.00001
