-- Patient experience per region and question (NPE, SKR's own region aggregates), against Sweden:
-- which questions pull a region's dimension scores down. Grain: one row per survey, region (Sweden
-- included) and scored question. Scores are 0-100.

WITH region_scores AS (
    SELECT
        period_start
        ,measurement_sv
        ,selection_sv
        ,region_id
        ,question_number
        ,score
        ,ci
    FROM {{ ref('fct_npe_question_scores') }}
    WHERE aggregation_level = 'region'
)

,national AS (
    SELECT period_start, question_number, score AS national_score
    FROM region_scores
    WHERE region_id = '0000'
)

SELECT
    sco.period_start
    ,EXTRACT(YEAR FROM sco.period_start) AS survey_year
    ,sco.region_id
    ,reg.region_short_name
    ,reg.is_national
    ,sco.question_number
    ,que.question_short_name
    ,que.question_text
    ,que.dimension_code
    ,que.dimension_name
    ,sco.score
    ,sco.ci
    ,nat.national_score
    ,sco.score - nat.national_score AS deviation_from_national
    -- 1 = the region's lowest-scoring question
    ,RANK() OVER (PARTITION BY sco.period_start, sco.region_id ORDER BY sco.score) AS rank_in_region
FROM region_scores sco
INNER JOIN national nat USING (period_start, question_number)
INNER JOIN {{ ref('dim_region') }} reg ON reg.region_id = sco.region_id
LEFT JOIN {{ ref('dim_npe_question') }} que
    ON que.period_start = sco.period_start
    AND que.measurement_sv = sco.measurement_sv
    AND que.selection_sv = sco.selection_sv
    AND que.question_number = sco.question_number
