-- Medical assessment per health centre over the latest 12 months of the waiting-times exports, for
-- comparing centres within and between regions. Grain: one row per care unit with data in the
-- window. Shares are 0-1 and volume-weighted: summed counts first, then divided.
-- is_included marks the centres the comparisons use: health centres (dim_care_unit.unit_type)
-- with at least 250 assessments in the window, so one centre's share is precise to about
-- +/-2.5 share points.

WITH window_bounds AS (
    SELECT
        DATE_SUB(MAX(period_start), INTERVAL 11 MONTH) AS window_start
        ,MAX(period_start) AS window_end
    FROM {{ ref('fct_medical_assessment') }}
)

,unit_totals AS (
    SELECT
        fct.care_unit_id
        ,fct.region_id
        -- a suppressed month hides all three counts together; summing only complete months keeps
        -- numerators and denominators on the same months
        ,COUNTIF(fct.total_assessments IS NOT NULL) AS months_with_data
        ,SUM(IF(fct.assessed_within_3_days IS NOT NULL AND fct.assessed_same_day IS NOT NULL, fct.total_assessments, NULL)) AS total_assessments
        ,SUM(IF(fct.total_assessments IS NOT NULL AND fct.assessed_same_day IS NOT NULL, fct.assessed_within_3_days, NULL)) AS assessed_within_3_days
        ,SUM(IF(fct.total_assessments IS NOT NULL AND fct.assessed_within_3_days IS NOT NULL, fct.assessed_same_day, NULL)) AS assessed_same_day
    FROM {{ ref('fct_medical_assessment') }} fct
    CROSS JOIN window_bounds
    WHERE fct.aggregation_level = 'health_centre'
        AND fct.period_start BETWEEN window_bounds.window_start AND window_bounds.window_end
    GROUP BY 1, 2
)

,centres AS (
    SELECT
        unit_totals.*
        ,cu.care_unit_name
        ,cu.unit_type
        ,cu.unit_type = 'health_centre' AND COALESCE(unit_totals.total_assessments, 0) >= 250 AS is_included
        ,SAFE_DIVIDE(unit_totals.assessed_within_3_days, unit_totals.total_assessments) AS within_3_days_share
        ,SAFE_DIVIDE(unit_totals.assessed_same_day, unit_totals.total_assessments) AS same_day_share
    FROM unit_totals
    INNER JOIN {{ ref('dim_care_unit') }} cu USING (care_unit_id)
)

SELECT
    centres.care_unit_id
    ,centres.care_unit_name
    ,centres.unit_type
    ,centres.region_id
    ,reg.region_short_name
    ,window_bounds.window_start
    ,window_bounds.window_end
    ,CONCAT(FORMAT_DATE('%b %Y', window_bounds.window_start), ' – ', FORMAT_DATE('%b %Y', window_bounds.window_end)) AS window_label
    ,centres.months_with_data
    ,centres.total_assessments
    ,centres.assessed_within_3_days
    ,centres.assessed_same_day
    ,centres.within_3_days_share
    ,centres.same_day_share
    ,centres.is_included

    -- the included centres of the same region, and of all of Sweden, pooled the same way
    ,IF(centres.is_included, SAFE_DIVIDE(
        SUM(IF(centres.is_included, centres.assessed_within_3_days, 0)) OVER (PARTITION BY centres.region_id),
        SUM(IF(centres.is_included, centres.total_assessments, 0)) OVER (PARTITION BY centres.region_id)), NULL) AS region_within_3_days_share
    ,IF(centres.is_included, SAFE_DIVIDE(
        SUM(IF(centres.is_included, centres.assessed_within_3_days, 0)) OVER (),
        SUM(IF(centres.is_included, centres.total_assessments, 0)) OVER ()), NULL) AS national_within_3_days_share
FROM centres
CROSS JOIN window_bounds
LEFT JOIN {{ ref('dim_region') }} reg ON reg.region_id = centres.region_id
