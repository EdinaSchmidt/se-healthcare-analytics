-- Answered calls and chats per month and contact type ('all' = phone + chat): the export's own
-- region totals (aggregation_level = 'region', care_unit_id NULL, Sweden = '0000') and every care
-- unit. The two levels overlap, so never sum across them. Stockholm is not in the export.

SELECT
    fc.period_start
    ,fc.aggregation_level
    ,reg.region_id
    ,cu.care_unit_id
    ,fc.is_national
    ,fc.contact_type
    ,fc.answered_contacts
    ,fc.total_contacts
    ,fc.answered_pct
FROM {{ ref('stg_waiting_times__first_contact') }} fc
LEFT JOIN {{ ref('regions') }} reg ON reg.region_waiting_times = fc.region_name
LEFT JOIN {{ ref('dim_care_unit') }} cu
    ON cu.region_id = reg.region_id
    AND cu.waiting_times_name = fc.health_centre_name
