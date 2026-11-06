-- Regions with a journal system change must never get a TRUE/FALSE
-- waiting-time flag, since their waiting-time data is unreliable.
SELECT
    sl.region_id
    ,sl.region_short_name
    ,sl.is_access_below_national
    ,sl.is_first_call_below_national
FROM {{ ref('rpt_region_expansion_shortlist') }} sl
    INNER JOIN {{ ref('rpt_region_year_metrics') }} m
        ON sl.region_id = m.region_id
        AND sl.year = m.year
WHERE m.has_journal_system_change
    AND (
        sl.is_access_below_national IS NOT NULL
        OR sl.is_first_call_below_national IS NOT NULL
    )
