-- Exactly one year is flagged as latest, and it is the most recent year in the table.

WITH years AS (
    SELECT
        COUNT(DISTINCT CASE WHEN is_latest_year THEN period_year END) AS n_flagged_years
        ,MAX(CASE WHEN is_latest_year THEN period_year END) AS flagged_year
        ,MAX(period_year) AS max_year
    FROM {{ ref('rpt_primary_care_costs_by_region') }}
)

SELECT *
FROM years
WHERE n_flagged_years != 1
    OR flagged_year != max_year