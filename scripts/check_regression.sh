#!/usr/bin/env bash
# Regression check of the indicator tables: shows what a model change moves in the published numbers.
#
#   ./scripts/check_regression.sh save      before the change: saves the current indicator tables
#   ./scripts/check_regression.sh compare   after the change: rebuilds, then lists every row that
#                                           differs from the saved tables (can be run several times)
#   ./scripts/check_regression.sh clean     once done: drops the saved tables
#
# A change is then accepted on purpose (e.g. a new enrolment definition) or rejected (nothing
# should have moved). Run from the repository root with the project environment active.
set -euo pipefail

MODE="${1:-}"
TABLES="activity_rate_by_province activity_rate_by_organization"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DATABASE="${DATABASE:-$ROOT/data/warehouse.duckdb}"

case "$MODE" in
    save)
        python - "$DATABASE" $TABLES <<'PY'
import sys
import duckdb

database, *tables = sys.argv[1:]
connection = duckdb.connect(database)
connection.sql("create schema if not exists regression_check")
for table in tables:
    connection.sql(f"create or replace table regression_check.{table} as select * from data_mart.{table}")
    rows = connection.sql(f"select count(*) from regression_check.{table}").fetchone()[0]
    print(f"saved {table} ({rows} rows)")
PY
        ;;
    compare)
        # Models only: the tests may legitimately fail on a deliberate change until they are updated.
        (cd "$ROOT" && dbt run --quiet)
        python - "$DATABASE" $TABLES <<'PY'
import sys
import duckdb

database, *tables = sys.argv[1:]
connection = duckdb.connect(database)
moved = False
for table in tables:
    differences = connection.sql(f"""
        (select 'before' as version, * from regression_check.{table}
         except all select 'before', * from data_mart.{table})
        union all
        (select 'after', * from data_mart.{table}
         except all select 'after', * from regression_check.{table})
        order by 2, 3, 1
    """)
    count = len(differences.fetchall())
    if count == 0:
        print(f"{table}: no difference")
    else:
        moved = True
        print(f"{table}: {count} differing rows")
        differences.show(max_rows=50)
sys.exit(1 if moved else 0)
PY
        ;;
    clean)
        python - "$DATABASE" <<'PY'
import sys
import duckdb

duckdb.connect(sys.argv[1]).sql("drop schema if exists regression_check cascade")
print("dropped the saved tables (schema regression_check)")
PY
        ;;
    *)
        echo "usage: $0 save|compare|clean" >&2
        exit 2
        ;;
esac
