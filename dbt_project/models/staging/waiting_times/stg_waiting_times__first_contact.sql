WITH source AS (
    SELECT * FROM {{ source('waiting_times', 'first_contact') }}
)

,months AS (
    SELECT * FROM {{ ref('month_translations') }}
)

,regions AS (
    SELECT * FROM {{ ref('regions') }}
)

,renamed AS (
    SELECT
        reg.region_id
        ,TRIM(REPLACE(src.vardcentral, '\u00AD', '-')) AS health_center
        ,TRIM(src.typ) AS type_sv
        ,CASE TRIM(src.typ)
            WHEN 'Alla samtal' THEN 'all_calls'
            WHEN 'Chatt' THEN 'chat'
            WHEN 'Telefon' THEN 'telephone'
            END AS type
        ,CAST(src.ar AS INT64) AS year
        ,DATE(CAST(src.ar AS INT64), mon.month_num, 1) AS period_start
        ,CASE
            WHEN TRIM(src.totalt_antal) = 'X' THEN 'suppressed'
            WHEN TRIM(src.totalt_antal) = '\u00AD\u00AD' THEN 'no_data'
            END AS suppression_code
        ,{{ clean_number('src.besvarade_samtal', 'INT64') }} AS answered_calls
        ,{{ clean_number('src.totalt_antal', 'INT64') }} AS total_calls

    FROM source src
    LEFT JOIN months mon ON LOWER(TRIM(src.manad)) = LOWER(TRIM(mon.month_sv))
    LEFT JOIN regions reg ON LOWER(TRIM(src.region)) = LOWER(TRIM(reg.region_waiting_times))
)

SELECT * FROM renamed