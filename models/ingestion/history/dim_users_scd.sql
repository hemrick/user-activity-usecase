{#
    History of each user (SCD type 2): one row per version, from the changes logged in
    int_users_changes. Rebuilt on every run: the input is small (one row per change).
#}

with

versions as (
    select
        user_id,
        province_of_residence,
        organization_id,
        has_eligible_programs,
        {{ business_date('loaded_at') }} as valid_from
    from {{ ref('int_users_changes') }}
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key(['user_id', 'valid_from']) }} as user_sk,
        user_id,
        province_of_residence,
        organization_id,
        has_eligible_programs,
        valid_from,
        lead(valid_from) over (partition by user_id order by valid_from) as valid_to
    from versions
)

select
    *,
    valid_to is null as is_current
from final
