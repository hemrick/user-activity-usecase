-- One direction only: a user who disappeared from the snapshots stays in fct_user_month_end
-- (disappearances are not modeled).

with expected as (
    select
        months.calendar_month,
        users.id as user_id,
        users.province_of_residence,
        users.organization_id
    from {{ ref('dim_calendar_months') }} as months
    inner join {{ source('raw', 'users') }} as users
        on {{ business_date('users.loaded_at') }} = months.month_end_date
    where months.is_reported
)

select
    expected.*,
    actual.province_of_residence as actual_province,
    actual.organization_id as actual_organization_id
from expected
left join {{ ref('fct_user_month_end') }} as actual
    on actual.user_id = expected.user_id
    and actual.calendar_month = expected.calendar_month
where actual.user_id is null
   or actual.province_of_residence is distinct from expected.province_of_residence
   or actual.organization_id is distinct from expected.organization_id
