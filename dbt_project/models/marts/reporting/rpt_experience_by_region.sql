-- Patient experience per region (NPE, SKR's own region aggregates): overall experience and the six
-- dimensions, against Sweden, with how many of the region's health centres score clearly below or
-- above Sweden. Grain: one row per survey, region (Sweden included) and measure. Scores are 0-100.
-- "Clearly" means the whole confidence interval lies on one side of Sweden's score.

WITH region_scores AS (
    SELECT period_start, region_id, 'overall_experience' AS measure_code, overall_experience_score AS score, overall_experience_ci AS ci
    FROM {{ ref('fct_npe_unit_results') }}
    WHERE aggregation_level = 'region'
        AND overall_experience_score IS NOT NULL

    UNION ALL

    SELECT period_start, region_id, dimension_code AS measure_code, score, ci
    FROM {{ ref('fct_npe_dimension_scores') }}
    WHERE aggregation_level = 'region'
)

,centre_scores AS (
    SELECT period_start, region_id, 'overall_experience' AS measure_code, overall_experience_score AS score, overall_experience_ci AS ci
    FROM {{ ref('fct_npe_unit_results') }}
    WHERE aggregation_level = 'health_centre'
        AND NOT is_national
        AND overall_experience_score IS NOT NULL

    UNION ALL

    SELECT period_start, region_id, dimension_code AS measure_code, score, ci
    FROM {{ ref('fct_npe_dimension_scores') }}
    WHERE aggregation_level = 'health_centre'
        AND NOT is_national
)

,national AS (
    SELECT period_start, measure_code, score AS national_score
    FROM region_scores
    WHERE region_id = '0000'
)

,centre_counts AS (
    -- per region, and summed over all regions under Sweden ('0000')
    SELECT
        cen.period_start
        ,group_region_id AS region_id
        ,cen.measure_code
        ,COUNT(*) AS centres_scored
        ,COUNTIF(cen.score + cen.ci < nat.national_score) AS centres_clearly_below_national
        ,COUNTIF(cen.score - cen.ci > nat.national_score) AS centres_clearly_above_national
    FROM centre_scores cen
    INNER JOIN national nat USING (period_start, measure_code)
    CROSS JOIN UNNEST([cen.region_id, '0000']) AS group_region_id
    GROUP BY 1, 2, 3
)

SELECT
    sco.period_start
    ,EXTRACT(YEAR FROM sco.period_start) AS survey_year
    ,sco.region_id
    ,reg.region_short_name
    ,reg.is_national
    ,sco.measure_code
    ,COALESCE(dim.dimension_name, 'Overall experience') AS measure_name
    -- overall experience first, then the dimensions in the questionnaire's order
    ,CASE sco.measure_code
        WHEN 'overall_experience' THEN 0
        WHEN 'care_and_treatment' THEN 1
        WHEN 'participation' THEN 2
        WHEN 'respectful_treatment' THEN 3
        WHEN 'continuity' THEN 4
        WHEN 'information' THEN 5
        WHEN 'accessibility' THEN 6
        END AS measure_order
    ,sco.score
    ,sco.ci
    ,nat.national_score
    ,sco.score - nat.national_score AS deviation_from_national
    ,CASE
        WHEN reg.is_national THEN NULL
        WHEN sco.score - sco.ci > nat.national_score THEN 'Clearly above Sweden'
        WHEN sco.score + sco.ci < nat.national_score THEN 'Clearly below Sweden'
        ELSE 'Not clearly different'
        END AS comparison_to_national
    ,COALESCE(cc.centres_scored, 0) AS centres_scored
    ,COALESCE(cc.centres_clearly_below_national, 0) AS centres_clearly_below_national
    ,COALESCE(cc.centres_clearly_above_national, 0) AS centres_clearly_above_national
    ,SAFE_DIVIDE(cc.centres_clearly_below_national, cc.centres_scored) AS share_of_centres_clearly_below_national
FROM region_scores sco
INNER JOIN national nat USING (period_start, measure_code)
INNER JOIN {{ ref('dim_region') }} reg ON reg.region_id = sco.region_id
LEFT JOIN {{ ref('npe_dimension_translations') }} dim ON dim.dimension_code = sco.measure_code
LEFT JOIN centre_counts cc
    ON cc.period_start = sco.period_start
    AND cc.region_id = sco.region_id
    AND cc.measure_code = sco.measure_code
