{% test json_keys_present(model, column_name, keys) %}

select {{ column_name }}
from {{ model }}
where not list_has_all(
    json_keys({{ column_name }}),
    [{% for key in keys %}'{{ key }}'{% if not loop.last %}, {% endif %}{% endfor %}]
)

{% endtest %}
