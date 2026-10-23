WITH source AS (
    SELECT * FROM {{ source('waiting_times', 'medical_assessment') }}
)

,renamed AS (
    SELECT
        DATE(CAST(ar AS INT64), {{ swedish_month_number('manad') }}, 1) AS period_start
        ,CASE WHEN TRIM(vardcentral) = 'Alla vårdcentraler' THEN 'region' ELSE 'health_centre' END AS aggregation_level
        ,region AS region_name
        ,NULLIF(REPLACE(TRIM(vardcentral), '­', '-'), 'Alla vårdcentraler') AS health_centre_name -- the export writes hyphens as soft hyphens
        ,region = 'Alla regioner' AS is_national
        ,{{ parse_waiting_times_number('antal_inom_0_dagar') }} AS assessed_same_day
        ,{{ parse_waiting_times_number('antal_inom_3_dagar') }} AS assessed_within_3_days -- includes same day
        ,{{ parse_waiting_times_number('antal_over_3_dagar') }} AS assessed_after_3_days -- empty in every export so far
        ,{{ parse_waiting_times_number('antal_valt_vanta_langre') }} AS chose_to_wait_longer
        ,{{ parse_waiting_times_number('totalt_antal') }} AS total_assessments
        ,{{ parse_waiting_times_number('medelvarde_vantetid', 'FLOAT64') }} AS wait_days_mean
        ,{{ parse_waiting_times_number('p10_vantetid', 'FLOAT64') }} AS wait_days_p10
        ,{{ parse_waiting_times_number('p25_vantetid', 'FLOAT64') }} AS wait_days_p25
        ,{{ parse_waiting_times_number('median_vantetid', 'FLOAT64') }} AS wait_days_median
        ,{{ parse_waiting_times_number('p75_vantetid', 'FLOAT64') }} AS wait_days_p75
        ,{{ parse_waiting_times_number('p90_vantetid', 'FLOAT64') }} AS wait_days_p90
        ,'X' IN (
            antal_inom_0_dagar, antal_inom_3_dagar, antal_over_3_dagar, antal_valt_vanta_langre, totalt_antal
            ,medelvarde_vantetid, p10_vantetid, p25_vantetid, median_vantetid, p75_vantetid, p90_vantetid
            ) AS has_suppressed_values
    FROM source
    )

SELECT * FROM renamed
