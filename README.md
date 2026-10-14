# Monthly User Activity Rate: a dbt modeling use case

The dbt code behind a use case: a **monthly user activity rate** on a user base that keeps changing,
built test-first.

The full use case presentation is online: https://www.emerictrossat.com/user-activity-usecase

> **This repository is meant to be read, not run.** It ships no data and no `profiles.yml`. The
> models target DuckDB (`dbt-duckdb`), and every example value in the tests is synthetic.

## The metric

**Monthly User Activity Rate** = cases opened in the calendar month ÷ users enrolled on the last day
of that month. It is published at two grains:

| Table | One row per |
|---|---|
| `activity_rate_by_province` | month × province |
| `activity_rate_by_organization` | month × organization |

Users move between provinces and switch organizations, but past months must never change. Each side
of the rate takes the user's province and organization on its own date:

| Side | User's province / organization taken on… |
|---|---|
| Numerator: cases opened | the **day the case was opened** |
| Denominator: enrolled users | the **last day of the month** |

## From raw to the indicator

```text
raw.users         → dim_users_scd ─────────┐
raw.organizations → dim_organizations_scd ─┼→ fct_user_month_end ─┐
                    dim_calendar_months ───┘                      ├→ activity_rate_by_province
raw.events        → stg_events__case_properties → fct_cases ──────┘  activity_rate_by_organization
```

Three classic patterns:

1. **Generic events → dedicated tables** (`stg_events__case_properties`). The generic JSON events
   are flattened per event type, and tests on the JSON structure make any source change either
   harmless or loud.
2. **Nightly snapshots → slowly changing dimensions** (`int_*_changes` → `dim_*_scd`). Only the
   changes are kept, as versions with `valid_from` / `valid_to`.
3. **Granular facts → aggregated metrics** (`fct_cases`, `fct_user_month_end` → `activity_rate_by_*`).
   Each side of the rate is a reusable fact table that can be tested on its own.

## Versions and dependencies

| Component | Version | Why |
|---|---|---|
| `dbt-core` | 1.9.x (built with 1.9.4) | unit tests need dbt ≥ 1.8 |
| `dbt-duckdb` | 1.9.x (built with 1.9.3) | adapter; the SQL uses DuckDB syntax (`qualify`, `group by all`, `->>`, `union all by name`) |
| `dbt_utils` | 1.3.0 (`packages.yml`, install with `dbt deps`) | surrogate keys and tests: `unique_combination_of_columns`, `mutually_exclusive_ranges`, `expression_is_true` |
| Python `duckdb` | any recent version | used only by the scripts in `scripts/` |

To run it, you would need a `profiles.yml` with a `data_mart` profile pointing to a DuckDB database
that holds the three raw tables (`raw.users`, `raw.organizations`, `raw.events`, described in
`models/ingestion/staging/_sources.yml`). Then run `dbt deps` followed by `dbt build`.

## Repository layout

```text
dbt_project.yml        tags, materializations, variables
macros/                business_date: batch timestamp → business date
models/
  docs.md              shared docs blocks (business date, SCD validity)
  ingestion/           incremental: reads raw and keeps the history
    staging/           sources + stg_events__case_properties
    intermediate/      int_users_changes, int_organizations_changes (append-only change logs)
    history/           dim_users_scd, dim_organizations_scd
  indicators/          rebuilt in full every night
    dim_calendar_months.sql, fct_cases.sql, fct_user_month_end.sql
    aggregates/        activity_rate_by_province, activity_rate_by_organization
tests/
  generic/             reusable tests (no_batch_gap, relationships_same_batch, json_keys_present…)
  data_quality/        singular tests on what the sources deliver
  delivery/            singular tests on our own logic (recomputed from raw, reconciliation)
scripts/
  check_incremental.sh replays a past night incrementally; the result must equal a full rebuild
  check_regression.sh  diffs the indicator tables before and after a code change
```

Each model folder has a `_*__models.yml` (documentation and declared tests) and a
`_*__unit_tests.yml` (dbt unit tests on synthetic rows: the rules and edge cases of the metric).

## Testing framework

Tests are split by the question they answer, and selected by tag:

| | Data source monitoring (`tag:tests_data_quality`) | Delivery (`tag:tests_delivery`) |
|---|---|---|
| Question | Did something break in what the **sources** deliver? | Does **our code** compute the right thing? |
| Fails when | the data changes | the code changes |
| Who acts | data owner | developer |
| Where | `models/ingestion/staging/*.yml`, `tests/data_quality/` | unit tests, `models/**/*.yml` outside staging, `tests/delivery/` |

Severity: `error` when a failure would publish a wrong KPI, and `warn` when the data is still usable
but needs a look.
