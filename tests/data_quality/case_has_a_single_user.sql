select case_id, count(distinct user_id) as n_users
from {{ ref('stg_events__case_properties') }}
group by case_id
having count(distinct user_id) > 1
