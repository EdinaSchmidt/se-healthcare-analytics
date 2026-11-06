{% macro stg_npe_dimensions(source_table, value_column) %}

WITH source AS (
    SELECT * FROM {{ source('patient_surveys', source_table) }}
)

,regions AS (
    SELECT * FROM {{ ref('regions')}}
)

,survey_translations AS (
    SELECT * FROM {{ ref('npe_survey_translations')}}
)

,dimension_translations AS (
    SELECT * FROM {{ ref('npe_dimension_translations')}}
)


,unpivoted AS (
    SELECT *
    FROM source
    UNPIVOT INCLUDE NULLS (
        {{ value_column }} FOR dimension_column IN (
            vard_och_behandling AS 'Vård och behandling'
            ,delaktighet AS 'Delaktighet'
            ,bemotande AS 'Bemötande'
            ,kontinuitet AS 'Kontinuitet'
            ,information AS 'Information'
            ,tillganglighet AS 'Tillgänglighet'
        )
    )
)


,renamed AS (
    SELECT 
        reg.region_id
        ,src.kommun AS municipality
        ,TRIM(REPLACE(src.halso_vardcentral, '\u00AD', '-')) AS health_center
        ,src.hsa_id AS health_center_id
        ,CAST(src.survey_period AS INT64) AS year
        ,DATE(CAST(src.survey_period AS INT64), 1, 1) AS period_start
        ,src.kommentar AS comment_sv
        ,s_tra.comment AS comment
        ,src.dimension_column AS dimension_sv
        ,d_tra.dimension_code AS dimension
        ,CAST(src.{{ value_column }} AS NUMERIC) AS {{ value_column }}
        ,src.aggregation_level AS aggregation_level_sv
        ,CASE src.aggregation_level
            WHEN 'Hälso-/vårdcentral' THEN 'health_center'
            WHEN 'Kommun' THEN 'municipality'
            WHEN 'Region' THEN 'region'
            END AS aggregation_level
        ,src.selection AS selection_sv
        ,CASE src.selection 
            WHEN 'Läkarbesök' THEN 'doctor_visit' 
            END AS selection
        ,src.respondent_threshold AS respondent_threshold_sv
        ,SAFE_CAST(REGEXP_EXTRACT(src.respondent_threshold, r'\d+') AS INT64) AS min_respondents_public


    FROM unpivoted src 
    LEFT JOIN regions reg ON TRIM(LOWER(src.region)) = TRIM(LOWER(reg.region_patient_surveys))
    LEFT JOIN survey_translations s_tra ON TRIM(src.kommentar) = TRIM(s_tra.comment_sv)
    LEFT JOIN dimension_translations d_tra on TRIM(src.dimension_column) = TRIM(d_tra.dimension_sv)
)


,final AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key([
            'aggregation_level'
            ,'region_id'
            ,'municipality'
            ,'health_center_id'
            ,'year'
            ,'dimension'
        ]) }} AS dimension_result_key
        ,*
    FROM renamed
)

SELECT * FROM final


{% endmacro %}