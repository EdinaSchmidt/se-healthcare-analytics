WITH flags AS (
    SELECT
        region_id
        ,is_national
        ,region_short_name
        ,year
        ,care_need_index
        ,residents_growth_5y
        ,residents_65_plus_growth_5y
        ,residents_65_plus_share_change_5y
        ,reasonable_wait_diff
        ,trust_diff
        ,purchase_share_diff
        ,cost_deviation_from_national
        ,first_contact_answered_share_diff_from_national
        ,assessed_within_3_days_share_diff_from_national

        ,CASE WHEN is_national THEN NULL
            WHEN NOT is_access_data_reliable THEN NULL
            WHEN assessed_within_3_days_share_diff_from_national <= -0.05 THEN TRUE
            ELSE FALSE END AS is_access_below_national

        ,CASE WHEN is_national THEN NULL
            WHEN NOT is_first_contact_data_reliable THEN NULL
            WHEN NOT has_first_contact_data THEN NULL
            WHEN first_contact_answered_share_diff_from_national <= -0.1 THEN TRUE
            ELSE FALSE END AS is_first_call_below_national

        ,CASE WHEN is_national THEN NULL
            WHEN NOT has_patient_survey_data THEN NULL
            WHEN accessibility_score_ci_upper < national_accessibility_score_ci_lower THEN TRUE
            ELSE FALSE END AS is_accessibility_clearly_below_national

        ,CASE WHEN is_national THEN NULL
            WHEN NOT has_patient_survey_data THEN NULL
            WHEN continuity_score_ci_upper < national_continuity_score_ci_lower THEN TRUE
            ELSE FALSE END AS is_continuity_clearly_below_national
        
        ,CASE WHEN is_national THEN NULL
            WHEN reasonable_wait_diff <= -0.05 THEN TRUE
            ELSE FALSE END AS is_reasonable_wait_below_national

        ,CASE WHEN is_national THEN NULL
            WHEN trust_diff <= -0.05 THEN TRUE
            ELSE FALSE END AS is_trust_below_national


    FROM {{ ref('rpt_region_year_metrics') }}

)

,flags_calc AS (
    SELECT 
        *
        ,CASE WHEN is_access_below_national IS NULL THEN 0 ELSE 1 END
        + CASE WHEN is_first_call_below_national IS NULL THEN 0 ELSE 1 END
        + CASE WHEN is_accessibility_clearly_below_national IS NULL THEN 0 ELSE 1 END
        + CASE WHEN is_continuity_clearly_below_national IS NULL THEN 0 ELSE 1 END 
        + CASE WHEN is_reasonable_wait_below_national IS NULL THEN 0 ELSE 1 END
        + CASE WHEN is_trust_below_national IS NULL THEN 0 ELSE 1 END
            AS assessable_flags

        ,IF(is_access_below_national, 1, 0) + 
        IF(is_first_call_below_national, 1, 0) + 
        IF(is_accessibility_clearly_below_national, 1, 0) + 
        IF(is_continuity_clearly_below_national, 1, 0) +
        IF(is_reasonable_wait_below_national, 1, 0) +
        IF(is_trust_below_national, 1, 0) 
            AS score


    FROM flags


    {#
        Required sources:
        - Kolada: national_reasonable_wait_share
        - First contact: national_first_contact_answered_share
        - Medical assessment: national_assessed_within_3_days_share
        - Patient survey: national_accessibility_score
    #}

    WHERE
        year = {{ latest_complete_year(
            ref('rpt_region_year_metrics'),
            [
                'national_reasonable_wait_share',
                'national_first_contact_answered_share',
                'national_assessed_within_3_days_share',
                'national_accessibility_score'
            ]
        ) }}

        AND NOT is_national
)

SELECT 
    *
    ,SAFE_DIVIDE(score, assessable_flags) AS below_national_share

    ,CASE WHEN assessable_flags < 4 THEN NULL
        WHEN SAFE_DIVIDE(score, assessable_flags) >= 0.75 THEN TRUE
        ELSE FALSE END AS is_shortlisted

FROM flags_calc