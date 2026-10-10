# SESSION HANDOFF
## Project
PROJECT_APP (temporary name). Brand CANDIDATE: "Servex" (logo in docs/brand/) — NOT confirmed by owner.
## Date
2026-10-01
## Current Phase
PHASE 2 — Authentication & Roles (demo): **COMPLETE** (Phases 0, 1 complete). Phase 3 NOT started.
## Current Step
Phase 2 finished, tested, documented, tagged `phase-2-complete`. Backend SQL drafts from the owner parked + validated.
## Product Summary
Premium on-demand local services marketplace, Jordan (Amman, Irbid) first. Customer picks service + location, compares nearby providers, CHOOSES one, requests; provider accepts, travels, inspects, quotes; customer approves + demo-pays; work, invoice, ratings, history. Separate provider/admin experiences. Arabic-first RTL, English later. Prototype = in-memory demo data; later Supabase, real payments, maps, push.
## What Was Completed
Phase 0: Expo SDK 57 project, folders, i18n, docs. Phase 1: design tokens, IBM Plex Sans Arabic, RTL, UI kit (AppText, Button, Card, TextField, Skeleton, StateView, Toast, BottomSheet, OptionCard), dev preview. Phase 2: phone+demo-OTP auth (AuthService interface + in-memory impl, zustand store, zod schemas), login/verify/register screens, role guards (Stack.Protected), role home stubs with logout, 24 unit tests, 10-step Playwright e2e, 2 real bugs fixed (wrong "invalid name" message for missing role; role card not exposed via aria-checked on web). Backend: owner's two SQL drafts parked unmodified in supabase/_drafts/, executed on PostgreSQL 16 with Supabase stand-ins; claude22 passes 22/22 behaviour checks.
## Files Created
See FILE_MAP.md. Phase 2: src/types/auth.ts, src/utils/phone.ts, src/features/auth/*, src/services/{auth,demo}/*, src/state/authStore.ts, src/components/ui/OptionCard.tsx, src/app/{login,verify,register}.tsx, src/app/{customer,provider,admin}/_layout.tsx, tests/unit/*, tests/serve_dist.py, tests/auth_smoke.py, supabase/_drafts/**, docs/brand/servex_logo_candidate.png.
## Files Modified
src/app/_layout.tsx (guards), src/app/index.tsx (redirect), src/i18n/* (auth/error keys, t() params, removed phase0.* keys), src/components/ui/{Button,TextField,index}.tsx (aria props, multiline), package.json (zustand, zod, tsx, @types/node, test script), tsconfig.json (types: node), docs/*, README.md.
## Files Deleted
src/components/ScreenPlaceholder.tsx (replaced by RoleHome), tests/nav_smoke.py (old role picker gone).
## Current Project Tree
```
.env.example
.gitignore
.vscode/extensions.json
.vscode/settings.json
AGENTS.md
LICENSE
README.md
app.json
assets/images/android-icon-background.png
assets/images/android-icon-foreground.png
assets/images/android-icon-monochrome.png
assets/images/favicon.png
assets/images/icon.png
assets/images/splash-icon.png
docs/AI_INSTRUCTIONS.md
docs/API_PLAN.md
docs/CHANGELOG.md
docs/DATABASE_PLAN.md
docs/DECISIONS.md
docs/DEPLOYMENT.md
docs/DEVELOPMENT_LOG.md
docs/ENVIRONMENT.md
docs/FILE_MAP.md
docs/KNOWN_ISSUES.md
docs/PROJECT_ARCHITECTURE.md
docs/PROJECT_STATUS.md
docs/RESEARCH.md
docs/ROADMAP.md
docs/SECURITY.md
docs/SESSION_HANDOFF.md
docs/TESTING.md
docs/brand/servex_logo_candidate.png
eslint.config.js
package-lock.json
package.json
src/app/+html.tsx
src/app/_layout.tsx
src/app/admin/_layout.tsx
src/app/admin/index.tsx
src/app/customer/_layout.tsx
src/app/customer/index.tsx
src/app/dev/components.tsx
src/app/index.tsx
src/app/login.tsx
src/app/provider/_layout.tsx
src/app/provider/index.tsx
src/app/register.tsx
src/app/verify.tsx
src/components/ui/AppText.tsx
src/components/ui/BottomSheet.tsx
src/components/ui/Button.tsx
src/components/ui/Card.tsx
src/components/ui/OptionCard.tsx
src/components/ui/Skeleton.tsx
src/components/ui/StateView.tsx
src/components/ui/TextField.tsx
src/components/ui/Toast.tsx
src/components/ui/index.ts
src/constants/theme.ts
src/features/admin/.gitkeep
src/features/auth/AuthScreen.tsx
src/features/auth/RoleHome.tsx
src/features/auth/homeFor.ts
src/features/auth/schemas.ts
src/features/customer/.gitkeep
src/features/invoices/.gitkeep
src/features/jobs/.gitkeep
src/features/notifications/.gitkeep
src/features/payments/.gitkeep
src/features/provider/.gitkeep
src/features/ratings/.gitkeep
src/hooks/.gitkeep
src/i18n/ar.ts
src/i18n/en.ts
src/i18n/index.ts
src/i18n/rtl.ts
src/services/auth/index.ts
src/services/auth/memoryAuthService.ts
src/services/auth/types.ts
src/services/demo/seed.ts
src/state/authStore.ts
src/types/auth.ts
src/utils/phone.ts
supabase/_drafts/claude22/0001_enums.sql
supabase/_drafts/claude22/0002_core_tables.sql
supabase/_drafts/claude22/0003_workflow_tables.sql
supabase/_drafts/claude22/0004_functions.sql
supabase/_drafts/claude22/0005_rls.sql
supabase/_drafts/claude22/0006_storage_realtime.sql
supabase/_drafts/claude22/generate_seed.py
supabase/_drafts/claude22/seed.sql
supabase/_drafts/claude22/static_check.py
supabase/_drafts/files_zip/20260101000000_core_schema.sql
supabase/_drafts/files_zip/20260101000100_rls.sql
supabase/_drafts/files_zip/APPEND_TO_PROJECT_DOCS.md
supabase/_drafts/files_zip/BACKEND_HANDOFF.md
supabase/_drafts/files_zip/DATABASE_PLAN.md
supabase/_drafts/validation/behave_a.sql
supabase/_drafts/validation/behave_a_extra.sql
supabase/_drafts/validation/run.sh
supabase/_drafts/validation/stubs.sql
tests/auth_smoke.py
tests/design_smoke.py
tests/serve_dist.py
tests/unit/authService.test.ts
tests/unit/authStore.test.ts
tests/unit/phone.test.ts
tsconfig.json
```
## Architecture State
See PROJECT_ARCHITECTURE.md (UI layer, Auth layer, Backend). UI -> services interface -> (in-memory now / Supabase in Phase 22). NOT yet built: central job state machine, central demo data for services/providers/jobs (only auth demo users exist), pricing engine, notifications, any real data screens.
## Current User Flows
Fresh visit -> /login (demo box shows numbers + code) -> phone -> /verify (code 123456) -> existing user: role home (greeting + logout); new user: /register (name + role customer/provider) -> role home. Unauthenticated deep links to /customer /provider /admin are redirected to login; a signed-in customer cannot open admin/provider (verified). Dev preview at /dev/components.
## Data / State
zustand auth store (user, pendingPhone, verifiedPhone, busy, errorKey) — in memory only (reload = logged out, KI-012). Demo users: admin 0790000001, customer 0790000002, provider 0790000003; OTP 123456.
## Tests Run
tsc, eslint, `npm test` (24), tests/auth_smoke.py (10 steps), tests/design_smoke.py, Android+web export (Phase 1; web re-exported in Phase 2), DB: `bash supabase/_drafts/validation/run.sh`.
## Test Results
All PASS. NOT tested: real phone/Expo Go, native RTL, iOS, dark mode, screen readers, real Supabase.
## Known Bugs
None functional. KI-001, KI-007..KI-018 in KNOWN_ISSUES.md (notably KI-014 DEMO_MODE, KI-016 verified-phone-not-copied DB gap).
## Known Limitations
Sandbox: no device/emulator; Expo online API blocked (expo-doctor never run). DB validated on plain PostgreSQL 16 with stand-ins only. UX study of Careem/Uber/Wolt/Talabat/Airbnb still NOT done.
## Important Decisions
D-001..D-025 (DECISIONS.md). New this session: zustand (D-017), zod (D-018), phone+demo OTP default (D-019), client-side guards only (D-020), auth rules (D-021), aria-* props (D-022), tsx+node:test (D-023), SQL drafts parked, claude22 recommended base pending owner (D-024), Servex = candidate only (D-025).
## Research Completed
Expo SDK/Router, Fanni listings, RTL in Expo/RN, Expo protected-routes docs. NOT done: marketplace UX study (before Phase 3/6), maps, payments in Jordan, push, store rules, real Supabase behaviour.
## Things NOT To Change
- Routes in src/app; customer/provider/admin real folders (no route groups).
- No hardcoded UI strings; logical start/end props; aria-* props for state; >=48dp targets.
- Do not move SQL from supabase/_drafts into supabase/migrations or apply it anywhere without owner decision.
- Do not rename app/bundle id/icon to Servex until owner confirms.
- 14 job states are fixed (DB enum matches exactly).
- Keep AGENTS.md. No real payments/GPS/maps yet.
## Exact Next Task
(0) Ask owner, ONE question at a time: is "Servex" the final name? then: confirm claude22 as SQL base. If Servex confirmed: do the rename checklist (app name, display name, bundle id/package, icon/splash from logo, docs). (1) Short, honestly-reported UX study (Careem, Wolt/Talabat, Airbnb, Uber) for home + provider cards; write to RESEARCH.md. (2) PHASE 3 Customer Home: central demo data module for categories/services (Jordanian services, Arabic names) + home screen (greeting, search entry, category grid, "most requested", skeleton/empty/error states) using the UI kit; route stays /customer. Note Phase 4 (services/categories) overlaps: keep the data model aligned with DB tables categories/services in supabase/_drafts/claude22. (3) tests (unit for data, e2e for home), docs, checkpoint, handoff.
## Next Steps
1. Owner replaces folder with the new zip, runs npm install, tests login, ideally on a phone via Expo Go (verify native RTL, KI-001/KI-018).
2. Owner answers: Servex final? SQL base?
3. Phase 3 as above; later Phase 22 reconciliation of DB drafts (KI-016 first).
## Commands Needed To Continue
`npm install` · `npm run web` · `npm start` (QR) · `npm run verify` · `npm test` · `npx expo-doctor` · `git log --oneline` · `git checkout phase-2-complete` to return to this state. UI tests: see TESTING.md.
## User Actions Required
1. Unzip PROJECT_APP.zip to C:\\Dev\\PROJECT_APP (replace old folder; NOT on OneDrive). 2. In that folder: `npm install` then `npm run web`. 3. Success: Arabic RTL login; 0790000002 + 123456 -> customer home; logout works; a new number (e.g. 0771234567) goes to registration. 4. Optional: `npm start` + Expo Go on phone; report whether layout is right-to-left. 5. Answer the two questions (brand, SQL base). 6. Save original master prompt as docs/MASTER_PROMPT.md. 7. Back up folder / private GitHub repo.
## Git Checkpoint
Branch main. Tags: phase-0-complete, phase-1-complete, phase-2-complete.
## Backup Status
Delivered as zip (includes .git, excludes node_modules). No remote.
## NEXT SESSION PROMPT
```
You are the lead engineer of PROJECT_APP (Jordan services marketplace, Expo SDK 57 + TypeScript; brand candidate "Servex" NOT confirmed). Files are the source of truth. First read, in order: README.md, docs/PROJECT_STATUS.md, docs/PROJECT_ARCHITECTURE.md, docs/FILE_MAP.md, docs/DECISIONS.md, docs/DEVELOPMENT_LOG.md, docs/SESSION_HANDOFF.md, docs/AI_INSTRUCTIONS.md, docs/DATABASE_PLAN.md (and docs/MASTER_PROMPT.md if present). Run git status, npm run verify, npm test. Continue exactly from the documented state: Phases 0-2 complete; follow "Exact Next Task" (ask the owner ONE question first: is Servex the final name?). Research just-in-time and say honestly if you cannot browse. Run runtime tests (tests/*.py), not only tsc/eslint. Do not apply supabase/_drafts SQL anywhere without owner decision. Update FILE_MAP/DEVELOPMENT_LOG/DECISIONS/PROJECT_STATUS, git checkpoint, update SESSION_HANDOFF, end with a Session Report + a new NEXT SESSION PROMPT. The owner is not an engineer: give click-by-click steps in simple Jordanian Arabic. Do not change items under "Things NOT To Change".
```
