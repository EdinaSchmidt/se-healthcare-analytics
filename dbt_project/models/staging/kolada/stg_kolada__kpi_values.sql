WITH source AS (
    SELECT * FROM {{ source('kolada', 'kpi_values') }}
)

,renamed AS (
    SELECT
        kpi AS kpi_id
        ,municipality AS region_id
        ,period AS year
        ,DATE(period, 1, 1) AS period_start
        ,gender AS gender_code
        ,CASE gender
            WHEN 'T' THEN 'total'
            WHEN 'K' THEN 'female'
            WHEN 'M' THEN 'male'
            END AS gender
        ,value AS amount
        ,LOWER(status) AS value_status
        ,isdeleted AS is_deleted
    FROM source
)

SELECT * FROM renamed