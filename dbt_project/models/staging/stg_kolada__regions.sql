WITH source AS (
    SELECT * FROM {{ source('kolada', 'regions') }}
)

,renamed AS (
    SELECT 
        id AS region_id
        ,title AS region_name
        ,id = '0000' AS is_national
    FROM source
    )

SELECT * FROM renamed