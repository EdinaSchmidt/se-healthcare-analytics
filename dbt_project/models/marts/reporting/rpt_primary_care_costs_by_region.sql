-- Primary care cost per inhabitant by region and year: N71007 (total) and its seven components.
-- Grain: one row per KPI, region and year. Includes the national row (is_national) as benchmark.

WITH costs AS (
    SELECT
        fct.kpi_id
        ,kpi.kpi_name
        ,kpi.kpi_short_name
        ,kpi.kpi_description
        ,kpi.cost_role
        ,fct.region_id
        ,reg.region_name
        ,reg.region_short_name
        ,reg.region_display_name
        ,reg.is_national
        ,fct.period_start
        ,EXTRACT(YEAR FROM fct.period_start) AS period_year
        ,MIN(EXTRACT(YEAR FROM fct.period_start)) OVER (PARTITION BY fct.region_id, fct.kpi_id) AS base_year
        ,MAX(EXTRACT(YEAR FROM fct.period_start)) OVER () AS latest_year
        ,fct.amount
        ,FIRST_VALUE(fct.amount) OVER(PARTITION BY fct.region_id, fct.kpi_id ORDER BY fct.period_start) AS amount_base_year

    FROM {{ ref('fct_kpi_values') }} fct 
    LEFT JOIN {{ ref('dim_kpi') }} kpi ON fct.kpi_id = kpi.kpi_id
    LEFT JOIN {{ ref('dim_region') }} reg ON fct.region_id = reg.region_id
    WHERE 
        kpi.cost_role IN ('total', 'component')
)

,national AS (
    SELECT 
        kpi_id
        ,period_start
        ,amount
    FROM costs
    WHERE is_national
)

,region_totals AS (
    SELECT
        region_id
        ,period_start
        ,amount AS region_total_amount
    FROM costs
    WHERE cost_role = 'total'
)

SELECT 
    costs.kpi_id
    ,costs.kpi_name
    ,costs.kpi_short_name
    ,costs.kpi_description
    ,costs.cost_role
    ,costs.region_id
    ,costs.region_name
    ,costs.region_short_name
    ,costs.region_display_name
    ,costs.is_national
    ,costs.period_start
    ,costs.period_year
    ,costs.period_year = costs.latest_year AS is_latest_year
    ,costs.amount
    ,costs.base_year
    ,costs.amount_base_year
    ,region_totals.region_total_amount
    ,national.amount AS national_amount

    -- growth: each region and KPI against its own first year (0-1)
    ,SAFE_DIVIDE(costs.amount, costs.amount_base_year) -1 AS growth_since_base_year

    -- deviation from the national figure, same KPI and year (0.05 = 5 % above)
    ,SAFE_DIVIDE(costs.amount, national.amount) - 1 AS deviation_from_national

    -- share of the region's total primary care cost (1 for the total row itself)
    ,SAFE_DIVIDE(costs.amount, region_totals.region_total_amount) AS share_of_region_total



FROM costs
LEFT JOIN national ON costs.kpi_id = national.kpi_id AND costs.period_start = national.period_start
LEFT JOIN region_totals ON costs.region_id = region_totals.region_id AND costs.period_start = region_totals.period_start