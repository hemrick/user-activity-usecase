{% test relationships_same_batch(model, column_name, to, field, batch_column) %}

select child.{{ column_name }}, child.{{ batch_column }}
from {{ model }} as child
left join {{ to }} as parent
    on parent.{{ field }} = child.{{ column_name }}
    and parent.{{ batch_column }} = child.{{ batch_column }}
where child.{{ column_name }} is not null
  and parent.{{ field }} is null

{% endtest %}
