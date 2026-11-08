-- A flag must be NULL when its input is missing (NULL = can't be assessed)

SELECT region_short_name, year, assessable_flags, is_shortlisted
FROM {{ ref('rpt_region_expansion_shortlist') }}
WHERE (reasonable_wait_diff IS NULL AND is_reasonable_wait_below_national IS NOT NULL)
   OR (trust_diff IS NULL AND is_trust_below_national IS NOT NULL)
   OR (assessed_within_3_days_share_diff_from_national IS NULL AND is_access_below_national IS NOT NULL)
   OR (first_contact_answered_share_diff_from_national IS NULL AND is_first_call_below_national IS NOT NULL)