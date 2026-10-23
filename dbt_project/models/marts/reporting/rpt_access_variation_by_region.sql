-- Is poor access a regional or a health-centre problem? Spread of the share assessed within 3 days
-- between the included health centres of each region (rpt_access_by_health_centre, latest 12
-- months), plus a split of all variation between centres into a between-region and a
-- within-region part. Grain: one row per region with included centres, plus Sweden (all centres).
--
-- The split is volume-weighted, with w = a centre's assessments, p = its share, P_r = its
-- region's pooled share and P = Sweden's:
--   total   = sum(w * (p - P)^2)   / sum(w)
--   between = sum(w * (P_r - P)^2) / sum(w)   (centres moved to their region's share)
--   within  = sum(w * (p - P_r)^2) / sum(w)   (centres around their own region)
-- between + within = total, so the two shares add up to 1.

WITH centres AS (
    SELECT
        region_id
        ,region_short_name
        ,care_unit_id
        ,total_assessments AS w
        ,within_3_days_share AS p
        ,region_within_3_days_share AS p_region
        ,national_within_3_days_share AS p_national
    FROM {{ ref('rpt_access_by_health_centre') }}
    WHERE is_included
)

,split AS (
    SELECT
        SAFE_DIVIDE(SUM(w * POW(p_region - p_national, 2)), SUM(w * POW(p - p_national, 2))) AS between_region_variance_share
        ,SAFE_DIVIDE(SUM(w * POW(p - p_region, 2)), SUM(w * POW(p - p_national, 2))) AS within_region_variance_share
        ,SQRT(SAFE_DIVIDE(SUM(w * POW(p - p_national, 2)), SUM(w))) AS centre_sd
        ,SQRT(SAFE_DIVIDE(SUM(w * POW(p_region - p_national, 2)), SUM(w))) AS between_region_sd
        ,SQRT(SAFE_DIVIDE(SUM(w * POW(p - p_region, 2)), SUM(w))) AS within_region_sd
    FROM centres
)

,with_percentiles AS (
    -- each region's centres, and every centre again under Sweden ('0000')
    SELECT
        grouped.*
        ,PERCENTILE_CONT(grouped.p, 0.1) OVER (PARTITION BY grouped.region_id) AS p10
        ,PERCENTILE_CONT(grouped.p, 0.25) OVER (PARTITION BY grouped.region_id) AS p25
        ,PERCENTILE_CONT(grouped.p, 0.5) OVER (PARTITION BY grouped.region_id) AS median
        ,PERCENTILE_CONT(grouped.p, 0.75) OVER (PARTITION BY grouped.region_id) AS p75
        ,PERCENTILE_CONT(grouped.p, 0.9) OVER (PARTITION BY grouped.region_id) AS p90
    FROM (
        SELECT region_id, w, p, p_region AS p_group FROM centres
        UNION ALL
        SELECT '0000' AS region_id, w, p, p_national AS p_group FROM centres
        ) grouped
)

,regions AS (
    SELECT
        region_id
        ,COUNT(*) AS centres_included
        ,SUM(w) AS total_assessments
        ,ANY_VALUE(p_group) AS within_3_days_share
        ,MIN(p) AS min_share
        ,ANY_VALUE(p10) AS p10_share
        ,ANY_VALUE(p25) AS p25_share
        ,ANY_VALUE(median) AS median_share
        ,ANY_VALUE(p75) AS p75_share
        ,ANY_VALUE(p90) AS p90_share
        ,MAX(p) AS max_share
        -- how far this region's centres sit from their own region's share (volume-weighted)
        ,SQRT(SAFE_DIVIDE(SUM(w * POW(p - p_group, 2)), SUM(w))) AS sd_share
    FROM with_percentiles
    GROUP BY 1
)

SELECT
    regions.region_id
    ,reg.region_short_name
    ,reg.is_national
    ,regions.centres_included
    ,regions.total_assessments
    ,regions.within_3_days_share
    ,nat.within_3_days_share AS national_within_3_days_share
    ,regions.within_3_days_share - nat.within_3_days_share AS within_3_days_vs_national
    ,regions.min_share
    ,regions.p10_share
    ,regions.p25_share
    ,regions.median_share
    ,regions.p75_share
    ,regions.p90_share
    ,regions.max_share
    ,regions.p90_share - regions.p10_share AS p10_p90_range
    ,regions.sd_share
    ,split.between_region_variance_share
    ,split.within_region_variance_share
    ,split.centre_sd
    ,split.between_region_sd
    ,split.within_region_sd
    ,(SELECT ANY_VALUE(window_label) FROM {{ ref('rpt_access_by_health_centre') }}) AS window_label
FROM regions
CROSS JOIN split
INNER JOIN {{ ref('dim_region') }} reg ON reg.region_id = regions.region_id
LEFT JOIN regions nat ON nat.region_id = '0000'
