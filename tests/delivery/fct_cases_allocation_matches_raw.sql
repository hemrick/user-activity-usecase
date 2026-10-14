with cases as (
    select
        (data ->> 'case_id')::bigint as case_id,
        min((data ->> 'subject_user_id')::integer) as user_id,
        min(timestamp)::date as opened_date
    from {{ source('raw', 'events') }}
    where event_type = 'case_properties'
    group by 1
),

expected as (
    select cases.case_id, users.province_of_residence, users.organization_id
    from cases
    inner join {{ source('raw', 'users') }} as users
        on users.id = cases.user_id
        and {{ business_date('users.loaded_at') }} = cases.opened_date
)

select
    expected.case_id,
    expected.province_of_residence as expected_province,
    actual.province_of_residence as actual_province,
    expected.organization_id as expected_organization_id,
    actual.organization_id as actual_organization_id
from expected
left join {{ ref('fct_cases') }} as actual
    on actual.case_id = expected.case_id
where actual.case_id is null
   or actual.province_of_residence is distinct from expected.province_of_residence
   or actual.organization_id is distinct from expected.organization_id
