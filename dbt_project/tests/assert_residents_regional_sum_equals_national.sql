-- The sum of regional residents must match the national total for every year.
-- A mismatch means a region is missing, duplicated or joined incorrectly in
-- rpt_region_year_metrics. Tolerance: 0.001% relative difference.

WITH national AS (
    SELECT 
        year
        ,SUM(residents) AS residents_national
    FROM {{ ref('rpt_region_year_metrics') }}
    WHERE is_national
    GROUP BY 
        year
)


,regional AS (
    SELECT 
        year
        ,SUM(residents) AS residents_regional
    FROM {{ ref('rpt_region_year_metrics') }}
    WHERE NOT is_national
    GROUP BY 
        year
)


SELECT 
    year
    ,residents_national
    ,residents_regional
    ,SAFE_DIVIDE(residents_national - residents_regional, residents_national) AS residence_diff
FROM national FULL OUTER JOIN regional USING(year)
WHERE SAFE_DIVIDE(residents_national - residents_regional, residents_national) >= 0.00001
