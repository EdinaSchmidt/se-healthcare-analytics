SELECT
    kpi_id
    ,gender
    ,region_id
    ,period_start
    ,amount
FROM {{ ref('stg_kolada__kpi_values') }}
WHERE 
    gender = 'total'

