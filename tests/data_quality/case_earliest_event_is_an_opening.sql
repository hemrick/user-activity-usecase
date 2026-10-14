{{ config(severity='warn') }}

with earliest_events as (
    select case_id, emitted_at, status, triage_recommendation, issue_type
    from {{ ref('stg_events__case_properties') }}
    qualify row_number() over (partition by case_id order by emitted_at) = 1
)

select *
from earliest_events
where status <> 'pending'
   or triage_recommendation is not null
   or issue_type is not null
