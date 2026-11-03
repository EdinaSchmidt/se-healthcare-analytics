SELECT 
    region_id
    ,region_id = '0000' is_national
    ,region_short_name
    ,IF(region_id = '0000', 'Sweden (national)', region_short_name) AS region_display_name
FROM  {{ ref('regions') }} 