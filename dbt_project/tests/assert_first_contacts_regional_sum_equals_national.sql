-- Socialstyrelsen's national row ('Alla regioner') must equal the sum of the
-- regional rows for every month, for answered and total calls (all contact
-- types, centre aggregate rows only). A mismatch means a region is missing
-- (e.g. a spelling not in the regions seed), duplicated, or double-counted
-- across contact types or centres. A month missing on either side also fails.
-- Checks the raw data, so all regions count, including those changing journal
-- systems; the reporting benchmark (regions not changing journal systems) is
-- not tested here. Tolerance: 0.001% relative difference.


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
WHERE ABS(SAFE_DIVIDE(answered_calls_national - answered_calls_regional, answered_calls_national)) >= 0.00001
    OR ABS(SAFE_DIVIDE(total_calls_national - total_calls_regional, total_calls_national)) >= 0.00001
    OR answered_calls_national IS NULL
    OR answered_calls_regional IS NULL
