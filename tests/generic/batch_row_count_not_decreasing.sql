{% test batch_row_count_not_decreasing(model, column_name) %}

with batch_counts as (
    select {{ column_name }} as batch, count(*) as row_count
    from {{ model }}
    group by 1
)

select
    batch,
    row_count,
    lag(row_count) over (order by batch) as previous_row_count
from batch_counts
qualify row_count < previous_row_count

{% endtest %}
