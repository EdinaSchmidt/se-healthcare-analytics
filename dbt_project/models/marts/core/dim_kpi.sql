SELECT 
    kpi.kpi_id,
    tra.kpi_name,
    tra.kpi_short_name,
    tra.kpi_description,
    tra.unit,
    tra.cost_role,
    tra.perspective,
    tra.operating_area,
    kpi.provider_type_code,
    kpi.provider_type,
    kpi.is_divided_by_gender,
    kpi.title_sv,
    kpi.description_sv
FROM {{ ref('stg_kolada__kpis') }} kpi 
LEFT JOIN {{ ref('kolada_kpi_translations') }} tra USING(kpi_id)