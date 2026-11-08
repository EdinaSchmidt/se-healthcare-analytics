WITH kolada_all AS (
    SELECT
        val.region_id
        ,EXTRACT(YEAR FROM val.period_start) AS year
        ,CAST(MAX(CASE WHEN val.kpi_id = 'N01951' THEN val.amount END) AS INT64)  AS residents
        ,CAST(MAX(CASE WHEN val.kpi_id = 'N02907' THEN val.amount END) AS INT64) AS residents_projected_5y
        ,MAX(CASE WHEN val.kpi_id = 'N02907' THEN EXTRACT(YEAR FROM val.period_start) END) AS residents_projection_base_year
        ,MAX(CASE WHEN val.kpi_id = 'N02907' THEN EXTRACT(YEAR FROM DATE_ADD(val.period_start, INTERVAL kpi.horizon_years YEAR)) END) AS residents_projection_target_year

        ,CAST(MAX(CASE WHEN val.kpi_id = 'N01938' THEN val.amount END) AS INT64) AS residents_65_plus
        ,CAST(MAX(CASE WHEN val.kpi_id = 'N02912' THEN val.amount END) AS INT64) AS residents_65_plus_projected_5y
        ,MAX(CASE WHEN val.kpi_id = 'N02912' THEN EXTRACT(YEAR FROM val.period_start) END) AS residents_65_plus_projection_base_year
        ,MAX(CASE WHEN val.kpi_id = 'N02912' THEN EXTRACT(YEAR FROM DATE_ADD(val.period_start, INTERVAL kpi.horizon_years YEAR)) END) AS residents_65_plus_projection_target_year

        ,MAX(CASE WHEN val.kpi_id = 'N00992' THEN val.amount END) AS care_need_index

        ,MAX(CASE WHEN val.kpi_id = 'U70450' THEN val.amount END) / 100 AS reasonable_wait_share

        ,MAX(CASE WHEN val.kpi_id = 'U71458' THEN val.amount END) / 100 AS trust_share

        ,MAX(CASE WHEN val.kpi_id = 'N71029' THEN val.amount END) / 100 AS purchase_share

        ,MAX(CASE WHEN val.kpi_id = 'N71007' THEN val.amount END) AS cost_per_inhabitant_sek


    FROM {{ ref('fct_kolada_kpi_values') }} val
        LEFT JOIN {{ ref('dim_kolada_kpi')}} kpi ON val.kpi_id = kpi.kpi_id
    WHERE val.kpi_id IN (
        'N01951',   -- Inhabitants
        'N02907',   -- Projected inhabitants, 5 years
        'N01938',   -- Inhabitants 65+
        'N02912',   -- Projected 65+, 5 years
        'N00992',   -- Care Need Index (CNI), index
        'U70450',   -- Reasonable waiting time to a health centre, share (%) --> “About the data”: even the national benchmark is modest, so “at Sweden’s level” doesn’t mean “good”
        'U71458',   -- Trust in health centres, share (%)
        'N71029',   -- Purchased primary care share
        'N71007'    -- Net cost of primary care, SEK per inhabitant
        )
        AND val.amount IS NOT NULL
    GROUP BY 
        ALL
)

,projections AS (
    -- SCB projections are stored under their base year (a new one every third year).
    -- Each is valid from its base year until the next one arrives.
    SELECT
        region_id
        ,year AS projection_base_year
        ,LEAD(year) OVER (PARTITION BY region_id ORDER BY year) AS next_projection_base_year
        ,residents AS residents_at_projection_base
        ,residents_65_plus AS residents_65_plus_at_projection_base
        ,residents_projected_5y
        ,residents_projection_target_year
        ,residents_65_plus_projected_5y
        ,residents_65_plus_projection_target_year
    FROM kolada_all
    WHERE residents_projected_5y IS NOT NULL
)

,kolada_national AS (
    SELECT 
        year
        ,reasonable_wait_share AS national_reasonable_wait_share
        ,trust_share AS national_trust_share
        ,purchase_share AS national_purchase_share
        ,cost_per_inhabitant_sek AS national_cost_per_inhabitant_sek
    FROM 
        kolada_all
    WHERE region_id = '0000'
)

,clean_regions AS (
    SELECT region_id
    FROM {{ ref('dim_region') }}
    WHERE NOT is_national
        AND (data_quality_note IS NULL
            OR data_quality_note NOT LIKE '%journal system change%')
)

,first_contact_all AS (
    SELECT 
        region_id
        ,year
        ,answered_calls
        ,total_calls
        ,months_reported
        ,months_in_data
        ,missing_months
    FROM {{ ref('fct_waiting_times_first_contact') }}
)

,first_contact_national AS (
    SELECT
        year
        ,SUM(answered_calls) AS national_answered_calls
        ,SUM(total_calls) AS national_total_calls
    FROM first_contact_all
    WHERE region_id IN (SELECT region_id FROM clean_regions)
    GROUP BY year
)

