# DATABASE PLAN
**Status (2026-10-01):** two independent SQL drafts supplied by the owner (from other AI sessions) are parked UNMODIFIED in `supabase/_drafts/`. Nothing is applied anywhere. Both were EXECUTED on PostgreSQL 16 with hand-written Supabase stand-ins (`supabase/_drafts/validation/stubs.sql`); neither has run on real Supabase.

| | `claude22/` (recommended base) | `files_zip/` |
|---|---|---|
| Files | 0001_enums ... 0006_storage_realtime, seed.sql, generate_seed.py | core_schema, rls, its own DATABASE_PLAN.md/BACKEND_HANDOFF.md |
| Size | 26 tables, 54 policies, 47 functions, 19 triggers | 19 tables, ~35 policies |
| Executes on PG16 | yes (incl. seed covering all 14 job states) | yes |
| Behaviour checks | 22/22 pass (`validation/behave_a*.sql`) | none written |
| Commission | `app_settings.commission_rate = 0`, `commission_status = pending_owner_decision` (configurable) | hardcoded placeholder 10% |
| Author access to repo | unknown | none (stated) |
Recommendation: base = claude22; keep files_zip only as reference. **Owner confirmation pending (D-024).**

## claude22 overview
Tables: profiles, customer_profiles, provider_profiles, provider_specialties, provider_service_areas, provider_availability, provider_portfolio, provider_services, categories, services, jobs, job_status_history, allowed_job_transitions (32 rows = state machine), inspections, inspection_photos, quotes, quote_items, payments, payment_events, invoices, invoice_line_items, reviews, disputes, notifications, audit_logs, app_settings. Workflow goes through SECURITY DEFINER RPCs (create_job, transition_job, cancel_job, complete_job, approve_quote, create_review, admin_* ...). Clients cannot write job status, roles, verification or rating counters directly (verified). Money = JOD numeric(…,3). Job states = exactly the 14 in the master prompt.

## Reconciliation with the frontend (do in Phase 22 prep)
| Frontend | DB | Status |
|---|---|---|
| Roles customer/provider/admin | `user_role` same; client insert policy allows only customer/provider | OK |
| Phone E.164 `+9627[789]XXXXXXX` | CHECK `^\+9627[789][0-9]{7}$` | identical |
| User status active/suspended | `account_status` active/suspended/deleted | superset, OK |
| Job states (14) | `job_status` enum | identical |
| "ratings" | table `reviews` | rename in UI types or alias |
| Registration (verify -> profile) | client inserts own profile with phone NULL | **GAP: verified phone never copied from auth.users (KI-016)** |
Other gaps listed by the draft authors: quote-expiry/cron wiring, PostGIS for distance search, storage policy tests, notification fan-out, invoice generation hardening.

## How to re-validate
`bash supabase/_drafts/validation/run.sh` (Linux + PostgreSQL 16, as root). Final proof: `supabase db reset` (Docker) or a scratch Supabase project.
