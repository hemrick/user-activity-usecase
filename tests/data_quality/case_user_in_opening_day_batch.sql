with cases as (
    select case_id, any_value(user_id) as user_id, min(emitted_at)::date as opened_date
    from {{ ref('stg_events__case_properties') }}
    group by case_id
),

users_by_day as (
    select id as user_id, {{ business_date('loaded_at') }} as batch_date
    from {{ source('raw', 'users') }}
)

select cases.*
from cases
inner join {{ ref('dim_calendar_months') }} as months
    on months.calendar_month = date_trunc('month', cases.opened_date)
    and months.is_reported
left join users_by_day
    on users_by_day.user_id = cases.user_id
    and users_by_day.batch_date = cases.opened_date
where users_by_day.user_id is null
