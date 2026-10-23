-- One row per NPE health centre (HSA-ID) with its Kolada region code, taken from the latest survey
-- the centre appears in.

WITH centres AS (
    SELECT
        npe.period_start
        ,reg.region_id
        ,npe.municipality_name
        ,npe.health_centre_name
        ,npe.hsa_id
    FROM {{ ref('stg_npe__response_rates') }} npe
    LEFT JOIN {{ ref('regions') }} reg ON reg.region_patient_surveys = npe.region_name
    WHERE npe.aggregation_level = 'health_centre'
        AND NOT npe.is_national
)

SELECT
    hsa_id
    ,region_id
    ,municipality_name
    ,health_centre_name
    ,period_start AS latest_survey_period_start
FROM centres
QUALIFY ROW_NUMBER() OVER (PARTITION BY hsa_id ORDER BY period_start DESC) = 1
