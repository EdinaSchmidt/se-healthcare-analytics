-- The shortlist must describe exactly one year.
SELECT
    COUNT(DISTINCT year) AS years_in_shortlist
FROM {{ ref('rpt_region_expansion_shortlist') }}
HAVING COUNT(DISTINCT year) != 1
