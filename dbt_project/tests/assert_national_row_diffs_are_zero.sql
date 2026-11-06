-- The national row compared with itself must give zero differences.
-- A non-zero value means the national benchmark join picked up the wrong row.
-- Waiting-time diffs are excluded: their benchmark is built from regions not
-- changing journal systems (matching Socialstyrelsen), so it deliberately
-- differs from the raw national row.
SELECT
    year
    ,reasonable_wait_diff
    ,trust_diff
    ,purchase_share_diff
    ,accessibility_score_diff
    ,continuity_score_diff
FROM {{ ref('rpt_region_year_metrics') }}
WHERE is_national
    AND (
        ABS(COALESCE(reasonable_wait_diff, 0)) > 1e-9
        OR ABS(COALESCE(trust_diff, 0)) > 1e-9
        OR ABS(COALESCE(purchase_share_diff, 0)) > 1e-9
        OR ABS(COALESCE(accessibility_score_diff, 0)) > 1e-9
        OR ABS(COALESCE(continuity_score_diff, 0)) > 1e-9
    )