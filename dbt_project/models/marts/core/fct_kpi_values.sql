SELECT
    kpi_id
    ,region_id
    ,period_start
    ,amount
FROM {{ ref('stg_kolada__kpi_values') }}
WHERE gender = 'T'