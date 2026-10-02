# CLAUDE 3 — PROJECT UNDERSTANDING

Author: Claude 3 (independent QA/audit agent) · Date: 2026-10-01 · Mode: read-only analysis

## 0. Scope and evidence base (read this first)

**What I actually received** (17 docs + 1 image, all under `/mnt/user-data/uploads`):
AI_INSTRUCTIONS, API_PLAN, CHANGELOG, DATABASE_PLAN, DECISIONS, DEPLOYMENT, DEVELOPMENT_LOG, ENVIRONMENT, FILE_MAP, KNOWN_ISSUES, PROJECT_ARCHITECTURE, PROJECT_STATUS, RESEARCH, ROADMAP, SECURITY, SESSION_HANDOFF, TESTING, `servex_logo_candidate.png`.

**What I did NOT receive** (so nothing about them is verified):
- Source code (`src/**`), `package.json`, `app.json`, `tsconfig.json`, lockfile
- `supabase/_drafts/**` (both SQL drafts, seed, validation scripts)
- `tests/**` (unit tests and Playwright scripts)
- `README.md`, `AGENTS.md`, `docs/MASTER_PROMPT.md` (AI_INSTRUCTIONS #9 says the master prompt was never saved to the repo)
- `.git` (tags, history, commit state)

**Evidence labels used in both reports**
- **[DOC]** stated in a project doc. I did not re-run or re-inspect the underlying code.
- **[DOC-CONFLICT]** two docs disagree, or a doc contradicts the SESSION_HANDOFF file tree.
- **[NOT VERIFIABLE]** depends on a file I do not have.
- **[INFERENCE]** my reasoning from documented facts; flagged so it is not mistaken for a fact.

Nothing in this report comes from executing code. "Passing" always means "the docs say it passed".

## 1. What PROJECT_APP is [DOC]

- Temporary name PROJECT_APP. Brand candidate **"Servex"** (logo stored as candidate; **not confirmed**, D-010, D-025). Bundle id is a placeholder `com.placeholder.projectapp` (D-008).
- A premium on-demand local-services marketplace, launching in **Jordan (Amman, Irbid)**. Arabic-first, RTL; English later (SESSION_HANDOFF "Product Summary").
- Prototype stage: in-memory demo data. Later: Supabase, real payments, maps, push.

## 2. Target users and main product flow [DOC]

Users are customers (request services), providers (do the work) and an admin.

Intended flow (SESSION_HANDOFF "Product Summary"):
1. Customer picks a service and a location, compares nearby providers, **chooses** one (marketplace rule, AI_INSTRUCTIONS #7).
2. Provider accepts, travels, inspects, quotes.
3. Customer approves the quote and pays (**demo payment only**).
4. Work is done, then invoice, ratings, history.

Only step 0 (sign-in / role routing) exists in the app. Everything in the flow above is planned, not built.

## 3. Roles [DOC]

| Role | Self-registerable | Has today | Route tree |
|---|---|---|---|
| customer | yes | stub home (greeting + logout) | `/customer` |
| provider | yes | stub home | `/provider` |
| admin | **never** (D-021; DB policy allows only customer/provider on client insert) | stub home | `/admin` |

Routes are real folders, not route groups (D-003). Guards use `Stack.Protected` and are client-side only (D-020, KI-015).
Demo users: admin `0790000001`, customer `0790000002`, provider `0790000003`; OTP `123456`.

## 4. Technology stack [DOC]

Expo SDK 57, React Native 0.86, React 19, TypeScript strict, Expo Router (typed routes), React Compiler, npm (D-004), ESLint 9 flat (D-007), zustand 5 (D-017), zod 4 (D-018), reanimated (D-013), own UI kit (D-014), IBM Plex Sans Arabic (D-012), custom `t()` i18n (D-005), tests via `tsx` + `node:test` (D-023) and Playwright (Python). Backend plan: Supabase (Postgres + RLS + Edge Functions); not integrated. Package versions are as stated in docs; I could not check `package.json`.

## 5. What each phase implemented [DOC]

**Phase 0 (scaffold):** SDK 57 project, folder architecture, i18n skeleton (ar/en), role route stubs, docs set, `.env.example`, placeholder ids. Found and fixed: route-group URL collision (D-003).

**Phase 1 (design system):** tokens (`theme.ts`), Arabic font, RTL (web `dir=rtl` in `+html.tsx`; native `I18nManager`), UI kit (AppText, Button, Card, TextField, Skeleton, StateView, Toast, BottomSheet; OptionCard added Phase 2), dev preview `/dev/components`, `design_smoke.py`. Found and fixed: `accessibilityState` not exposed on web, so `aria-*` props (D-022).

**Phase 2 (demo auth):** Jordanian phone normaliser (77/78/79, Arabic digits), zod schemas with i18n-key errors, `AuthService` interface + in-memory impl (OTP must be requested, 5 wrong codes lock a phone 60 s, admin never self-registered, suspended blocked), zustand store, login/verify/register screens, guards, `RoleHome`, 24 unit tests, 10-step e2e. Also: two backend SQL drafts parked and executed on PostgreSQL 16 with hand-written Supabase stand-ins.

## 6. What Phase 3 is supposed to implement [DOC]

Phase 3 = **Customer Home** (SESSION_HANDOFF "Exact Next Task"). Order of work:
0. Ask the owner, one question at a time: is "Servex" final? Then confirm `claude22` as SQL base. If Servex is confirmed, run the rename checklist (master prompt §38, which I do not have).
1. A short UX study (Careem, Wolt/Talabat, Airbnb, Uber), written to RESEARCH.md.
2. Central demo-data module for categories/services (Jordanian services, Arabic names), plus a home screen (greeting, search entry, category grid, "most requested", skeleton/empty/error states). Route stays `/customer`. Keep the model aligned with DB `categories`/`services`.
3. Tests, docs, checkpoint, handoff.

Phase 3 has **not** started; PROJECT_STATUS says it is blocked on the UX study plus owner answers (brand, SQL base).
The full phase list (0–32) lives in the master prompt §31, which is not in the repo. Phases mentioned in docs: 4 services/categories (overlaps Phase 3), 5 maps, 6 provider discovery, 8 pricing, 20/22 Supabase, 22 DB reconciliation, 23 maps, 24 push, 25 payments, 26–28 deployment/stores.

## 7. Frontend architecture [DOC]

- `src/app/` routes only. `src/features/<domain>/` (auth populated; customer, provider, jobs, payments, invoices, ratings, notifications, admin are empty `.gitkeep`). Also `components/ui`, `services`, `state`, `hooks`, `types`, `utils`, `constants`, `i18n`; alias `@/*` to `src/*`.
- Layering: UI to `services/*` interface to in-memory impl (Phase 1–21) to Supabase impl (Phase 22).
- Auth chain: `types/auth` to `features/auth/schemas` (zod) to `services/auth/*` to `state/authStore` to screens. Demo data only in `services/demo/seed.ts`.
- Rules: no hardcoded strings (`t()`), logical `start/end` props (D-016), `aria-*` props for state, ≥48dp targets, deterministic documented pricing, central demo data, central job state machine in `features/jobs` (**not built**).
- RTL is fixed on (Arabic-only launch, D-011).

## 8. Backend drafts [DOC — I have not seen the SQL]

Two parked, unmodified, unapplied drafts in `supabase/_drafts/` (D-024):

| | `claude22` (recommended base, owner confirmation pending) | `files_zip` (reference) |
|---|---|---|
| Size | 26 tables, 54 policies, 47 functions, 19 triggers | 19 tables, ~35 policies |
| Seed | yes (covers all 14 job states) | no |
| Behaviour checks | 22 written, 22 pass | none |
| Commission | `app_settings.commission_rate = 0`, status `pending_owner_decision` | hardcoded 10% |

claude22 design: RLS on all 26 tables (deny by default, column-level grants), workflow through SECURITY DEFINER RPCs (`create_job`, `transition_job`, `cancel_job`, `complete_job`, `approve_quote`, `create_review`, `admin_*`), state machine as table `allowed_job_transitions` (32 rows), money `numeric(…,3)` JOD, phone CHECK `^\+9627[789][0-9]{7}$`.
Both were run only on plain PostgreSQL 16 with stand-ins (`stubs.sql`), never on real Supabase. Table names are listed in DATABASE_PLAN (I counted 26, consistent with the stated number).

## 9. Job state machine

- **Documented facts:** exactly **14 job states**, fixed ("Things NOT To Change"). The DB enum `job_status` matches them exactly. Transitions live in DB table `allowed_job_transitions` (32 rows). API_PLAN: transitions must be validated server-side "using the same state-machine definition". The frontend plans a central state machine in `features/jobs` (not built).
- **Not available to me:** the **names of the 14 states and the 32 transitions are not written in any uploaded doc**. They are in master prompt §17 and the SQL, neither of which I have. I will not guess them.
- See audit finding about having two sources of truth.

## 10. Current tests [DOC]

| Test | Claimed result | Source |
|---|---|---|
| `npm run verify` (tsc + eslint) | PASS | TESTING |
| `npm test`, 24 unit tests (phone, authService, authStore) | 24/24 PASS | TESTING |
| `tests/auth_smoke.py`, Playwright e2e, 10 steps | 10/10 PASS | TESTING |
| `tests/design_smoke.py`, runtime design/RTL/a11y | PASS | TESTING |
| `supabase/_drafts/validation/run.sh` (claude22 only) | 22/22 PASS | TESTING |
| Android + web export | PASS (Phase 1; web re-exported in Phase 2) | TESTING |

Not tested at all: real device/Expo Go, iOS, emulator, native RTL, dark mode, screen readers, reduced motion, real Supabase, `expo-doctor`.
No CI. No component tests (D-023).

## 11. Known issues (from KNOWN_ISSUES.md)

KI-001 native RTL unverified · KI-003 Expo Go vs SDK 57 · KI-004 deprecated `uuid@7` warning · KI-005/011 placeholder icons/visuals · KI-006/018 never run on a phone · KI-007 BottomSheet no exit animation · KI-008 single-slot Toast · KI-009 light theme only · KI-010 dev route ships · KI-012 session lost on reload · KI-013 shared `errorKey` · **KI-014 DEMO_MODE shows OTP** · KI-015 guards client-side only · **KI-016 verified phone never copied to `profiles.phone`** · KI-017 DB/UI naming mismatch (`reviews` vs ratings; extra `deleted` status). KI-002 resolved.

## 12. What Claude 1 and Claude 2 are responsible for — UNCLEAR

**No uploaded document defines "Claude 1" or "Claude 2", or any multi-agent split of responsibilities.** I will not invent one. What the docs do say:
- The SQL drafts came from "two independent … other AI sessions" (DATABASE_PLAN, DEVELOPMENT_LOG). One folder is named `claude22`; whether that is "Claude 2" is not stated.
- The previous sessions acted as "lead engineer" (SESSION_HANDOFF NEXT SESSION PROMPT).
- My own role (Claude 3) is defined only by your prompt: independent QA/audit, read-only.

**Please state:** who owns frontend, who owns backend/SQL, who owns docs, who may change `supabase/_drafts/`, and how merges happen. See audit section 6.

## 13. Contradictions and unclear points found while reading

1. PROJECT_STATUS "Next task: Phase 1" is stale; Phases 0–2 are complete and the real next step is the Phase 3 prerequisites.
2. TESTING.md still references `tests/nav_smoke.py`, which DEVELOPMENT_LOG/HANDOFF say was deleted in Phase 2.
3. RESEARCH.md "NOT YET DONE" still lists RTL and state/forms libraries as pending, though Phases 1–2 did them (judgment-based for state/forms).
4. FILE_MAP describes `src/app/_layout.tsx` as "root Stack, status bar"; later docs say it also holds guards, font loading, splash hold and ToastProvider.
5. ENVIRONMENT.md says "Phase 0 needs no env vars" and does not mention `DEMO_MODE`, which is a code constant, not an env var.
6. The UX study is scheduled "before Phase 1/3/6" in RESEARCH, but Phase 1 shipped without it.
7. Supabase phase numbers differ: "Phase 20/22" (SECURITY, RESEARCH) vs "Phase 22" (ARCHITECTURE, DATABASE_PLAN); maps "Phase 5/23".
8. User's checklist names `docs/MASTER_PROMPT.md` and `README.md`; neither was uploaded, and the master prompt is confirmed absent from the repo (AI_INSTRUCTIONS #9).
9. The logo file is a 1327×301 comparison sheet (light and dark variants with captions "LIGHT BACKGROUND / DARK BACKGROUND"), not a clean app-icon asset. It shows a Latin "Servex" wordmark only.
