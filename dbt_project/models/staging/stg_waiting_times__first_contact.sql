WITH source AS (
    SELECT * FROM {{ source('waiting_times', 'first_contact') }}
)

,renamed AS (
    SELECT
        DATE(CAST(ar AS INT64), {{ swedish_month_number('manad') }}, 1) AS period_start
        ,CASE WHEN TRIM(vardcentral) = 'Alla vårdcentraler' THEN 'region' ELSE 'health_centre' END AS aggregation_level
        ,region AS region_name
        ,NULLIF(REPLACE(TRIM(vardcentral), '­', '-'), 'Alla vårdcentraler') AS health_centre_name -- the export writes hyphens as soft hyphens
        ,region = 'Alla regioner' AS is_national
        ,CASE typ
            WHEN 'Alla samtal' THEN 'all'
            WHEN 'Telefon' THEN 'phone'
            WHEN 'Chatt' THEN 'chat'
            END AS contact_type
        ,{{ parse_waiting_times_number('besvarade_samtal') }} AS answered_contacts
        ,{{ parse_waiting_times_number('totalt_antal') }} AS total_contacts
        ,{{ parse_waiting_times_number('andel_procent_besvarade_samtal', 'FLOAT64') }} AS answered_pct
    FROM source
    )

SELECT * FROM renamed
