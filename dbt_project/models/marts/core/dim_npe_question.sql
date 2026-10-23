WITH questions AS (
    SELECT DISTINCT
        period_start
        ,measurement_sv
        ,selection_sv
        ,question_number
        ,question_text_sv
        ,dimension_sv
    FROM {{ ref('stg_npe__questions') }}
)

SELECT
    que.period_start
    ,que.measurement_sv
    ,que.selection_sv
    ,que.question_number
    ,qtr.question_text
    ,qtr.question_short_name
    ,dtr.dimension_code
    ,dtr.dimension_name
    ,que.question_text_sv
    ,que.dimension_sv
FROM questions que
LEFT JOIN {{ ref('npe_question_translations') }} qtr USING(question_text_sv)
LEFT JOIN {{ ref('npe_dimension_translations') }} dtr USING(dimension_sv)
