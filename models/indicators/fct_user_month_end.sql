{#
    One row per user present on the last day of each reported month, with their province and
    organization on that day and the enrolment flags. Every user present is kept; the enrolment
    filter is applied in the KPI tables.
#}

with

reported_months as (
    select calendar_month, month_end_date
    from {{ ref('dim_calendar_months') }}
    where is_reported
),

user_month_ends as (
    select
        user_versions.user_id,
        reported_months.calendar_month,
        reported_months.month_end_date,
        user_versions.user_sk,
        user_versions.province_of_residence,
        user_versions.organization_id,
        user_versions.has_eligible_programs
    from reported_months
    inner join {{ ref('dim_users_scd') }} as user_versions
        on user_versions.valid_from <= reported_months.month_end_date
        and (user_versions.valid_to is null or reported_months.month_end_date < user_versions.valid_to)
),

with_organization as (
    select
        user_month_ends.*,
        organization_versions.organization_id is not null
            and (
                organization_versions.churned_at is null
                or organization_versions.churned_at > user_month_ends.month_end_date
            ) as is_organization_active
    from user_month_ends
    left join {{ ref('dim_organizations_scd') }} as organization_versions
        on organization_versions.organization_id = user_month_ends.organization_id
        and organization_versions.valid_from <= user_month_ends.month_end_date
        and (
            organization_versions.valid_to is null
            or user_month_ends.month_end_date < organization_versions.valid_to
        )
)

select
    user_id,
    calendar_month,
    month_end_date,
    user_sk,
    province_of_residence,
    organization_id,
    has_eligible_programs,
    is_organization_active,
    has_eligible_programs and is_organization_active as is_enrolled
from with_organization
