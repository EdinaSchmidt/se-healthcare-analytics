WITH source AS (
    SELECT * FROM {{ source('npe', 'response_rates') }}
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
        ,CAST(utskickade_enkater AS INT64) AS surveys_sent
        ,CAST(antal_respondenter AS INT64) AS respondents
        ,svarsfrekvens AS response_rate_pct
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
