WITH source AS (
    SELECT * FROM {{ source('npe', 'answer_distributions') }}
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
        ,CAST(q1_1 AS INT64) AS q1_1_count -- respondents who gave answer option 1 to question 1
        ,CAST(q1_2 AS INT64) AS q1_2_count
        ,CAST(q1_3 AS INT64) AS q1_3_count
        ,CAST(q1_4 AS INT64) AS q1_4_count
        ,CAST(q1_5 AS INT64) AS q1_5_count
        ,CAST(q2_1 AS INT64) AS q2_1_count
        ,CAST(q2_2 AS INT64) AS q2_2_count
        ,CAST(q2_3 AS INT64) AS q2_3_count
        ,CAST(q2_4 AS INT64) AS q2_4_count
        ,CAST(q2_5 AS INT64) AS q2_5_count
        ,CAST(q3_1 AS INT64) AS q3_1_count
        ,CAST(q3_2 AS INT64) AS q3_2_count
        ,CAST(q3_3 AS INT64) AS q3_3_count
        ,CAST(q3_4 AS INT64) AS q3_4_count
        ,CAST(q3_5 AS INT64) AS q3_5_count
        ,CAST(q4_1 AS INT64) AS q4_1_count
        ,CAST(q4_2 AS INT64) AS q4_2_count
        ,CAST(q4_3 AS INT64) AS q4_3_count
        ,CAST(q4_4 AS INT64) AS q4_4_count
        ,CAST(q4_5 AS INT64) AS q4_5_count
        ,CAST(q5_1 AS INT64) AS q5_1_count
        ,CAST(q5_2 AS INT64) AS q5_2_count
        ,CAST(q5_3 AS INT64) AS q5_3_count
        ,CAST(q5_4 AS INT64) AS q5_4_count
        ,CAST(q5_5 AS INT64) AS q5_5_count
        ,CAST(q6_1 AS INT64) AS q6_1_count
        ,CAST(q6_2 AS INT64) AS q6_2_count
        ,CAST(q6_3 AS INT64) AS q6_3_count
        ,CAST(q6_4 AS INT64) AS q6_4_count
        ,CAST(q6_5 AS INT64) AS q6_5_count
        ,CAST(q7_1 AS INT64) AS q7_1_count
        ,CAST(q7_2 AS INT64) AS q7_2_count
        ,CAST(q7_3 AS INT64) AS q7_3_count
        ,CAST(q7_4 AS INT64) AS q7_4_count
        ,CAST(q7_5 AS INT64) AS q7_5_count
        ,CAST(q8_1 AS INT64) AS q8_1_count
        ,CAST(q8_2 AS INT64) AS q8_2_count
        ,CAST(q8_3 AS INT64) AS q8_3_count
        ,CAST(q8_4 AS INT64) AS q8_4_count
        ,CAST(q8_5 AS INT64) AS q8_5_count
        ,CAST(q9_1 AS INT64) AS q9_1_count
        ,CAST(q9_2 AS INT64) AS q9_2_count
        ,CAST(q9_3 AS INT64) AS q9_3_count
        ,CAST(q9_4 AS INT64) AS q9_4_count
        ,CAST(q9_5 AS INT64) AS q9_5_count
        ,CAST(q10_1 AS INT64) AS q10_1_count
        ,CAST(q10_2 AS INT64) AS q10_2_count
        ,CAST(q10_3 AS INT64) AS q10_3_count
        ,CAST(q10_4 AS INT64) AS q10_4_count
        ,CAST(q10_5 AS INT64) AS q10_5_count
        ,CAST(q11_1 AS INT64) AS q11_1_count
        ,CAST(q11_2 AS INT64) AS q11_2_count
        ,CAST(q11_3 AS INT64) AS q11_3_count
        ,CAST(q11_4 AS INT64) AS q11_4_count
        ,CAST(q11_5 AS INT64) AS q11_5_count
        ,CAST(q12_1 AS INT64) AS q12_1_count
        ,CAST(q12_2 AS INT64) AS q12_2_count
        ,CAST(q12_3 AS INT64) AS q12_3_count
        ,CAST(q12_4 AS INT64) AS q12_4_count
        ,CAST(q12_5 AS INT64) AS q12_5_count
        ,CAST(q13_1 AS INT64) AS q13_1_count
        ,CAST(q13_2 AS INT64) AS q13_2_count
        ,CAST(q13_3 AS INT64) AS q13_3_count
        ,CAST(q13_4 AS INT64) AS q13_4_count
        ,CAST(q13_5 AS INT64) AS q13_5_count
        ,CAST(q14_1 AS INT64) AS q14_1_count
        ,CAST(q14_2 AS INT64) AS q14_2_count
        ,CAST(q14_3 AS INT64) AS q14_3_count
        ,CAST(q14_4 AS INT64) AS q14_4_count
        ,CAST(q15_1 AS INT64) AS q15_1_count
        ,CAST(q15_2 AS INT64) AS q15_2_count
        ,CAST(q15_3 AS INT64) AS q15_3_count
        ,CAST(q15_4 AS INT64) AS q15_4_count
        ,CAST(q15_5 AS INT64) AS q15_5_count
        ,CAST(q16_1 AS INT64) AS q16_1_count
        ,CAST(q16_2 AS INT64) AS q16_2_count
        ,CAST(q16_3 AS INT64) AS q16_3_count
        ,CAST(q16_4 AS INT64) AS q16_4_count
        ,CAST(q16_5 AS INT64) AS q16_5_count
        ,CAST(q16_6 AS INT64) AS q16_6_count
        ,CAST(q17_1 AS INT64) AS q17_1_count
        ,CAST(q17_2 AS INT64) AS q17_2_count
        ,CAST(q17_3 AS INT64) AS q17_3_count
        ,CAST(q18_1 AS INT64) AS q18_1_count
        ,CAST(q18_2 AS INT64) AS q18_2_count
        ,CAST(q18_3 AS INT64) AS q18_3_count
        ,CAST(q18_4 AS INT64) AS q18_4_count
        ,CAST(q18_5 AS INT64) AS q18_5_count
        ,CAST(q18_6 AS INT64) AS q18_6_count
        ,CAST(q18_7 AS INT64) AS q18_7_count
        ,CAST(q18_8 AS INT64) AS q18_8_count
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
