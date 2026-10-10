# DEVELOPMENT LOG
## 2026-10-01 — Phase 0
- Inspected env: empty workspace, no existing project, git 2.43, node 22.22, npm 10.9; pnpm/yarn/bun absent. Expo CLI online features (`expo lint` auto-setup) blocked by sandbox -> configured ESLint manually (D-007).
- Scaffolded `create-expo-app --template default@sdk-57`; committed untouched template as baseline ("chore: untouched ... baseline").
- Removed demo components/assets; added folder skeleton, theme placeholder, i18n (ar/en), role stub routes, `ScreenPlaceholder`, `.env.example`, `.gitignore` secrets rules, placeholder bundle ids.
- **Bug found & fixed:** first layout used route groups `(customer)` etc.; TS/ESLint/bundle all passed, but runtime test showed all three resolved to URL `/` (groups add no segment) so "back" landed on the wrong screen. Fixed by real folders `customer/ provider/ admin/` (D-003). Lesson: compile checks are not enough; keep runtime navigation test.
- Changed link `accessibilityRole` button->link (Expo Router renders anchors on web).
- Tests: tsc, eslint, android export (2.7MB hbc), web static export (6 routes), Playwright nav test (3 roles, forward+back, correct URLs, no page errors). All pass. Files: see FILE_MAP.

## 2026-10-01 — Phase 1: Design System & App Shell
- Researched RTL in Expo/RN (see RESEARCH.md) -> D-011..D-016.
- Added tokens (`theme.ts`: colours, spacing, radius, typography, shadows), RTL helper, `+html.tsx` (lang=ar dir=rtl), font loading + splash hold in `_layout.tsx`, ToastProvider.
- Built UI kit in `src/components/ui/`; migrated start screen + placeholders to it; added dev preview route `/dev/components` (all components, states, toast, sheet).
- Issues hit: `StyleSheet.absoluteFillObject` removed in RN 0.86 (replaced by explicit absolute style); multiline TextField lacked vertical padding (found in visual review, fixed).
- Tests: tsc, eslint, android export, web export (7 routes), `tests/nav_smoke.py` (3 roles fwd/back), `tests/design_smoke.py` (dir=rtl, lang, font loaded, layout mirrored, toast, disabled button, field error, sheet open/close x2) — all PASS. Visual review of screenshot done.
- Not done: native RTL on device, dark mode, UX study of Careem/Uber/Wolt (deferred, see RESEARCH.md).

## 2026-10-01 — Phase 2: Authentication & Roles (demo)
- Built: types, Jordanian phone normaliser (77/78/79, Arabic digits), zod schemas, central demo seed, `AuthService` interface + in-memory impl (OTP request required, 5-attempt/60s lock, admin never self-registered, suspension), zustand store, screens login/verify/register, `OptionCard`, role layouts, `Stack.Protected` guards, `homeFor`, `RoleHome` (replaces `ScreenPlaceholder`), `t()` with `{placeholders}`, test tooling (tsx, @types/node), `tests/serve_dist.py`, `tests/auth_smoke.py`. Removed `tests/nav_smoke.py` (old role picker no longer exists).
- Research: Expo protected-routes docs (client-side only; web quirks). zustand/zod/tsx by judgment.
- Real bugs found by runtime tests and fixed: wrong error message for missing role; role card `aria-checked` missing on web (switched Button/OptionCard to `aria-*` props). False alarms: hidden duplicate screens under the stack (tests now target visible elements); a test-runner `pkill` killing its own shell.
- Tests: see TESTING.md (24 unit, 10 e2e steps, design smoke).
## 2026-10-01 — Backend drafts received from owner + validation
- Owner supplied `claude22.zip` and `files.zip` (two independent Supabase SQL drafts from other AI sessions) and a "Servex" logo. Parked unmodified in `supabase/_drafts/{claude22,files_zip}`; logo in `docs/brand/`.
- Installed PostgreSQL 16 in the sandbox, wrote Supabase stand-ins (`supabase/_drafts/validation/stubs.sql`), executed both sets: both run. Wrote 22 behaviour checks for claude22: all pass (one initial "failure" was a wrong expectation: `cancel_job` is idempotent by design; one check had a wrong column name in the test itself).
- Findings: enum matches the 14 job states exactly; DB phone CHECK equals frontend E.164 rule; claude22 keeps commission configurable (0, pending owner decision); gap KI-016 (verified phone never copied to `profiles.phone`).
