# Backend Handoff (written by Backend Agent; NOT a replacement for docs/SESSION_HANDOFF.md)

## Honest state
- The existing PROJECT_APP repo was NOT available in the backend agent's sandbox (no README, docs/, package.json, Git). B0 audit was NOT performed. FILE_MAP/PROJECT_STATUS/DEVELOPMENT_LOG/SESSION_HANDOFF were NOT edited; ready-to-paste entries are in `docs/APPEND_TO_PROJECT_DOCS.md`.
- No Git checkpoint exists. No database was available, so NO SQL was executed and NO tests exist.

## Created (all under PROJECT_APP_backend/, to be copied into repo root)
- supabase/migrations/20260101000000_core_schema.sql — enums, 19 tables, transition matrix, job/rating triggers, generated quote totals
- supabase/migrations/20260101000100_rls.sql — RLS for every table, column grants, `approve_quote` RPC
- docs/DATABASE_PLAN.md, docs/BACKEND_HANDOFF.md, docs/APPEND_TO_PROJECT_DOCS.md
Modified/deleted: none. Planned but NOT created: DATABASE_SCHEMA.md, API_PLAN/CONTRACTS, SECURITY.md, COSTS.md, seed, tests, Zod, integration plan.

## Next tasks
N1. Copy folder into repo root; run B0 (read docs in the brief's order, `git status`, verification command, compare `src` types/enums/mock data against DATABASE_PLAN.md). Record conflicts.
N2. Validate SQL: `npx supabase start` then `npx supabase db reset` (needs Docker); fix any errors; or paste both files in order into a scratch Supabase project's SQL editor.
N3. Write SQL tests for transitions, RLS, ratings, quote approval (pgTAP via `supabase test db`).
N4. B13 deterministic seed (Amman/Irbid fictional data), B6/B7 contracts + Zod, B14 SECURITY.md, B16 integration plan, B18 COSTS.md (research current pricing, date it).
N5. Git: `git add supabase docs && git commit -m "checkpoint: backend schema foundation (draft)"`.

## NEXT SESSION PROMPT
You are the Backend/Data agent for PROJECT_APP (Jordan services marketplace; Expo/React Native/TypeScript frontend by another agent; Supabase/PostgreSQL backend). Work in the existing repo; do not restart or reset anything. Read README.md and docs/ (PROJECT_STATUS, PROJECT_ARCHITECTURE, FILE_MAP, DECISIONS, DEVELOPMENT_LOG, SESSION_HANDOFF, AI_INSTRUCTIONS) then docs/BACKEND_HANDOFF.md and docs/DATABASE_PLAN.md. Run git status and the project verification command. Draft SQL exists in supabase/migrations/ but was never executed: validate it first (supabase db reset), then reconcile with the frontend's real types and state names (14 job states must not change silently). Then do N3–N5 from BACKEND_HANDOFF.md. Avoid editing frontend files. Save everything to disk, update FILE_MAP, DEVELOPMENT_LOG, PROJECT_STATUS, SESSION_HANDOFF, commit, and report every file created/modified.
