{% macro care_unit_name_key(column) -%}
    {#- Matching key for care unit names that the waiting-times export and NPE spell differently:
        lower case, no 'ARKIVERAD' / 'Allmänmedicinska mottagningen' prefix, no ' S' suffix
        (Gävleborg's waiting-times names), 'vårdcentralen' read as 'vårdcentral' and single spaces.
        Only used to match units; display names stay as delivered. -#}
    TRIM(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(
        LOWER({{ column }}),
        r'^(arkiverad|allmänmedicinska? mottagning(en)?)\s+', ''),
        r'\s+s$', ''),
        r'(vård|hälso)centralen', r'\1central'),
        r'\s+', ' '))
{%- endmacro %}
