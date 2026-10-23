-- One row per care unit named in the waiting-times exports (either table), with its Kolada region
-- code. The exports identify units by name only, so region + name is the key.

WITH units AS (
    SELECT DISTINCT
        region_name
        ,health_centre_name
        ,'medical_assessment' AS source_table
    FROM {{ ref('stg_waiting_times__medical_assessment') }}
    WHERE aggregation_level = 'health_centre'

    UNION ALL

    SELECT DISTINCT
        region_name
        ,health_centre_name
        ,'first_contact' AS source_table
    FROM {{ ref('stg_waiting_times__first_contact') }}
    WHERE aggregation_level = 'health_centre'
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['reg.region_id', 'units.health_centre_name']) }} AS waiting_times_unit_id
    ,reg.region_id
    ,units.health_centre_name AS waiting_times_name
    ,LOGICAL_OR(units.source_table = 'medical_assessment') AS in_medical_assessment
    ,LOGICAL_OR(units.source_table = 'first_contact') AS in_first_contact
FROM units
LEFT JOIN {{ ref('regions') }} reg ON reg.region_waiting_times = units.region_name
GROUP BY 1, 2, 3
