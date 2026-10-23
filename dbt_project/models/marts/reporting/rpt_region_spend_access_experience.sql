-- Do regions that spend more get better access or experience? Per region, the survey year's
-- primary care cost per inhabitant (Kolada N71007, nominal), access in that year's waiting-times
-- months (July-December 2025 for the 2025 survey) and NPE scores. Grain: one row per region,
-- Sweden included. Shares are 0-1, scores 0-100. With about 20 regions this shows association,
-- not cause: geography and age structure drive both cost and access.

WITH survey AS (
    SELECT MAX(period_start) AS period_start
    FROM {{ ref('fct_npe_unit_results') }}
)

,cost AS (
    SELECT
        fct.region_id
        ,fct.amount AS cost_per_inhabitant
    FROM {{ ref('fct_kpi_values') }} fct
    INNER JOIN {{ ref('dim_kpi') }} kpi ON kpi.kpi_id = fct.kpi_id
    CROSS JOIN survey
    WHERE kpi.cost_role = 'total'
        AND EXTRACT(YEAR FROM fct.period_start) = EXTRACT(YEAR FROM survey.period_start)
)

,assessment AS (
    SELECT
        fct.region_id
        ,COUNTIF(fct.total_assessments IS NOT NULL) AS months_with_assessment_data
        ,SUM(IF(fct.assessed_within_3_days IS NOT NULL AND fct.assessed_same_day IS NOT NULL, fct.total_assessments, NULL)) AS total_assessments
        ,SUM(IF(fct.total_assessments IS NOT NULL AND fct.assessed_same_day IS NOT NULL, fct.assessed_within_3_days, NULL)) AS assessed_within_3_days
        ,SUM(IF(fct.total_assessments IS NOT NULL AND fct.assessed_within_3_days IS NOT NULL, fct.assessed_same_day, NULL)) AS assessed_same_day
    FROM {{ ref('fct_medical_assessment') }} fct
    CROSS JOIN survey
    WHERE fct.aggregation_level = 'region'
        AND EXTRACT(YEAR FROM fct.period_start) = EXTRACT(YEAR FROM survey.period_start)
    GROUP BY 1
)

,contacts AS (
    SELECT
        fct.region_id
        ,SUM(IF(fct.answered_contacts IS NOT NULL, fct.total_contacts, NULL)) AS total_contacts
        ,SUM(IF(fct.total_contacts IS NOT NULL, fct.answered_contacts, NULL)) AS answered_contacts
    FROM {{ ref('fct_first_contact') }} fct
    CROSS JOIN survey
    WHERE fct.aggregation_level = 'region'
        AND fct.contact_type = 'all'
        AND EXTRACT(YEAR FROM fct.period_start) = EXTRACT(YEAR FROM survey.period_start)
    GROUP BY 1
)

,experience AS (
    SELECT
        res.region_id
        ,res.overall_experience_score
        ,acc.score AS accessibility_score
    FROM {{ ref('fct_npe_unit_results') }} res
    INNER JOIN survey ON survey.period_start = res.period_start
    LEFT JOIN {{ ref('fct_npe_dimension_scores') }} acc
        ON acc.period_start = res.period_start
        AND acc.region_id = res.region_id
        AND acc.aggregation_level = 'region'
        AND acc.dimension_code = 'accessibility'
    WHERE res.aggregation_level = 'region'
)

,regions AS (
    SELECT
        reg.region_id
        ,reg.region_short_name
        ,reg.is_national
        ,cost.cost_per_inhabitant
        ,ass.months_with_assessment_data
        ,ass.total_assessments
        ,SAFE_DIVIDE(ass.assessed_within_3_days, ass.total_assessments) AS within_3_days_share
        ,SAFE_DIVIDE(ass.assessed_same_day, ass.total_assessments) AS same_day_share
        ,SAFE_DIVIDE(con.answered_contacts, con.total_contacts) AS contacts_answered_share
        ,xp.overall_experience_score
        ,xp.accessibility_score
    FROM {{ ref('dim_region') }} reg
    LEFT JOIN cost USING (region_id)
    LEFT JOIN assessment ass USING (region_id)
    LEFT JOIN contacts con USING (region_id)
    LEFT JOIN experience xp USING (region_id)
)

SELECT
    regions.*
    ,EXTRACT(YEAR FROM survey.period_start) AS survey_year
    ,SAFE_DIVIDE(regions.cost_per_inhabitant, nat.cost_per_inhabitant) - 1 AS cost_vs_national
    ,regions.within_3_days_share - nat.within_3_days_share AS within_3_days_vs_national
    ,regions.overall_experience_score - nat.overall_experience_score AS overall_experience_vs_national
    ,regions.accessibility_score - nat.accessibility_score AS accessibility_vs_national
    -- a region is in the comparison when it has all three sources for the year
    ,NOT regions.is_national
        AND regions.cost_per_inhabitant IS NOT NULL
        AND regions.within_3_days_share IS NOT NULL
        AND regions.overall_experience_score IS NOT NULL AS is_included
FROM regions
CROSS JOIN survey
LEFT JOIN regions nat ON nat.is_national
