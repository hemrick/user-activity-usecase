{% test no_batch_gap(model, column_name) %}

with batch_dates as (
    select distinct {{ business_date(column_name) }} as batch_date
    from {{ model }}
)

select
    batch_date,
    lag(batch_date) over (order by batch_date) as previous_batch_date
from batch_dates
qualify batch_date - previous_batch_date > 1

{% endtest %}
