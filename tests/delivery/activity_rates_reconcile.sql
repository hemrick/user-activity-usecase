with facts as (
    select
        months.calendar_month,
        (select count(*) from {{ ref('fct_cases') }} as cases
          where cases.calendar_month = months.calendar_month) as cases,
        (select count(*) from {{ ref('fct_user_month_end') }} as users
          where users.calendar_month = months.calendar_month and users.is_enrolled) as enrolled_users
    from {{ ref('dim_calendar_months') }} as months
    where months.is_reported
),

by_province as (
    select calendar_month,
           sum(count_of_cases_opened) as cases,
           sum(count_of_enrolled_users) as enrolled_users
    from {{ ref('activity_rate_by_province') }}
    group by calendar_month
),

by_organization as (
    select calendar_month,
           sum(count_of_cases_opened) as cases,
           sum(count_of_enrolled_users) as enrolled_users
    from {{ ref('activity_rate_by_organization') }}
    group by calendar_month
)

select
    facts.calendar_month,
    facts.cases, by_province.cases as cases_by_province, by_organization.cases as cases_by_organization,
    facts.enrolled_users, by_province.enrolled_users as users_by_province, by_organization.enrolled_users as users_by_organization
from facts
left join by_province on by_province.calendar_month = facts.calendar_month
left join by_organization on by_organization.calendar_month = facts.calendar_month
where by_province.cases is distinct from facts.cases
   or by_organization.cases is distinct from facts.cases
   or by_province.enrolled_users is distinct from facts.enrolled_users
   or by_organization.enrolled_users is distinct from facts.enrolled_users
