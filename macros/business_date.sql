{% macro business_date(loaded_at_column) -%}
    (({{ loaded_at_column }} at time zone '{{ var("business_timezone") }}')::date - 1)
{%- endmacro %}
