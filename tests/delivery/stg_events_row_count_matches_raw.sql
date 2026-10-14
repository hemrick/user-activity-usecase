with expected as (
    select count(*) as n_events from {{ source('raw', 'events') }}
    where event_type = 'case_properties'
),

actual as (select count(*) as n_events from {{ ref('stg_events__case_properties') }})

select expected.n_events as expected_events, actual.n_events as actual_events
from expected, actual
where expected.n_events <> actual.n_events
