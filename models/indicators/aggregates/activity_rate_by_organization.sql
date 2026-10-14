{#
    Monthly User Activity Rate by organization, for reported months.
    Cases are counted in the organization of the user on the day the case was opened;
    enrolled users in their organization on the last day of the month. Organizations are grouped
    by id and shown with their current name.
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
        organization_id,
        count(*) as count_of_cases_opened
    from {{ ref('fct_cases') }}
    where calendar_month in (select calendar_month from reported_months)
    group by all
),

enrolled_users as (
    select
        calendar_month,
        organization_id,
        count(*) filter (where is_enrolled) as count_of_enrolled_users
    from {{ ref('fct_user_month_end') }}
    group by all
),

counts as (
    select
        coalesce(enrolled_users.calendar_month, cases_opened.calendar_month) as calendar_month,
        coalesce(enrolled_users.organization_id, cases_opened.organization_id) as organization_id,
        coalesce(enrolled_users.count_of_enrolled_users, 0) as count_of_enrolled_users,
        coalesce(cases_opened.count_of_cases_opened, 0) as count_of_cases_opened
    from enrolled_users
    full outer join cases_opened
        on cases_opened.calendar_month = enrolled_users.calendar_month
        and cases_opened.organization_id = enrolled_users.organization_id
),

current_names as (
    select organization_id, organization_name
    from {{ ref('dim_organizations_scd') }}
    where is_current
)

select
    counts.calendar_month,
    counts.organization_id,
    current_names.organization_name,
    counts.count_of_enrolled_users,
    counts.count_of_cases_opened,
    counts.count_of_cases_opened / nullif(counts.count_of_enrolled_users, 0) as activity_rate
from counts
left join current_names
    on current_names.organization_id = counts.organization_id
