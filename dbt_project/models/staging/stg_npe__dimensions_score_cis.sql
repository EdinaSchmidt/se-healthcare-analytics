WITH source AS (
    SELECT * FROM {{ source('npe', 'dimension_score_cis') }}
)

,renamed AS (
    SELECT
        DATE(CAST(survey_period AS INT64), 1, 1) AS period_start
        ,measurement AS measurement_sv
        ,selection AS selection_sv
        ,CASE aggregation_level
            WHEN 'Region' THEN 'region'
            WHEN 'Kommun' THEN 'municipality'
            WHEN 'Hälso-/vårdcentral' THEN 'health_centre'
            END AS aggregation_level
        ,region AS region_name
        ,kommun AS municipality_name
        ,halso_vardcentral AS health_centre_name
        ,hsa_id
        ,region = 'Alla' AS is_national -- 'Alla' rows are the national total, repeated at every aggregation level
        ,vard_och_behandling AS care_and_treatment_ci
        ,delaktighet AS participation_ci
        ,bemotande AS respectful_treatment_ci
        ,kontinuitet AS continuity_ci
        ,information AS information_ci
        ,tillganglighet AS accessibility_ci
        ,kommentar AS comment_sv
        ,CASE kommentar -- why values are missing
            WHEN 'För få svar' THEN 'too_few_responses'
            WHEN 'För få svar på en eller flera frågor' THEN 'too_few_responses_some_questions'
            END AS suppression_reason
        ,CAST(REGEXP_EXTRACT(respondent_threshold, r'\d+') AS INT64) AS respondent_threshold -- 'Publik: 30' -> 30
        ,CAST(extract_date AS DATE) AS extract_date
    FROM source
    )

SELECT * FROM renamed
