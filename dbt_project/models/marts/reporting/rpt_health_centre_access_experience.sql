-- Do patients notice better access? Each NPE health centre of the latest survey with its measured
-- access in the survey year (the waiting-times months of that year: July-December 2025 for the 2025
-- survey) next to its NPE scores. Grain: one row per NPE health centre, matched or not, so the match
-- rate can be read here. Shares are 0-1, scores 0-100.
-- is_included marks the centres the comparison uses: matched to a waiting-times unit, at least 250
-- assessments in the window and both NPE scores published.

WITH survey AS (
    SELECT MAX(period_start) AS period_start
    FROM {{ ref('fct_npe_unit_results') }}
)

,npe AS (
    SELECT
        res.care_unit_id
        ,res.respondents
        ,res.response_rate_pct
        ,res.overall_experience_score
        ,res.overall_experience_ci
        ,acc.score AS accessibility_score
        ,acc.ci AS accessibility_ci
    FROM {{ ref('fct_npe_unit_results') }} res
    INNER JOIN survey ON survey.period_start = res.period_start
    LEFT JOIN {{ ref('fct_npe_dimension_scores') }} acc
        ON acc.period_start = res.period_start
        AND acc.care_unit_id = res.care_unit_id
        AND acc.aggregation_level = 'health_centre'
        AND acc.dimension_code = 'accessibility'
    WHERE res.aggregation_level = 'health_centre'
        AND NOT res.is_national
)

,assessment AS (
    SELECT
        fct.care_unit_id
        ,COUNTIF(fct.total_assessments IS NOT NULL) AS months_with_assessment_data
        ,SUM(IF(fct.assessed_within_3_days IS NOT NULL AND fct.assessed_same_day IS NOT NULL, fct.total_assessments, NULL)) AS total_assessments
        ,SUM(IF(fct.total_assessments IS NOT NULL AND fct.assessed_same_day IS NOT NULL, fct.assessed_within_3_days, NULL)) AS assessed_within_3_days
        ,SUM(IF(fct.total_assessments IS NOT NULL AND fct.assessed_within_3_days IS NOT NULL, fct.assessed_same_day, NULL)) AS assessed_same_day
        ,MIN(fct.period_start) AS window_start
        ,MAX(fct.period_start) AS window_end
    FROM {{ ref('fct_medical_assessment') }} fct
    CROSS JOIN survey
    WHERE fct.aggregation_level = 'health_centre'
        AND EXTRACT(YEAR FROM fct.period_start) = EXTRACT(YEAR FROM survey.period_start)
    GROUP BY 1
)

,contacts AS (
    SELECT
        fct.care_unit_id
        ,SUM(IF(fct.answered_contacts IS NOT NULL, fct.total_contacts, NULL)) AS total_contacts
        ,SUM(IF(fct.total_contacts IS NOT NULL, fct.answered_contacts, NULL)) AS answered_contacts
    FROM {{ ref('fct_first_contact') }} fct
    CROSS JOIN survey
    WHERE fct.aggregation_level = 'health_centre'
        AND fct.contact_type = 'all'
        AND EXTRACT(YEAR FROM fct.period_start) = EXTRACT(YEAR FROM survey.period_start)
    GROUP BY 1
)

,joined AS (
    SELECT
        npe.care_unit_id
        ,cu.care_unit_name
        ,cu.region_id
        ,reg.region_short_name
        ,cu.is_matched
        ,cu.match_method
        ,npe.respondents
        ,npe.response_rate_pct
        ,npe.overall_experience_score
        ,npe.overall_experience_ci
        ,npe.accessibility_score
        ,npe.accessibility_ci
        ,ass.months_with_assessment_data
        ,ass.total_assessments
        ,SAFE_DIVIDE(ass.assessed_within_3_days, ass.total_assessments) AS within_3_days_share
        ,SAFE_DIVIDE(ass.assessed_same_day, ass.total_assessments) AS same_day_share
        ,con.total_contacts
        ,SAFE_DIVIDE(con.answered_contacts, con.total_contacts) AS contacts_answered_share
        ,cu.is_matched
            AND COALESCE(ass.total_assessments, 0) >= 250
            AND npe.overall_experience_score IS NOT NULL
            AND npe.accessibility_score IS NOT NULL AS is_included
    FROM npe
    INNER JOIN {{ ref('dim_care_unit') }} cu USING (care_unit_id)
    LEFT JOIN {{ ref('dim_region') }} reg ON reg.region_id = cu.region_id
    LEFT JOIN assessment ass USING (care_unit_id)
    LEFT JOIN contacts con USING (care_unit_id)
)

,quintiles AS (
    -- 1 = the fifth of included centres with the lowest share assessed within 3 days
    SELECT
        care_unit_id
        ,NTILE(5) OVER (ORDER BY within_3_days_share, care_unit_id) AS access_quintile
    FROM joined
    WHERE is_included
)

SELECT
    joined.*
    ,quintiles.access_quintile
    ,CASE quintiles.access_quintile
        WHEN 1 THEN 'Slowest fifth'
        WHEN 2 THEN 'Second fifth'
        WHEN 3 THEN 'Middle fifth'
        WHEN 4 THEN 'Fourth fifth'
        WHEN 5 THEN 'Fastest fifth'
        END AS access_quintile_label
    ,EXTRACT(YEAR FROM survey.period_start) AS survey_year
    ,(SELECT CONCAT(FORMAT_DATE('%b', MIN(window_start)), '–', FORMAT_DATE('%b %Y', MAX(window_end))) FROM assessment) AS access_window_label
FROM joined
CROSS JOIN survey
LEFT JOIN quintiles USING (care_unit_id)
