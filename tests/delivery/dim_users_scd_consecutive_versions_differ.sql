select user_id, valid_from
from {{ ref('dim_users_scd') }}
qualify (province_of_residence, organization_id, has_eligible_programs)
    is not distinct from lag((province_of_residence, organization_id, has_eligible_programs))
    over (partition by user_id order by valid_from)
