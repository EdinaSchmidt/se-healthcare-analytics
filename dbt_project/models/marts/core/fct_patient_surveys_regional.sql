
SELECT 
    dim.region_id
    ,dim.year
    ,dim.comment
    ,dim.comment_sv
    ,dim.dimension 
    ,dim.score
    ,ci.score_ci AS score_ci_half_width 
    ,dim.score - ci.score_ci AS score_ci_lower
    ,dim.score + ci.score_ci AS score_ci_upper


FROM 
    {{ ref('stg_patient_surveys__dimensions') }} dim
    LEFT JOIN {{ ref('stg_patient_surveys__dimensions_ci') }} ci USING(dimension_result_key)
WHERE 
    dim.aggregation_level = 'region'
    AND dim.selection = 'doctor_visit'
