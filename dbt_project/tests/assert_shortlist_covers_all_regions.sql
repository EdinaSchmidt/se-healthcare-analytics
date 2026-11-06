-- Every non-national region in dim_region must appear in the shortlist.
-- Catches regions silently dropped by a join or filter.
SELECT
    reg.region_id
    ,reg.region_short_name
FROM {{ ref('dim_region') }} reg
    LEFT JOIN {{ ref('rpt_region_expansion_shortlist') }} sl
        ON reg.region_id = sl.region_id
WHERE NOT reg.is_national
    AND sl.region_id IS NULL
