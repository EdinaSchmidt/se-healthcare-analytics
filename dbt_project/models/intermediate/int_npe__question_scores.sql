-- NPE question scores in long form: one row per survey, unit and scored question, with the score's
-- confidence interval. Only questions with an answer scale are kept (16-18 have none, so their
-- "score" means nothing); units without a score (too few responses) have no rows.

WITH scores AS (
    SELECT * FROM {{ ref('stg_npe__question_means') }}
)

,cis AS (
    SELECT * FROM {{ ref('stg_npe__question_mean_cis') }}
)

,scored_questions AS (
    SELECT DISTINCT
        period_start
        ,measurement_sv
        ,selection_sv
        ,question_number
    FROM {{ ref('stg_npe__questions') }}
    WHERE answer_weight IS NOT NULL
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
        {%- for q in range(1, 19) %}
        ,scores.q{{ q }}_score
        ,cis.q{{ q }}_ci
        {%- endfor %}
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
    ,CAST(unpivoted.question_number AS INT64) AS question_number
    ,unpivoted.score
    ,unpivoted.ci
FROM joined
UNPIVOT ((score, ci) FOR question_number IN (
    {%- for q in range(1, 19) %}
    {{ ',' if not loop.first }}(q{{ q }}_score, q{{ q }}_ci) AS {{ q }}
    {%- endfor %}
    )) AS unpivoted
INNER JOIN scored_questions
    ON scored_questions.period_start = unpivoted.period_start
    AND scored_questions.measurement_sv = unpivoted.measurement_sv
    AND scored_questions.selection_sv = unpivoted.selection_sv
    -- the type checker reads UNPIVOT labels as strings
    AND scored_questions.question_number = CAST(unpivoted.question_number AS INT64)
LEFT JOIN {{ ref('regions') }} reg ON reg.region_patient_surveys = unpivoted.region_name
