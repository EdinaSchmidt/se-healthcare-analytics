WITH source AS (
    SELECT * FROM {{ source('waiting_times', 'medical_assessment') }}
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
        ,CAST(src.ar AS INT64) AS year
        ,DATE(CAST(src.ar AS INT64), mon.month_num, 1) AS period_start
        ,CASE
            WHEN TRIM(src.totalt_antal) = 'X' THEN 'suppressed'
            WHEN TRIM(src.totalt_antal) = '\u00AD\u00AD' THEN 'no_data'
            WHEN TRIM(src.medelvarde_vantetid) = 'N' THEN 'no_patients'
            END AS suppression_code
        ,{{ clean_number('src.antal_inom_0_dagar', 'INT64') }} AS assessed_within_0_days
        ,{{ clean_number('src.antal_inom_3_dagar', 'INT64') }} AS assessed_within_3_days
        ,{{ clean_number('src.totalt_antal', 'INT64') }} AS total_assessments
        ,{{ clean_number('src.antal_valt_vanta_langre', 'INT64') }} AS chose_to_wait_longer
        ,{{ clean_number('src.medelvarde_vantetid', 'FLOAT64') }} AS wait_days_mean
        ,{{ clean_number('src.p10_vantetid', 'FLOAT64') }} AS wait_days_p10
        ,{{ clean_number('src.p25_vantetid', 'FLOAT64') }} AS wait_days_p25
        ,{{ clean_number('src.median_vantetid', 'FLOAT64') }} AS wait_days_median
        ,{{ clean_number('src.p75_vantetid', 'FLOAT64') }} AS wait_days_p75
        ,{{ clean_number('src.p90_vantetid', 'FLOAT64') }} AS wait_days_p90

    FROM source src
    LEFT JOIN months mon ON LOWER(TRIM(src.manad)) = LOWER(TRIM(mon.month_sv))
    LEFT JOIN regions reg ON LOWER(TRIM(src.region)) = LOWER(TRIM(reg.region_waiting_times))
)

,derived AS (
    SELECT
        *
        ,total_assessments - assessed_within_3_days AS assessed_over_3_days
    FROM renamed
)

SELECT * FROM derived