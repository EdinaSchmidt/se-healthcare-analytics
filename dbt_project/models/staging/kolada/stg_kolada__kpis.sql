
WITH source AS (
    SELECT * FROM {{ source('kolada', 'kpis') }}
)

,renamed AS (
    SELECT 
        id AS kpi_id
        ,title AS title_sv
        ,TRIM(description) AS description_sv
        ,auspice AS provider_type_code
        ,CASE auspice
            WHEN 'T' THEN 'total'
            WHEN 'P' THEN 'private'
            WHEN 'E' THEN 'own_operation'   -- run by the region itself; a subset of O
            WHEN 'X' THEN 'not_applicable'
            WHEN 'O' THEN 'public'          -- all public providers (municipality, region, state)
            WHEN 'A' THEN 'other_than_own'
            END AS provider_type
        ,perspective AS perspective_sv
        ,operating_area AS operating_area_sv
        ,is_divided_by_gender

    FROM source 
    )


SELECT * FROM renamed