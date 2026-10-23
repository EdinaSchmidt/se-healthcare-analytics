-- NPE dimension scores in long form: one row per survey, unit and dimension, with the score's
-- confidence interval. Units without a score (suppressed for too few responses) have no rows.
-- dimension_code matches npe_dimension_translations.

WITH scores AS (
    SELECT * FROM {{ ref('stg_npe__dimension_scores') }}
)

,cis AS (
    SELECT * FROM {{ ref('stg_npe__dimensions_score_cis') }}
)

,joined AS (
    SELECT
        scores.period_start
        ,scores.measurement_sv
        ,scores.selection_sv
        ,scores.aggregation_level
        ,scores.region_name
        ,scores.municipality_name
        ,scores.hsa_id
        ,scores.is_national
        ,scores.care_and_treatment_score
        ,cis.care_and_treatment_ci
        ,scores.participation_score
        ,cis.participation_ci
        ,scores.respectful_treatment_score
        ,cis.respectful_treatment_ci
        ,scores.continuity_score
        ,cis.continuity_ci
        ,scores.information_score
        ,cis.information_ci
        ,scores.accessibility_score
        ,cis.accessibility_ci
    FROM scores
    INNER JOIN cis
        ON cis.period_start = scores.period_start
        AND cis.measurement_sv = scores.measurement_sv
        AND cis.selection_sv = scores.selection_sv
        AND cis.aggregation_level = scores.aggregation_level
        AND cis.region_name = scores.region_name
        AND cis.municipality_name IS NOT DISTINCT FROM scores.municipality_name
        AND cis.hsa_id IS NOT DISTINCT FROM scores.hsa_id
)

SELECT
    unpivoted.period_start
    ,unpivoted.measurement_sv
    ,unpivoted.selection_sv
    ,unpivoted.aggregation_level
    ,reg.region_id
    ,unpivoted.municipality_name
    ,unpivoted.hsa_id
    ,unpivoted.is_national
    ,unpivoted.dimension_code
    ,unpivoted.score
    ,unpivoted.ci
FROM joined
UNPIVOT ((score, ci) FOR dimension_code IN (
    (care_and_treatment_score, care_and_treatment_ci) AS 'care_and_treatment'
    ,(participation_score, participation_ci) AS 'participation'
    ,(respectful_treatment_score, respectful_treatment_ci) AS 'respectful_treatment'
    ,(continuity_score, continuity_ci) AS 'continuity'
    ,(information_score, information_ci) AS 'information'
    ,(accessibility_score, accessibility_ci) AS 'accessibility'
    )) AS unpivoted
LEFT JOIN {{ ref('regions') }} reg ON reg.region_patient_surveys = unpivoted.region_name
