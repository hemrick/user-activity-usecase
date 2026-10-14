select organization_id, valid_from
from {{ ref('dim_organizations_scd') }}
qualify (organization_name, churned_at)
    is not distinct from lag((organization_name, churned_at))
    over (partition by organization_id order by valid_from)
