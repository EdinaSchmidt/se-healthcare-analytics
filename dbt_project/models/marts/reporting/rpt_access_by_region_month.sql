-- Care guarantee follow-up per region and month: share of patients assessed the same day and within
-- 3 days, and share of calls/chats answered, against Sweden and the same month a year earlier.
-- Grain: one row per region (Sweden included) and month of the waiting-times exports; a region
-- without data that month still has a row, with NULL measures. Shares are 0-1.

WITH assessment AS (
    SELECT
        period_start
        ,region_id
        ,total_assessments
        ,assessed_same_day
        ,assessed_within_3_days
        ,chose_to_wait_longer
        ,wait_days_mean
        ,wait_days_median
        ,wait_days_p90
    FROM {{ ref('fct_medical_assessment') }}
    WHERE aggregation_level = 'region'
)

,contacts AS (
    SELECT
        period_start
        ,region_id
        ,answered_contacts
        ,total_contacts
    FROM {{ ref('fct_first_contact') }}
    WHERE aggregation_level = 'region'
        AND contact_type = 'all'
)

,months AS (
    SELECT period_start FROM assessment
    UNION DISTINCT
    SELECT period_start FROM contacts
)

,region_months AS (
    SELECT
        reg.region_id
        ,reg.region_short_name
        ,reg.is_national
        ,months.period_start
        ,ass.total_assessments
        ,ass.assessed_same_day
        ,ass.assessed_within_3_days
        ,ass.chose_to_wait_longer
        ,ass.wait_days_mean
        ,ass.wait_days_median
        ,ass.wait_days_p90
        ,SAFE_DIVIDE(ass.assessed_same_day, ass.total_assessments) AS same_day_share
        ,SAFE_DIVIDE(ass.assessed_within_3_days, ass.total_assessments) AS within_3_days_share
        ,con.answered_contacts
        ,con.total_contacts
        ,SAFE_DIVIDE(con.answered_contacts, con.total_contacts) AS contacts_answered_share
    FROM {{ ref('dim_region') }} reg
    CROSS JOIN months
    LEFT JOIN assessment ass ON ass.region_id = reg.region_id AND ass.period_start = months.period_start
    LEFT JOIN contacts con ON con.region_id = reg.region_id AND con.period_start = months.period_start
)

,national AS (
    SELECT
        period_start
        ,same_day_share
        ,within_3_days_share
        ,contacts_answered_share
    FROM region_months
    WHERE is_national
)

SELECT
    cur.region_id
    ,cur.region_short_name
    ,cur.is_national
    ,cur.period_start
    ,FORMAT_DATE('%b %Y', cur.period_start) AS period_label
    ,cur.period_start = MAX(cur.period_start) OVER () AS is_latest_month
    ,cur.total_assessments IS NOT NULL AS has_assessment_data
    ,cur.total_contacts IS NOT NULL AS has_contact_data
    ,cur.total_assessments
    ,cur.assessed_same_day
    ,cur.assessed_within_3_days
    ,cur.chose_to_wait_longer
    ,cur.wait_days_mean
    ,cur.wait_days_median
    ,cur.wait_days_p90
    ,cur.answered_contacts
    ,cur.total_contacts
    ,cur.same_day_share
    ,cur.within_3_days_share
    ,cur.contacts_answered_share
    ,nat.same_day_share AS national_same_day_share
    ,nat.within_3_days_share AS national_within_3_days_share
    ,nat.contacts_answered_share AS national_contacts_answered_share

    -- difference from Sweden in the same month, in share points (0.02 = 2 percentage points)
    ,cur.same_day_share - nat.same_day_share AS same_day_vs_national
    ,cur.within_3_days_share - nat.within_3_days_share AS within_3_days_vs_national
    ,cur.contacts_answered_share - nat.contacts_answered_share AS contacts_answered_vs_national

    -- the same month a year earlier: access is seasonal, so compare like months only
    ,prev.same_day_share AS same_day_share_previous_year
    ,prev.within_3_days_share AS within_3_days_share_previous_year
    ,prev.contacts_answered_share AS contacts_answered_share_previous_year
    ,cur.same_day_share - prev.same_day_share AS same_day_change_vs_previous_year
    ,cur.within_3_days_share - prev.within_3_days_share AS within_3_days_change_vs_previous_year
    ,cur.contacts_answered_share - prev.contacts_answered_share AS contacts_answered_change_vs_previous_year
FROM region_months cur
LEFT JOIN national nat ON nat.period_start = cur.period_start
LEFT JOIN region_months prev
    ON prev.region_id = cur.region_id
    AND prev.period_start = DATE_SUB(cur.period_start, INTERVAL 1 YEAR)