,medical_assessment_all AS (
    SELECT 
        region_id
        ,year
        ,assessed_within_3_days
        ,total_assessments
        ,months_reported
        ,months_in_data
        ,missing_months
    FROM {{ ref('fct_waiting_times_medical_assessments') }}
)

,medical_assessment_national AS (
    SELECT
        year
        ,SUM(assessed_within_3_days) AS national_assessed_within_3_days
        ,SUM(total_assessments) AS national_total_assessments
    FROM medical_assessment_all
    WHERE region_id IN (SELECT region_id FROM clean_regions)
    GROUP BY year
)

,patient_survey_scores_all AS (
    SELECT 
        region_id
        ,year
        ,SUM(CASE WHEN dimension = 'accessibility' THEN score END) AS accessibility_score
        ,SUM(CASE WHEN dimension = 'accessibility' THEN score_ci_lower END) AS accessibility_score_ci_lower
        ,SUM(CASE WHEN dimension = 'accessibility' THEN score_ci_upper END) AS accessibility_score_ci_upper
        ,SUM(CASE WHEN dimension = 'continuity' THEN score END) AS continuity_score
        ,SUM(CASE WHEN dimension = 'continuity' THEN score_ci_lower END) AS continuity_score_ci_lower
        ,SUM(CASE WHEN dimension = 'continuity' THEN score_ci_upper END) AS continuity_score_ci_upper
    FROM {{ ref('fct_patient_surveys_regional') }}
    WHERE 
        dimension IN ('accessibility', 'continuity')
    GROUP BY ALL
)

,patient_survey_scores_national AS (
    SELECT 
        region_id
        ,year
        ,accessibility_score AS national_accessibility_score
        ,accessibility_score_ci_lower AS national_accessibility_score_ci_lower
        ,accessibility_score_ci_upper AS national_accessibility_score_ci_upper
        ,continuity_score AS national_continuity_score
        ,continuity_score_ci_lower AS national_continuity_score_ci_lower
        ,continuity_score_ci_upper AS national_continuity_score_ci_upper
    FROM patient_survey_scores_all
    WHERE 
        region_id = '0000'
    GROUP BY ALL
)




,national_metrics AS (
    SELECT 
        year
        ,kol.national_reasonable_wait_share
        ,kol.national_trust_share
        ,kol.national_purchase_share
        ,kol.national_cost_per_inhabitant_sek
        ,frs.national_answered_calls
        ,frs.national_total_calls
        ,med.national_assessed_within_3_days
        ,med.national_total_assessments
        ,pss.national_accessibility_score
        ,pss.national_accessibility_score_ci_lower
        ,pss.national_accessibility_score_ci_upper
        ,pss.national_continuity_score
        ,pss.national_continuity_score_ci_lower
        ,pss.national_continuity_score_ci_upper
    FROM 
        kolada_national kol
        FULL OUTER JOIN first_contact_national frs USING(year)
        FULL OUTER JOIN medical_assessment_national med USING(year)
        FULL OUTER JOIN patient_survey_scores_national pss USING(year)
    
)

,metrics AS (
SELECT 
    region_id
    ,reg.region_short_name
    ,reg.is_national
    ,reg.data_quality_note
    ,year
    ,kol.residents
    ,kol.residents_65_plus
    ,SAFE_DIVIDE(kol.residents_65_plus, kol.residents) AS residents_65_plus_share
    ,kol.care_need_index
    ,kol.reasonable_wait_share
    ,nat.national_reasonable_wait_share
    ,kol.reasonable_wait_share - nat.national_reasonable_wait_share AS reasonable_wait_diff

    ,kol.trust_share
    ,nat.national_trust_share
    ,kol.trust_share - nat.national_trust_share AS trust_diff

    ,kol.purchase_share
    ,nat.national_purchase_share
    ,kol.purchase_share - nat.national_purchase_share AS purchase_share_diff

    ,kol.cost_per_inhabitant_sek
    ,nat.national_cost_per_inhabitant_sek
    ,SAFE_DIVIDE(kol.cost_per_inhabitant_sek, nat.national_cost_per_inhabitant_sek) - 1  AS cost_deviation_from_national

    ,frs.answered_calls
    ,frs.total_calls
    ,SAFE_DIVIDE(frs.answered_calls, frs.total_calls) AS first_contact_answered_share
    ,nat.national_answered_calls
    ,nat.national_total_calls
    ,SAFE_DIVIDE(nat.national_answered_calls, nat.national_total_calls) AS national_first_contact_answered_share

    ,frs.months_reported AS data_quality_flag_first_contact_months_reported
    ,frs.months_in_data AS data_quality_flag_first_contact_months_in_data
    ,frs.missing_months AS data_quality_flag_first_contact_missing_months

    ,med.assessed_within_3_days
    ,med.total_assessments
    ,SAFE_DIVIDE(med.assessed_within_3_days, med.total_assessments) AS assessed_within_3_days_share
    ,nat.national_assessed_within_3_days
    ,nat.national_total_assessments
    ,SAFE_DIVIDE(nat.national_assessed_within_3_days, nat.national_total_assessments) AS national_assessed_within_3_days_share

    ,med.months_reported AS data_quality_flag_medical_assessment_months_reported
    ,med.months_in_data AS data_quality_flag_medical_assessment_months_in_data
    ,med.missing_months AS data_quality_flag_medical_assessment_missing_months

    ,pss.accessibility_score
    ,pss.accessibility_score_ci_lower
    ,pss.accessibility_score_ci_upper
    ,pss.continuity_score
    ,pss.continuity_score_ci_lower
    ,pss.continuity_score_ci_upper

    ,nat.national_accessibility_score
    ,nat.national_accessibility_score_ci_lower
    ,nat.national_accessibility_score_ci_upper
    ,nat.national_continuity_score
    ,nat.national_continuity_score_ci_lower
    ,nat.national_continuity_score_ci_upper   

    ,pss.accessibility_score - nat.national_accessibility_score AS accessibility_score_diff
    ,pss.continuity_score - nat.national_continuity_score AS continuity_score_diff


FROM
    kolada_all kol
    FULL OUTER JOIN first_contact_all frs USING(year, region_id)
    FULL OUTER JOIN medical_assessment_all med USING(year, region_id)
    FULL OUTER JOIN patient_survey_scores_all pss USING(year, region_id)
    LEFT JOIN national_metrics nat USING(year)
    LEFT JOIN {{ ref('dim_region') }} reg USING(region_id)
)


