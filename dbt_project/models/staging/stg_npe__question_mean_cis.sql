WITH source AS (
    SELECT * FROM {{ source('npe', 'question_mean_cis') }}
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
        ,q1 AS q1_ci
        ,q2 AS q2_ci
        ,q3 AS q3_ci
        ,q4 AS q4_ci
        ,q5 AS q5_ci
        ,q6 AS q6_ci
        ,q7 AS q7_ci
        ,q8 AS q8_ci
        ,q9 AS q9_ci
        ,q10 AS q10_ci
        ,q11 AS q11_ci
        ,q12 AS q12_ci
        ,q13 AS q13_ci
        ,q14 AS q14_ci
        ,q15 AS q15_ci
        ,q16 AS q16_ci
        ,q17 AS q17_ci
        ,q18 AS q18_ci
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
