WITH source AS (
    SELECT * FROM {{ source('npe', 'questions') }}
)

,renamed AS (
    SELECT
        DATE(CAST(survey_period AS INT64), 1, 1) AS period_start
        ,measurement AS measurement_sv
        ,selection AS selection_sv
        -- Frågor is a fill-down layout: position, text, dimension and scale are only set on a question's first answer row
        ,CAST(LAST_VALUE(position IGNORE NULLS) OVER (PARTITION BY survey_period, measurement, selection ORDER BY _row_number) AS INT64) AS question_number
        ,CAST(svarsalternativ AS INT64) AS answer_option
        ,TRIM(text) AS question_text_sv
        ,TRIM(dimension) AS dimension_sv
        ,normaliserad_svarsskala AS answer_scale_sv
        ,TRIM(svarstext) AS answer_text_sv
    FROM source
    )

,filled_down AS (
    SELECT
        period_start
        ,measurement_sv
        ,selection_sv
        ,question_number
        ,answer_option
        ,FIRST_VALUE(question_text_sv) OVER question AS question_text_sv
        ,FIRST_VALUE(dimension_sv) OVER question AS dimension_sv
        ,answer_text_sv
        -- The scale has one weight per answer option, with decimal commas: '1, 0,67, 0,33, 0, null'.
        -- 0,67 and 0,33 are rounded 2/3 and 1/3; NPE's published scores only reproduce with the exact thirds.
        ,CAST(NULLIF(REPLACE(SPLIT(FIRST_VALUE(answer_scale_sv) OVER question, ', ')[SAFE_OFFSET(answer_option - 1)], ',', '.'), 'null') AS FLOAT64) AS answer_weight
    FROM renamed
    WINDOW question AS (PARTITION BY period_start, measurement_sv, selection_sv, question_number ORDER BY answer_option)
    )

SELECT * FROM filled_down
