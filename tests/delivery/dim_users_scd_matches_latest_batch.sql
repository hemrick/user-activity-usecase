with latest_batch as (
    select
        id as user_id,
        province_of_residence,
        organization_id,
        len(eligible_programs) > 0 as has_eligible_programs
    from {{ source('raw', 'users') }}
    where loaded_at = (select max(loaded_at) from {{ source('raw', 'users') }})
),

current_versions as (
    select user_id, province_of_residence, organization_id, has_eligible_programs
    from {{ ref('dim_users_scd') }}
    where is_current
)

(select 'missing from the history' as issue, * from latest_batch
 except select 'missing from the history', * from current_versions)
union all
(select 'not in the latest batch', * from current_versions
 except select 'not in the latest batch', * from latest_batch)
