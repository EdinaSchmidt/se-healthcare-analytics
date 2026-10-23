{% macro parse_waiting_times_number(column, data_type='INT64') -%}
    {#- Socialstyrelsen's waiting-times exports keep every value as text: decimals use a comma,
        missing values are two soft hyphens (U+00AD), 'X' is suppressed (too few patients)
        and 'N' can't be computed (no patients). Anything else that isn't a number fails the cast. -#}
    CAST(REPLACE(NULLIF(NULLIF(NULLIF({{ column }}, '­­'), 'X'), 'N'), ',', '.') AS {{ data_type }})
{%- endmacro %}


{% macro swedish_month_number(column) -%}
    CASE {{ column }}
        WHEN 'Januari' THEN 1
        WHEN 'Februari' THEN 2
        WHEN 'Mars' THEN 3
        WHEN 'April' THEN 4
        WHEN 'Maj' THEN 5
        WHEN 'Juni' THEN 6
        WHEN 'Juli' THEN 7
        WHEN 'Augusti' THEN 8
        WHEN 'September' THEN 9
        WHEN 'Oktober' THEN 10
        WHEN 'November' THEN 11
        WHEN 'December' THEN 12
        END
{%- endmacro %}
