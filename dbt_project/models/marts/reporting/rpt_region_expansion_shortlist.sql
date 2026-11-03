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

,first_contact_all AS (
    SELECT 
        region_id
        ,year
        ,SUM(answered_calls) AS answered_calls
        ,SUM(total_calls) AS total_calls
    FROM {{ ref('fct_waiting_times_first_contact') }}
    GROUP BY 
        ALL
)

,first_contact_national AS (
    SELECT 
        year
        ,SUM(answered_calls) AS national_answered_calls
        ,SUM(total_calls) AS national_total_calls
    FROM {{ ref('fct_waiting_times_first_contact') }}
    WHERE region_id = '0000'
    GROUP BY ALL   
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
        ,assessed_within_3_days AS national_assessed_within_3_days
        ,total_assessments AS national_total_assessments
    FROM {{ ref('fct_waiting_times_medical_assessments') }}
    WHERE region_id = '0000'
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
    FROM 
        kolada_national kol
        FULL OUTER JOIN first_contact_national frs USING(year)
        FULL OUTER JOIN medical_assessment_national med USING(year)
    
)

,metrics AS (
SELECT 
    region_id
    ,reg.region_short_name
    ,reg.is_national
    ,year
    ,kol.residents
    ,kol.residents_projected_5y
    ,kol.residents_projection_base_year
    ,kol.residents_projection_target_year
    ,SAFE_DIVIDE(kol.residents_projected_5y, kol.residents) - 1  AS residents_growth_5y
    ,kol.residents_65_plus
    ,SAFE_DIVIDE(kol.residents_65_plus, kol.residents) AS residents_65_plus_share
    ,kol.residents_65_plus_projected_5y
    ,SAFE_DIVIDE(kol.residents_65_plus_projected_5y, kol.residents_projected_5y) AS residents_65_plus_share_projected_5y
    ,kol.residents_65_plus_projection_base_year
    ,kol.residents_65_plus_projection_target_year
    ,SAFE_DIVIDE(kol.residents_65_plus_projected_5y, kol.residents_65_plus) - 1  AS residents_65_plus_growth_5y
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

    ,med.assessed_within_3_days
    ,med.total_assessments
    ,SAFE_DIVIDE(med.assessed_within_3_days, med.total_assessments) AS assessed_within_3_days_share
    ,nat.national_assessed_within_3_days
    ,nat.national_total_assessments
    ,SAFE_DIVIDE(nat.national_assessed_within_3_days, nat.national_total_assessments) AS national_assessed_within_3_days_share

    ,med.months_reported AS data_quality_flag_medical_assessment_months_reported
    ,med.months_in_data AS data_quality_flag_medical_assessment_months_in_data
    ,med.missing_months AS data_quality_flag_medical_assessment_missing_months
FROM
    kolada_all kol
    FULL OUTER JOIN first_contact_all frs USING(year, region_id)
    FULL OUTER JOIN medical_assessment_all med USING(year, region_id)
    LEFT JOIN national_metrics nat USING(year)
    LEFT JOIN {{ ref('dim_region') }} reg USING(region_id)
)
SELECT 
    *
    ,residents_65_plus_share_projected_5y - residents_65_plus_share AS residents_65_plus_share_change_5y
    ,first_contact_answered_share - national_first_contact_answered_share AS first_contact_answered_share_diff_from_national
    ,assessed_within_3_days_share - national_assessed_within_3_days_share AS assessed_within_3_days_share_diff_from_national
FROM metrics


