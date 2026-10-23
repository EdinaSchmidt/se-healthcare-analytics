-- NPE results per survey and unit: response rate and overall experience. Units are SKR's own
-- aggregates at region, municipality and health-centre level, each level with a national row
-- (region_id '0000'). Never sum across levels. care_unit_id is the HSA-ID (health centres only).

WITH response_rates AS (
    SELECT * FROM {{ ref('stg_npe__response_rates') }}
)

,overall_experience AS (
    SELECT * FROM {{ ref('stg_npe__overal_experenece') }}
)

SELECT
    rr.period_start
    ,rr.measurement_sv
    ,rr.selection_sv
    ,rr.aggregation_level
    ,reg.region_id
    ,rr.municipality_name
    ,rr.hsa_id AS care_unit_id
    ,rr.is_national
    ,rr.surveys_sent
    ,rr.respondents
    ,rr.response_rate_pct
    ,oe.overall_experience_score
    ,oe.overall_experience_ci
    ,rr.suppression_reason
FROM response_rates rr
INNER JOIN overall_experience oe
    ON oe.period_start = rr.period_start
    AND oe.measurement_sv = rr.measurement_sv
    AND oe.selection_sv = rr.selection_sv
    AND oe.aggregation_level = rr.aggregation_level
    AND oe.region_name = rr.region_name
    AND oe.municipality_name IS NOT DISTINCT FROM rr.municipality_name
    AND oe.hsa_id IS NOT DISTINCT FROM rr.hsa_id
LEFT JOIN {{ ref('regions') }} reg ON reg.region_patient_surveys = rr.region_name
