-- Waiting time to medical assessment per month: the export's own region totals
-- (aggregation_level = 'region', care_unit_id NULL, Sweden = '0000') and every care unit.
-- The two levels overlap, so never sum across them; region totals include units of every type.

SELECT
    ma.period_start
    ,ma.aggregation_level
    ,reg.region_id
    ,cu.care_unit_id
    ,ma.is_national
    ,ma.total_assessments
    ,ma.assessed_same_day
    ,ma.assessed_within_3_days
    ,ma.assessed_after_3_days
    ,ma.chose_to_wait_longer
    ,ma.wait_days_mean
    ,ma.wait_days_p10
    ,ma.wait_days_p25
    ,ma.wait_days_median
    ,ma.wait_days_p75
    ,ma.wait_days_p90
    ,ma.has_suppressed_values
FROM {{ ref('stg_waiting_times__medical_assessment') }} ma
LEFT JOIN {{ ref('regions') }} reg ON reg.region_waiting_times = ma.region_name
LEFT JOIN {{ ref('dim_care_unit') }} cu
    ON cu.region_id = reg.region_id
    AND cu.waiting_times_name = ma.health_centre_name
