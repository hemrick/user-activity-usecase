{{ config(severity='warn') }}

select
    cases.case_id,
    cases.user_id,
    cases.opened_date,
    user_versions.has_eligible_programs,
    organization_versions.churned_at
from {{ ref('fct_cases') }} as cases
inner join {{ ref('dim_users_scd') }} as user_versions
    on user_versions.user_sk = cases.user_sk
left join {{ ref('dim_organizations_scd') }} as organization_versions
    on organization_versions.organization_id = cases.organization_id
    and organization_versions.valid_from <= cases.opened_date
    and (organization_versions.valid_to is null or cases.opened_date < organization_versions.valid_to)
where not user_versions.has_eligible_programs
   or organization_versions.churned_at <= cases.opened_date
