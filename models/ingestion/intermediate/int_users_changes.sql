{{ config(materialized='incremental', incremental_strategy='append') }}

{#
    Append-only log of user changes, read from the nightly full snapshots in raw.users.
    A row is added when a user appears for the first time or when one of the attributes used by
    the KPI changes: province of residence, organization, eligibility. dim_users_scd turns these
    rows into versions.

    Incremental run: reads the batches loaded after the latest row written and compares each user
    to its latest row. A batch without any change writes nothing, so it is read again by the next
    run, where it still matches the latest rows and adds nothing.
#}

with

batches as (
    select
        id as user_id,
        loaded_at,
        province_of_residence,
        organization_id,
        len(eligible_programs) > 0 as has_eligible_programs
    from {{ source('raw', 'users') }}
    {% if is_incremental() %}
    where loaded_at > (select coalesce(max(loaded_at), '-infinity') from {{ this }})
    {% endif %}
),

{% if is_incremental() %}
latest_rows as (
    select * from {{ this }}
    qualify row_number() over (partition by user_id order by loaded_at desc) = 1
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
        (province_of_residence, organization_id, has_eligible_programs)
            is distinct from lag((province_of_residence, organization_id, has_eligible_programs))
            over (partition by user_id order by loaded_at) as is_change
    from rows_to_compare
)

select
    user_id,
    loaded_at,
    province_of_residence,
    organization_id,
    has_eligible_programs
from changes
where is_change and not is_already_written
