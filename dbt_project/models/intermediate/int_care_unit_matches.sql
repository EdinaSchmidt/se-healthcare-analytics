-- Links NPE health centres (HSA-ID) to waiting-times units (known by name only), one to one.
-- Automatic matches compare name keys (macro care_unit_name_key) within the same region:
--   step 1: the full names
--   step 2: the waiting-times name without a trailing ', <town>'
--   step 3: both names without a trailing ', <town>'
-- Each NPE centre keeps its earliest step; a pair is dropped when either side still has more than
-- one candidate. Hand-checked pairs from the care_unit_match_overrides seed replace automatic ones.

WITH npe AS (
    SELECT
        hsa_id
        ,region_id
        ,{{ care_unit_name_key('health_centre_name') }} AS name_key
        ,{{ care_unit_name_key("REGEXP_REPLACE(health_centre_name, r',[^,]*$', '')") }} AS name_key_without_town
    FROM {{ ref('int_npe__health_centres') }}
)

,waiting_times AS (
    SELECT
        region_id
        ,waiting_times_name
        ,{{ care_unit_name_key('waiting_times_name') }} AS name_key
        ,{{ care_unit_name_key("REGEXP_REPLACE(waiting_times_name, r',[^,]*$', '')") }} AS name_key_without_town
    FROM {{ ref('int_waiting_times__unit_names') }}
)

,candidates AS (
    SELECT npe.hsa_id, wt.region_id, wt.waiting_times_name, 1 AS match_step
    FROM npe
    INNER JOIN waiting_times wt ON wt.region_id = npe.region_id AND wt.name_key = npe.name_key

    UNION ALL

    SELECT npe.hsa_id, wt.region_id, wt.waiting_times_name, 2 AS match_step
    FROM npe
    INNER JOIN waiting_times wt ON wt.region_id = npe.region_id AND wt.name_key_without_town = npe.name_key

    UNION ALL

    SELECT npe.hsa_id, wt.region_id, wt.waiting_times_name, 3 AS match_step
    FROM npe
    INNER JOIN waiting_times wt ON wt.region_id = npe.region_id AND wt.name_key_without_town = npe.name_key_without_town
)

,earliest_step AS (
    SELECT DISTINCT hsa_id, region_id, waiting_times_name, match_step
    FROM candidates
    QUALIFY match_step = MIN(match_step) OVER (PARTITION BY hsa_id)
)

,automatic AS (
    SELECT
        hsa_id
        ,region_id
        ,waiting_times_name
        ,IF(match_step = 1, 'same_name', 'without_town') AS match_method
    FROM earliest_step
    QUALIFY COUNT(*) OVER (PARTITION BY hsa_id) = 1
        AND COUNT(*) OVER (PARTITION BY region_id, waiting_times_name) = 1
)

,overrides AS (
    SELECT
        hsa_id
        ,region_id
        ,waiting_times_name
        ,'manual' AS match_method
    FROM {{ ref('care_unit_match_overrides') }}
)

SELECT * FROM overrides

UNION ALL

SELECT automatic.*
FROM automatic
WHERE NOT EXISTS (SELECT 1 FROM overrides WHERE overrides.hsa_id = automatic.hsa_id)
    AND NOT EXISTS (
        SELECT 1 FROM overrides
        WHERE overrides.region_id = automatic.region_id
            AND overrides.waiting_times_name = automatic.waiting_times_name
    )
