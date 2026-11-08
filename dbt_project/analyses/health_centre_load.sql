-- Analysis: how many residents (and residents aged 65+) a health centre serves on
-- average per region, now and in the projection's target year if the number of centres
-- stays the same.
--
-- Health centres = distinct HSA-IDs at centre level in the NPE patient survey (health centres
-- with doctor visits). Sörmland has no NPE results, so it has no count; the waiting-times
-- count is shown for reference only (it also lists other units, so it runs higher).
-- Assumes every resident is listed and spread evenly over the region's centres: an order of
-- magnitude, not a listing figure.
--
-- Run: dbt show --select health_centre_load --limit 30

WITH metrics AS (
    SELECT
        region_id
        ,region_short_name
        ,year
        ,residents
        ,residents_projected_5y
        ,residents_65_plus
        ,residents_65_plus_projected_5y
        ,residents_projection_target_year
    FROM {{ ref('rpt_region_year_metrics') }}
    WHERE year = (SELECT MAX(year) FROM {{ ref('rpt_region_expansion_shortlist') }})
        AND NOT is_national
)

,centres_npe AS (
    SELECT
        region_id
        ,year
        ,COUNT(DISTINCT health_center_id) AS health_centres
    FROM {{ ref('stg_patient_surveys__dimensions') }}
    WHERE aggregation_level = 'health_center'
        AND region_id != '0000'
    GROUP BY ALL
)

,centres_waiting_times AS (
    SELECT
        region_id
        ,year
        ,COUNT(DISTINCT health_center) AS units_waiting_times
    FROM {{ ref('stg_waiting_times__medical_assessment') }}
    WHERE health_center != 'Alla vårdcentraler'
        AND region_id != '0000'
    GROUP BY ALL
)

,joined AS (
    SELECT
        met.*
        ,npe.health_centres
        ,wt.units_waiting_times
    FROM metrics met
        LEFT JOIN centres_npe npe USING (region_id, year)
        LEFT JOIN centres_waiting_times wt USING (region_id, year)
)

,per_centre AS (
    SELECT
        region_short_name AS region
        ,year
        ,residents_projection_target_year AS target_year
        ,health_centres
        ,units_waiting_times
        ,ROUND(SAFE_DIVIDE(residents, health_centres)) AS residents_per_centre
        ,ROUND(SAFE_DIVIDE(residents_projected_5y, health_centres)) AS residents_per_centre_projected
        ,ROUND(SAFE_DIVIDE(residents_65_plus, health_centres)) AS residents_65_plus_per_centre
        ,ROUND(SAFE_DIVIDE(residents_65_plus_projected_5y, health_centres)) AS residents_65_plus_per_centre_projected
        -- extra 65+ residents in centres' worth of today's 65+ load
        ,ROUND(SAFE_DIVIDE(residents_65_plus_projected_5y - residents_65_plus
            , SAFE_DIVIDE(residents_65_plus, health_centres)), 1) AS centres_worth_of_65_plus_growth
    FROM joined

    UNION ALL

    -- all regions together (Sweden), over the regions that have a centre count
    SELECT
        'All regions with a centre count'
        ,ANY_VALUE(year)
        ,ANY_VALUE(residents_projection_target_year)
        ,SUM(health_centres)
        ,SUM(units_waiting_times)
        ,ROUND(SAFE_DIVIDE(SUM(IF(health_centres IS NOT NULL, residents, NULL)), SUM(health_centres)))
        ,ROUND(SAFE_DIVIDE(SUM(IF(health_centres IS NOT NULL, residents_projected_5y, NULL)), SUM(health_centres)))
        ,ROUND(SAFE_DIVIDE(SUM(IF(health_centres IS NOT NULL, residents_65_plus, NULL)), SUM(health_centres)))
        ,ROUND(SAFE_DIVIDE(SUM(IF(health_centres IS NOT NULL, residents_65_plus_projected_5y, NULL)), SUM(health_centres)))
        ,ROUND(SAFE_DIVIDE(
            SUM(IF(health_centres IS NOT NULL, residents_65_plus_projected_5y - residents_65_plus, NULL))
            , SAFE_DIVIDE(SUM(IF(health_centres IS NOT NULL, residents_65_plus, NULL)), SUM(health_centres))), 1)
    FROM joined
)

SELECT *
FROM per_centre
ORDER BY region = 'All regions with a centre count' DESC, centres_worth_of_65_plus_growth DESC
