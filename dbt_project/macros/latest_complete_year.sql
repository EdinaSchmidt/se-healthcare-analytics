{% macro latest_complete_year(model, required_columns) %}
   ( 
    SELECT MAX(year)
    FROM {{ model }}
    WHERE TRUE
    {%- for column in required_columns %}
        AND {{ column }} IS NOT NULL
    {%- endfor %}
   )
{%endmacro%}