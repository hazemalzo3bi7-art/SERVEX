#!/usr/bin/env bash
# Executes the SQL drafts in a REAL PostgreSQL 16 using minimal stand-ins for Supabase (stubs.sql), then runs behaviour checks.
# For developers/AI agents on Linux (or Docker) with PostgreSQL installed. The project owner does not need to run this.
# Usage (as root):  bash supabase/_drafts/validation/run.sh        (from the repo root)
# Limitation: stubs are NOT Supabase. Final proof requires `supabase db reset` (Docker) or a scratch Supabase project.
set -u
REPO="$(cd "$(dirname "$0")/../../.." && pwd)"; D="$REPO/supabase/_drafts"; P="psql -X -q -v ON_ERROR_STOP=1"
chmod -R a+rX "$REPO/supabase" 2>/dev/null
pg_ctlcluster 16 main start 2>/dev/null; sleep 2
for db in dba dbb; do su postgres -c "dropdb --if-exists $db 2>/dev/null; createdb $db" && su postgres -c "$P -d $db -f $D/validation/stubs.sql" >/dev/null || { echo "stub setup failed"; exit 1; }; done
echo "== SET A: claude22"; for f in 0001_enums 0002_core_tables 0003_workflow_tables 0004_functions 0005_rls 0006_storage_realtime seed; do
  out=$(su postgres -c "$P -d dba -f $D/claude22/$f.sql" 2>&1) && echo "OK   $f.sql" || { echo "FAIL $f.sql"; echo "$out" | head -5; break; }; done
echo "== SET B: files_zip"; for f in 20260101000000_core_schema 20260101000100_rls; do
  out=$(su postgres -c "$P -d dbb -f $D/files_zip/$f.sql" 2>&1) && echo "OK   $f.sql" || { echo "FAIL $f.sql"; echo "$out" | head -5; break; }; done
echo "== Behaviour checks on SET A (every line must start with PASS)"
for t in behave_a behave_a_extra; do su postgres -c "psql -X -d dba -f $D/validation/$t.sql" 2>&1 | grep -E "NOTICE|ERROR" | sed 's/psql:[^ ]* NOTICE:  //'; done
