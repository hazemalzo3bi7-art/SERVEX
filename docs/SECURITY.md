# SECURITY
Status: Phase 0 — no auth/backend yet. Rules already in force: no secrets in source; `.env` git-ignored; only `EXPO_PUBLIC_*` vars reach the app and are PUBLIC; never ship service-role/payment-secret keys in the app; demo payments never collect real card data.
Planned (Phase 20/22): Supabase Auth; roles enforced by RLS not just UI; admin actions audited; input validation (zod or similar); upload validation (type/size); rate limiting at Edge/DB; backups; dependency audit in CI.

## Phase 2 (demo auth) — what is and is NOT secure
- Demo OTP is a known constant: auth here is a UI/flow prototype, NOT security. `DEMO_MODE` must be false for release.
- Implemented rules (tested): admin cannot be self-registered; OTP must be requested first; 5 wrong codes lock a phone for 60 s (in-memory); suspended users cannot sign in; inputs validated with zod; phone normalised to E.164.
- `Stack.Protected` guards are client-side only (Expo docs). Real authorisation = database RLS (draft claude22: RLS on all 26 tables, deny-by-default, column-level grants, SECURITY DEFINER RPCs for workflow; 22 behaviour checks pass on plain PostgreSQL 16).
- Open DB items before production: verified-phone copy gap (KI-016), real Supabase test, rate limiting at Edge/DB, backups, storage policy tests.
