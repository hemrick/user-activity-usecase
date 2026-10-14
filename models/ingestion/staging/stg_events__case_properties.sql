{{
    config(
        materialized='incremental',
        incremental_strategy='append',
    )
}}

{#
    `case_properties` events, one row per event, with the JSON payload flattened into typed
    columns. Append-only: an incremental run adds the events emitted after the latest one already
    loaded. Corrections and backfills go through --full-refresh.
#}

with

events as (
    select
        event_id,
        timestamp as emitted_at,
        data
    from {{ source('raw', 'events') }}
    where event_type = 'case_properties'
    {% if is_incremental() %}
      and timestamp > (select coalesce(max(emitted_at), '-infinity') from {{ this }})
    {% endif %}
)

select
    event_id,
    emitted_at,
    (data ->> 'case_id')::bigint as case_id,
    (data ->> 'subject_user_id')::integer as user_id,
    data ->> 'issue_type' as issue_type,
    data ->> 'triage_recommendation' as triage_recommendation,
    data ->> 'status' as status
from events
