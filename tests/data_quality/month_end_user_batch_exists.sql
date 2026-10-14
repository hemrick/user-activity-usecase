with batch_dates as (
    select distinct {{ business_date('loaded_at') }} as batch_date
    from {{ source('raw', 'users') }}
)

select calendar_month, month_end_date
from {{ ref('dim_calendar_months') }}
where is_reported
  and month_end_date not in (select batch_date from batch_dates)
