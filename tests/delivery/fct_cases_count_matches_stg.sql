select
    (select count(distinct case_id) from {{ ref('stg_events__case_properties') }}) as expected_cases,
    (select count(*) from {{ ref('fct_cases') }}) as actual_cases
where expected_cases <> actual_cases
