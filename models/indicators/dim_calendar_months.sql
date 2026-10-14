{#
    One row per calendar month, from the first business date of the data to the reporting date.
    A month is reported when it is over (its last day is before the reporting date) and the data
    covers its last day (a user snapshot exists for that day).
#}

with

bounds as (
    select
        (select min(valid_from) from {{ ref('dim_users_scd') }}) as first_business_date,
        {{ business_date('max(loaded_at)') }} as last_covered_date,
        date '{{ var("reporting_date") }}' as reporting_date
    from {{ source('raw', 'users') }}
),

months as (
    select
        unnest(generate_series(
            date_trunc('month', first_business_date),
            date_trunc('month', reporting_date),
            interval 1 month
        ))::date as calendar_month
    from bounds
)

select
    months.calendar_month,
    last_day(months.calendar_month) as month_end_date,
    last_day(months.calendar_month) < bounds.reporting_date
        and last_day(months.calendar_month) <= bounds.last_covered_date as is_reported
from months
cross join bounds
