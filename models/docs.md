{% docs business_date %}
Business date, in the `America/Toronto` time zone (project variable `business_timezone`).
Users and organizations arrive as one full snapshot per night: the batch loaded on day D, around
01:20 local time, describes the state **at the end of day D − 1**. `loaded_at` is stored with a time
zone, so it is always converted to the business time zone before taking the date: the result does not depend
on the time zone of the machine running dbt. Event timestamps have no time zone and are assumed to
be in the business time zone already.
{% enddocs %}

{% docs valid_from %}
First business date on which this version applies (inclusive). See `business_date`.
{% enddocs %}

{% docs valid_to %}
First business date on which this version no longer applies (exclusive): the `valid_from` of the
next version. Null for the current version. A version applies on date D when
`valid_from <= D and (valid_to is null or D < valid_to)`.
{% enddocs %}

{% docs has_eligible_programs %}
True when the user is eligible to at least one program. The list of programs itself is not
modeled: its order is not stable in the source and no metric uses it.
{% enddocs %}

{% docs is_current %}
True for the latest version (`valid_to` is null).
{% enddocs %}

{% docs scd_history %}
History table (slowly changing dimension, type 2) built from the nightly full snapshots, in two steps:
- `int_<entity>_changes` (incremental, append-only): a row each time an entity appears for the first
  time or one of the modeled attributes changes. A run reads only the batches loaded after the
  latest row written. A batch loaded late has a recent `loaded_at`, so it is picked up by the next run.
- `dim_<entity>_scd` (table, rebuilt on every run): turns these rows into versions with `valid_from`,
  `valid_to` and `is_current`.

Attributes not modeled here remain available in the raw source. A correction of past batches is
applied with `dbt build --full-refresh`: the history is small (one row per change), so a
partial reprocessing mode is not worth its complexity.

Known limit: an entity that disappears from the snapshots keeps its last version as current
(disappearances are not modeled; a data quality test warns when a batch has fewer rows than the
previous one).
{% enddocs %}
