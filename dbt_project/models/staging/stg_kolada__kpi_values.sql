WITH source AS (
  SELECT * FROM {{ source('kolada', 'kpi_values') }}
)

,renamed AS (
  SELECT
    kpi AS kpi_id
    ,municipality AS region_id
    ,DATE(period, 1, 1) AS period_start
    ,gender
    ,value AS amount
  FROM source
  )


SELECT * FROM renamed