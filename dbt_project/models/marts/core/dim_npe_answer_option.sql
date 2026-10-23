SELECT
    ans.period_start
    ,ans.measurement_sv
    ,ans.selection_sv
    ,ans.question_number
    ,ans.answer_option
    ,tra.answer_text
    ,ans.answer_weight
    ,ans.answer_text_sv
FROM {{ ref('stg_npe__questions') }} ans
LEFT JOIN {{ ref('npe_answer_translations') }} tra USING(answer_text_sv)
