# TESTING
## Commands
`npm run verify` (tsc + eslint) · `npm run export:android` · `npm run export:web`
## Phase 0 results (2026-10-01)
| Check | Result |
|---|---|
| tsc --noEmit | PASS |
| eslint . | PASS |
| expo export android | PASS (2.7 MB Hermes bundle) |
| expo export web | PASS (routes: /, /customer, /provider, /admin, +not-found, _sitemap) |
| Playwright (headless Chromium, 390x780): home -> each role -> back, URL asserted, no page errors | PASS |
## Phase 1 results (2026-10-01)
| Check | Result |
|---|---|
| tsc, eslint | PASS |
| expo export web (7 routes) / android | PASS |
| tests/nav_smoke.py | PASS |
| tests/design_smoke.py: dir=rtl, lang=ar, Arabic font loaded, RTL layout mirrored, toast, disabled button, field error, bottom sheet open/close (backdrop + button) | PASS |
| Visual review of preview screenshot (390px wide) | PASS after multiline-field padding fix |
How to run UI tests: `npx expo export --platform web --output-dir /tmp/export-web`; `cd /tmp/export-web && python3 -m http.server 8099 &`; then `python3 tests/nav_smoke.py` and `python3 tests/design_smoke.py` (needs `pip install playwright && playwright install chromium`). Note: the simple server can't deep-link `/dev/components`; tests navigate by clicking.

## Not tested
Real device / Expo Go, iOS, Android emulator, native RTL layout, dark mode, screen readers (TalkBack/VoiceOver), reduced-motion behaviour. The Playwright script is saved as `tests/nav_smoke.py` (needs Python + playwright; not yet wired into npm scripts/CI).

## Phase 2 results (2026-10-01)
| Check | Result |
|---|---|
| tsc, eslint | PASS |
| `npm test` (tsx + node:test): phone normalisation, auth service (lockout w/ fake clock, admin can't self-register, suspended blocked), auth store | **24/24 PASS** |
| `tests/auth_smoke.py` end-to-end on web export: fresh visit -> /login; unauthenticated deep links to /customer /provider /admin blocked; invalid phone; /verify without request bounced; wrong then right code; customer cannot reach admin/provider; logout; admin + provider homes; new user w/ Arabic digits + validation errors + radio `aria-checked` + register; lockout message | **10/10 steps PASS** |
| `tests/design_smoke.py` (now also asserts `aria-disabled`, `aria-busy`) | PASS |
Run UI tests: `npx expo export --platform web --output-dir /tmp/export-web`; `python3 tests/serve_dist.py /tmp/export-web 8099 &`; `python3 tests/auth_smoke.py`; `python3 tests/design_smoke.py`. (Python + `pip install playwright && playwright install chromium`.)
Real bugs found by these tests and fixed: (1) missing role showed the "invalid name" message; (2) selected role card was not exposed to assistive tech on web (`aria-checked` missing).

## Database draft validation (2026-10-01) — `bash supabase/_drafts/validation/run.sh`
| Check | Result |
|---|---|
| claude22 migrations 0001-0006 + seed.sql executed on PostgreSQL 16 (Supabase stand-ins) | PASS: 26 tables, 26 with RLS, 54 policies, 47 functions, 19 triggers; seed covers all 14 job states |
| files_zip 2 migrations executed | PASS (executes only; no behaviour checks written) |
| 22 behaviour checks on claude22 (anon denied, customer sees only own jobs, no direct status/role edits, illegal transition, duplicate/non-party/early/out-of-range reviews, other customer's quote, cancel rules, admin-only actions, suspended user blocked, provider can't self-verify) | **22/22 PASS** |
Caveat: NOT real Supabase; `static_check.py` (shipped with claude22) was not made to work on this layout and was not used.
