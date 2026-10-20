SELECT 
    reg.region_id
    ,reg.region_name
    ,seed.region_short_name
    ,CASE WHEN reg.is_national THEN 'Sweden (national)' ELSE reg.region_name END AS region_display_name
    ,reg.is_national
FROM {{ ref('stg_kolada__regions') }} reg 
LEFT JOIN {{ ref('regions') }} seed USING(region_id)