SELECT 
    m.*
    ,p.residents_projected_5y
    ,p.projection_base_year AS residents_projection_base_year
    ,p.residents_projection_target_year
    ,SAFE_DIVIDE(p.residents_projected_5y, p.residents_at_projection_base) - 1 AS residents_growth_5y
    ,p.residents_projected_5y - p.residents_at_projection_base AS residents_change_5y
    ,p.residents_65_plus_projected_5y
    ,SAFE_DIVIDE(p.residents_65_plus_projected_5y, p.residents_projected_5y) AS residents_65_plus_share_projected_5y
    ,p.projection_base_year AS residents_65_plus_projection_base_year
    ,p.residents_65_plus_projection_target_year
    ,SAFE_DIVIDE(p.residents_65_plus_projected_5y, p.residents_65_plus_at_projection_base) - 1 AS residents_65_plus_growth_5y
    ,p.residents_65_plus_projected_5y - p.residents_65_plus_at_projection_base AS residents_65_plus_change_5y
    ,SAFE_DIVIDE(p.residents_65_plus_projected_5y, p.residents_projected_5y)
        - SAFE_DIVIDE(p.residents_65_plus_at_projection_base, p.residents_at_projection_base)
        AS residents_65_plus_share_change_5y

    ,m.first_contact_answered_share - m.national_first_contact_answered_share AS first_contact_answered_share_diff_from_national
    ,m.assessed_within_3_days_share - m.national_assessed_within_3_days_share AS assessed_within_3_days_share_diff_from_national

    ,CASE WHEN NOT m.is_national AND m.total_calls IS NOT NULL THEN TRUE 
        WHEN m.is_national THEN NULL 
        ELSE FALSE END has_first_contact_data
    
    ,CASE WHEN NOT m.is_national AND m.total_assessments IS NOT NULL THEN TRUE 
        WHEN m.is_national THEN NULL 
        ELSE FALSE END has_medical_assessment_data 

    ,CASE WHEN NOT m.is_national AND m.accessibility_score IS NOT NULL THEN TRUE 
        WHEN m.is_national THEN NULL 
        ELSE FALSE END has_patient_survey_data

    ,CASE WHEN NOT m.is_national AND m.data_quality_note LIKE '%journal system change%' THEN TRUE
        WHEN m.is_national THEN NULL 
        ELSE FALSE END has_journal_system_change
    
    ,CASE WHEN m.is_national THEN NULL
        WHEN m.data_quality_note LIKE '%journal system change%' THEN FALSE
        WHEN m.data_quality_flag_medical_assessment_months_in_data IS NULL THEN NULL  -- no rows for the year
        WHEN m.data_quality_flag_medical_assessment_missing_months > 0 THEN FALSE
        ELSE TRUE END AS is_access_data_reliable


    ,CASE WHEN m.is_national THEN NULL
        WHEN m.data_quality_note LIKE '%journal system change%' THEN FALSE
        WHEN m.data_quality_flag_first_contact_months_in_data IS NULL THEN NULL  -- no rows for the year
        WHEN m.data_quality_flag_first_contact_missing_months > 0 THEN FALSE
        ELSE TRUE END AS is_first_contact_data_reliable

FROM metrics m
LEFT JOIN projections p
    ON p.region_id = m.region_id
    AND m.year >= p.projection_base_year
    AND (p.next_projection_base_year IS NULL OR m.year < p.next_projection_base_year)


    



