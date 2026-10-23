-- One row per care unit: every NPE health centre and every unit in the waiting-times exports,
-- merged where int_care_unit_matches links them. care_unit_id is the HSA-ID when NPE knows the
-- unit, otherwise a hash of region and waiting-times name (the exports carry no ID).

WITH npe AS (
    SELECT * FROM {{ ref('int_npe__health_centres') }}
)

,waiting_times AS (
    SELECT
        units.*
        ,matches.hsa_id
        ,matches.match_method
    FROM {{ ref('int_waiting_times__unit_names') }} units
    LEFT JOIN {{ ref('int_care_unit_matches') }} matches USING (region_id, waiting_times_name)
)

,merged AS (
    SELECT
        COALESCE(npe.hsa_id, wt.waiting_times_unit_id) AS care_unit_id
        ,COALESCE(npe.region_id, wt.region_id) AS region_id
        ,COALESCE(npe.health_centre_name, wt.waiting_times_name) AS care_unit_name
        ,npe.hsa_id
        ,npe.health_centre_name AS npe_name
        ,npe.municipality_name
        ,wt.waiting_times_name
        ,npe.hsa_id IS NOT NULL AS in_npe
        ,wt.waiting_times_name IS NOT NULL AS in_waiting_times
        ,COALESCE(wt.in_medical_assessment, FALSE) AS in_medical_assessment
        ,COALESCE(wt.in_first_contact, FALSE) AS in_first_contact
        ,wt.match_method
    FROM npe
    FULL OUTER JOIN waiting_times wt ON wt.hsa_id = npe.hsa_id
)

SELECT
    care_unit_id
    ,region_id
    ,care_unit_name
    -- The waiting-times exports also list out-of-hours clinics, youth clinics, psychiatry, rehab
    -- and other units that are not listed-patient health centres. NPE only surveys health centres,
    -- so a match decides; otherwise the name does (checked against the 2025-26 exports).
    ,CASE
        WHEN in_npe THEN 'health_centre'
        WHEN REGEXP_CONTAINS(LOWER(waiting_times_name), r'jour|närakut|akutmottagning|kvälls|helgmottagning|1177') THEN 'out_of_hours'
        WHEN REGEXP_CONTAINS(LOWER(waiting_times_name), r'psykiatri|psykisk|\bbup\b|rehab|ungdomsmottagning|barnmorske|mödra|logoped|habilitering|barn- och ungdom|första linjen|mini-maria|sjukgymnastik|fysio|familjecentral|familjehälsa|barn- och familj|kvinnoklinik') THEN 'other'
        WHEN in_first_contact OR REGEXP_CONTAINS(LOWER(waiting_times_name), r'vårdcentral|hälsocentral|husläkar|läkarhus|familjeläkar|distriktsläkar|läkarmottagning|läkargrupp') THEN 'health_centre'
        ELSE 'other'
        END AS unit_type
    ,hsa_id
    ,npe_name
    ,municipality_name
    ,waiting_times_name
    ,in_npe
    ,in_waiting_times
    ,in_medical_assessment
    ,in_first_contact
    ,in_npe AND in_waiting_times AS is_matched
    ,match_method
FROM merged
