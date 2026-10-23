-- NPE dimension scores (0-100) per survey, unit and dimension, with the confidence interval.
-- Same units and levels as fct_npe_unit_results; never sum or average across levels.

SELECT
    period_start
    ,measurement_sv
    ,selection_sv
    ,aggregation_level
    ,region_id
    ,municipality_name
    ,hsa_id AS care_unit_id
    ,is_national
    ,dimension_code
    ,score
    ,ci
FROM {{ ref('int_npe__dimension_scores') }}
