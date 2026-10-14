#!/usr/bin/env bash
# Delivery check: incremental runs must produce exactly the same tables as a full refresh.
#
# 1. Full refresh on all data              -> reference copy of each ingestion table
# 2. Rows after MAX_BATCH_DATE deleted      -> simulates the state of a past night
# 3. Incremental run                        -> catches up to the latest batch;   compared with 1
# 4. Second incremental run, no new batch   -> must add nothing;                 compared with 1
#
# Run from the repository root with the project environment active:  ./scripts/check_incremental.sh
# Note: it rebuilds the ingestion tables; they end up identical to a normal full refresh.
set -euo pipefail

MAX_BATCH_DATE="${MAX_BATCH_DATE:-2024-05-31}"
MODELS="int_users_changes int_organizations_changes stg_events__case_properties"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DATABASE="${DATABASE:-$ROOT/data/warehouse.duckdb}"

run_dbt() {
    (cd "$ROOT" && dbt run --quiet --select $MODELS "$@")
}

compare_with_reference() {
    local label="$1"
    python - "$DATABASE" "$label" $MODELS <<'PY'
import sys
import duckdb

database, label, *models = sys.argv[1:]
connection = duckdb.connect(database)
failed = False
for model in models:
    differences = connection.sql(f"""
        select count(*) from (
            (select * from data_mart.{model} except all select * from incremental_check.{model})
            union all
            (select * from incremental_check.{model} except all select * from data_mart.{model})
        )
    """).fetchone()[0]
    status = "OK" if differences == 0 else f"FAILED ({differences} differing rows)"
    failed = failed or differences > 0
    print(f"  {label:<32} {model:<34} {status}")
sys.exit(1 if failed else 0)
PY
}

echo "1. Full refresh (reference)"
run_dbt --full-refresh
python - "$DATABASE" $MODELS <<'PY'
import sys
import duckdb

database, *models = sys.argv[1:]
connection = duckdb.connect(database)
connection.sql("create schema if not exists incremental_check")
for model in models:
    connection.sql(f"create or replace table incremental_check.{model} as select * from data_mart.{model}")
PY

echo "2. Back to the state of $MAX_BATCH_DATE"
# The tables are append-only and each row only depends on earlier batches: deleting the rows after a
# date gives the same table as a full refresh run on that date.
python - "$DATABASE" "$MAX_BATCH_DATE" <<'PY'
import sys
import duckdb

database, max_batch_date = sys.argv[1:]
connection = duckdb.connect(database)
business_date = "((loaded_at at time zone 'America/Toronto')::date - 1)"
for table in ("int_users_changes", "int_organizations_changes"):
    connection.execute(f"delete from data_mart.{table} where {business_date} > ?::date", [max_batch_date])
connection.execute(
    "delete from data_mart.stg_events__case_properties where emitted_at >= ?::date + 1", [max_batch_date]
)
PY

echo "3. Incremental run"
run_dbt
compare_with_reference "incremental"

echo "4. Incremental run without new batch"
run_dbt
compare_with_reference "incremental, no new batch"

python - "$DATABASE" <<'PY'
import sys
import duckdb

duckdb.connect(sys.argv[1]).sql("drop schema incremental_check cascade")
PY
echo "All incremental runs match the full refresh."
