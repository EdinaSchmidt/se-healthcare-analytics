{% macro clean_number(column, type='INT64') %}
    CASE
        WHEN TRIM({{ column }}) IN ('\u00AD\u00AD', 'X', 'N') THEN NULL
        ELSE CAST(REPLACE(TRIM({{ column }}), ',', '.') AS {{ type }})
    END
{% endmacro %}