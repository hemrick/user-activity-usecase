{#
    One row per case, at its opening, with the province and organization of the user on the
    opening day. Province and organization are attributes of the user: the case reaches them
    through the history of the user.
#}

with

cases as (
    select
        case_id,
        any_value(user_id) as user_id,
        min(emitted_at) as opened_at,
        opened_at::date as opened_date,
        date_trunc('month', opened_at)::date as calendar_month
    from {{ ref('stg_events__case_properties') }}
    group by case_id
)

select
    cases.case_id,
    cases.user_id,
    cases.opened_at,
    cases.opened_date,
    cases.calendar_month,
    user_versions.user_sk,
    user_versions.province_of_residence,
    user_versions.organization_id
from cases
-- Left join: a case whose user has no version that day is kept, with a null province and
-- organization, instead of disappearing from the indicator (a data quality test raises it).
left join {{ ref('dim_users_scd') }} as user_versions
    on user_versions.user_id = cases.user_id
    and user_versions.valid_from <= cases.opened_date
    and (user_versions.valid_to is null or cases.opened_date < user_versions.valid_to)
