-- Every year must have exactly one national row to benchmark against.
SELECT
    year
    ,COUNTIF(is_national) AS national_rows
FROM {{ ref('rpt_region_year_metrics') }}
GROUP BY year
HAVING COUNTIF(is_national) != 1
