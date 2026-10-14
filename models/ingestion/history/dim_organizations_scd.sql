{#
    History of each organization (SCD type 2): one row per version, from the changes logged in
    int_organizations_changes. Same logic as dim_users_scd.
#}

with

versions as (
    select
        organization_id,
        organization_name,
        churned_at,
        {{ business_date('loaded_at') }} as valid_from
    from {{ ref('int_organizations_changes') }}
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key(['organization_id', 'valid_from']) }} as organization_sk,
        organization_id,
        organization_name,
        churned_at,
        valid_from,
        lead(valid_from) over (partition by organization_id order by valid_from) as valid_to
    from versions
)

select
    *,
    valid_to is null as is_current
from final
