WITH flags AS (
    SELECT
        region_id
        ,is_national
        ,region_short_name
        ,year
        ,care_need_index
        ,residents_growth_5y
        ,residents_change_5y
        ,residents_65_plus_growth_5y
        ,residents_65_plus_change_5y
        ,residents_65_plus_share_change_5y
        ,reasonable_wait_diff
        ,trust_diff
        ,purchase_share_diff
        ,cost_deviation_from_national
        ,first_contact_answered_share_diff_from_national
        ,assessed_within_3_days_share_diff_from_national

        -- NULL = can't be assessed: unreliable data or a missing input.
        -- The comparison in ELSE returns NULL when its input is NULL.
        ,CASE WHEN is_national THEN NULL
            WHEN is_access_data_reliable IS NOT TRUE THEN NULL
            ELSE assessed_within_3_days_share_diff_from_national <= -0.05
            END AS is_access_below_national

        ,CASE WHEN is_national THEN NULL
            WHEN is_first_contact_data_reliable IS NOT TRUE THEN NULL
            WHEN has_first_contact_data IS NOT TRUE THEN NULL
            ELSE first_contact_answered_share_diff_from_national <= -0.1
            END AS is_first_call_below_national

        ,CASE WHEN is_national THEN NULL
            WHEN has_patient_survey_data IS NOT TRUE THEN NULL
            ELSE accessibility_score_ci_upper < national_accessibility_score_ci_lower
            END AS is_accessibility_clearly_below_national

        ,CASE WHEN is_national THEN NULL
            WHEN has_patient_survey_data IS NOT TRUE THEN NULL
            ELSE continuity_score_ci_upper < national_continuity_score_ci_lower
            END AS is_continuity_clearly_below_national

        ,CASE WHEN is_national THEN NULL
            ELSE reasonable_wait_diff <= -0.05
            END AS is_reasonable_wait_below_national

        ,CASE WHEN is_national THEN NULL
            ELSE trust_diff <= -0.05
            END AS is_trust_below_national


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

,rule_inputs AS (
    SELECT
        *
        ,SAFE_DIVIDE(score, assessable_flags) AS below_national_share

        -- Access gap: at least one measured access check met; one assessable check is enough to
        -- say FALSE. When neither can be assessed (unreliable or missing waiting-time data), fall
        -- back on the two access surveys: a gap only when patients (NPE accessibility) and
        -- residents (reasonable waiting time) agree. Three-valued AND: NULL if a survey is missing
        -- and the other doesn't already rule the gap out.
        ,CASE
            WHEN is_access_below_national OR is_first_call_below_national THEN TRUE
            WHEN is_access_below_national IS NOT NULL OR is_first_call_below_national IS NOT NULL THEN FALSE
            ELSE is_accessibility_clearly_below_national AND is_reasonable_wait_below_national
            END AS has_access_gap

        ,CASE
            WHEN is_access_below_national IS NOT NULL OR is_first_call_below_national IS NOT NULL THEN 'waiting_times'
            WHEN (is_accessibility_clearly_below_national AND is_reasonable_wait_below_national) IS NOT NULL THEN 'surveys'
            END AS access_gap_source

        -- Demand: projected growth in residents aged 65+ against the median region of the same year
        ,PERCENTILE_CONT(residents_65_plus_change_5y, 0.5) OVER () AS residents_65_plus_change_5y_median
    FROM flags_calc
)

SELECT
    *
    ,residents_65_plus_change_5y > residents_65_plus_change_5y_median AS is_demand_above_median

    -- Shortlisted: an access gap AND demand above the median region. Three-valued AND, so a
    -- region with unreliable access data is NULL (can't judge) unless its demand is too low.
    ,(has_access_gap AND residents_65_plus_change_5y > residents_65_plus_change_5y_median) AS is_shortlisted

FROM rule_inputs