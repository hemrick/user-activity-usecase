{{ config(materialized='incremental', incremental_strategy='append') }}

{#
    Append-only log of organization changes, read from the nightly full snapshots in
    raw.organizations. A row is added when an organization appears for the first time or when its
    name or churn date changes. Same logic as int_users_changes.
#}

with

batches as (
    select
        id as organization_id,
        loaded_at,
        name as organization_name,
        churned_at
    from {{ source('raw', 'organizations') }}
    {% if is_incremental() %}
    where loaded_at > (select coalesce(max(loaded_at), '-infinity') from {{ this }})
    {% endif %}
),

{% if is_incremental() %}
latest_rows as (
    select * from {{ this }}
    qualify row_number() over (partition by organization_id order by loaded_at desc) = 1
),
{% endif %}

rows_to_compare as (
    select *, false as is_already_written from batches
    {% if is_incremental() %}
    union all by name
    select *, true as is_already_written from latest_rows
    {% endif %}
),

changes as (
    select
        *,
        (organization_name, churned_at)
            is distinct from lag((organization_name, churned_at))
            over (partition by organization_id order by loaded_at) as is_change
    from rows_to_compare
)

select
    organization_id,
    loaded_at,
    organization_name,
    churned_at
from changes
where is_change and not is_already_written
