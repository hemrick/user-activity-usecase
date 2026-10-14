{#
    Monthly User Activity Rate by province of residence, for reported months.
    Cases are counted in the province of the user on the day the case was opened; eligible
    users in their province on the last day of the month.
#}

with

reported_months as (
    select calendar_month
    from {{ ref('dim_calendar_months') }}
    where is_reported
),

cases_opened as (
    select
        calendar_month,
        province_of_residence as province,
        count(*) as count_of_cases_opened
    from {{ ref('fct_cases') }}
    where calendar_month in (select calendar_month from reported_months)
    group by all
),

enrolled_users as (
    select
        calendar_month,
        province_of_residence as province,
        count(*) filter (where is_enrolled) as count_of_enrolled_users
    from {{ ref('fct_user_month_end') }}
    group by all
),

counts as (
    select
        coalesce(enrolled_users.calendar_month, cases_opened.calendar_month) as calendar_month,
        coalesce(enrolled_users.province, cases_opened.province) as province,
        coalesce(enrolled_users.count_of_enrolled_users, 0) as count_of_enrolled_users,
        coalesce(cases_opened.count_of_cases_opened, 0) as count_of_cases_opened
    from enrolled_users
    full outer join cases_opened
        on cases_opened.calendar_month = enrolled_users.calendar_month
        and cases_opened.province = enrolled_users.province
)

select
    calendar_month,
    province,
    count_of_enrolled_users,
    count_of_cases_opened,
    count_of_cases_opened / nullif(count_of_enrolled_users, 0) as activity_rate
from counts
