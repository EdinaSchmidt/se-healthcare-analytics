WITH surveys AS (
    SELECT DISTINCT
        period_start
        ,measurement_sv
        ,selection_sv
    FROM {{ ref('stg_npe__questions') }}
)

SELECT
    svy.period_start
    ,svy.measurement_sv
    ,svy.selection_sv
    ,tra.measurement
    ,tra.selection
FROM surveys svy
LEFT JOIN {{ ref('npe_survey_translations') }} tra USING(measurement_sv, selection_sv)
