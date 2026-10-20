-- The seven components should add up to N71007 per region and year
-- Returns rows where the gap is larger than 1 % of the total.

WITH sums AS (
    SELECT
        region_id,
        period_start,
        sum(CASE WHEN cost_role = 'component' THEN amount END) AS components_sum,
        max(CASE WHEN cost_role = 'total' THEN amount END) AS total_amount
    FROM {{ ref('rpt_primary_care_costs_by_region') }}
    GROUP BY region_id, period_start
)

SELECT *
FROM sums
WHERE ABS(components_sum - total_amount) > 0.01 * total_amount