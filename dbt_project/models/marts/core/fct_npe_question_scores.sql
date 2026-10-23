-- NPE question scores (0-100) per survey, unit and scored question, with the confidence interval.
-- Same units and levels as fct_npe_unit_results; question wording is in dim_npe_question.

SELECT
    period_start
    ,measurement_sv
    ,selection_sv
    ,aggregation_level
    ,region_id
    ,municipality_name
    ,hsa_id AS care_unit_id
    ,is_national
    ,question_number
    ,score
    ,ci
FROM {{ ref('int_npe__question_scores') }}
