
WITH source AS (
    SELECT * FROM {{ source('kolada', 'kpis') }}
)

,renamed AS (
    SELECT 
        id as kpi_id
        ,title AS title_sv
        ,TRIM(description) AS description_sv
        ,auspice AS provider_type_code
        ,CASE auspice
            WHEN 'T' THEN 'total'
            WHEN 'P' THEN 'private'
            WHEN 'E' THEN 'own_operation' -- E (own operation, egen regi) is care run by this region's own organisation, with its own staff and its own health centres. E is a subset of O
            WHEN 'X' THEN 'not_applicable'
            WHEN 'O' THEN 'public' -- O (public operation, offentlig regi) covers all providers in a municipality, region or the state.
            WHEN 'A' THEN 'other_than_own'
            END AS provider_type
        ,perspective AS perspective_sv
        ,operating_area AS operating_area_sv
        ,is_divided_by_gender

    FROM source 
    )


SELECT * FROM renamed