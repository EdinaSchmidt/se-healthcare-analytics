WITH source AS (
    SELECT * FROM {{ source('npe', 'question_means') }}
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
        ,q1 AS q1_score
        ,q2 AS q2_score
        ,q3 AS q3_score
        ,q4 AS q4_score
        ,q5 AS q5_score
        ,q6 AS q6_score
        ,q7 AS q7_score
        ,q8 AS q8_score
        ,q9 AS q9_score
        ,q10 AS q10_score
        ,q11 AS q11_score
        ,q12 AS q12_score
        ,q13 AS q13_score
        ,q14 AS q14_score
        ,q15 AS q15_score
        ,q16 AS q16_score
        ,q17 AS q17_score
        ,q18 AS q18_score
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
