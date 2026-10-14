with latest_batch as (
    select id as organization_id, name as organization_name, churned_at
    from {{ source('raw', 'organizations') }}
    where loaded_at = (select max(loaded_at) from {{ source('raw', 'organizations') }})
),

current_versions as (
    select organization_id, organization_name, churned_at
    from {{ ref('dim_organizations_scd') }}
    where is_current
)

(select 'missing from the history' as issue, * from latest_batch
 except select 'missing from the history', * from current_versions)
union all
(select 'not in the latest batch', * from current_versions
 except select 'not in the latest batch', * from latest_batch)
