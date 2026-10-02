# CLAUDE 3 — AUDIT REPORT

Author: Claude 3 · Date: 2026-10-01 · Mode: read-only, nothing implemented or changed

## 0. Limits of this audit (important)

This is a **documentation audit**. I received the 17 project docs and the logo, **not** the source, SQL drafts, tests, `package.json`, README or master prompt. Therefore:
- I executed nothing. "Verified" below means **cross-checked between documents** or **checked directly in a file I have**; it does **not** mean the code works.
- Anything that needs the code or SQL is under "Cannot verify" with the exact file to check.
- Severity: **High** = could cause security failure, data loss or major rework; **Med** = likely rework or user harm; **Low** = polish or hygiene.
- Tags: [DOC] stated in docs · [DOC-CONFLICT] docs disagree · [INFERENCE] my reasoning.

## 1. Verified working

### 1a. Checked by me directly
| # | Check | Result |
|---|---|---|
| V1 | Table count: DATABASE_PLAN lists 26 tables for claude22 | Counted: **26**, matches the stated number |
| V2 | Phone rule: frontend E.164 `+9627[789]XXXXXXX` vs DB CHECK `^\+9627[789][0-9]{7}$` | Both give a 9-digit Jordanian mobile number; consistent. Demo numbers (`079xxxxxxx`) fit the rule |
| V3 | Money unit: JOD with `numeric(…,3)` | Correct. JOD has 3 decimals (1 dinar = 1000 fils) |
| V4 | Test counts across docs (24 unit, 10 e2e steps, 22 DB checks) | Same in PROJECT_STATUS, TESTING and SESSION_HANDOFF |
| V5 | Tag/branch/doc claims in SESSION_HANDOFF tree vs FILE_MAP | Every file in FILE_MAP's Phase 2 list appears in the tree (except `scripts/`, an empty dir that git would not track) |
| V6 | Logo file | Present, PNG 1327×301 RGBA, two variants (light/dark) |

### 1b. Documented as working, not re-verified by me
- Demo auth flow, role guards, lockout, admin never self-registered, suspension block.
- 24 unit tests, `auth_smoke.py` 10/10, `design_smoke.py`, tsc, eslint, Android/web export.
- Web RTL (`dir=rtl`, mirrored layout), Arabic font loading, toast, bottom sheet, `aria-*` state exposure.
- claude22 behaviour checks 22/22 (anon denied, own-jobs-only, no direct status/role edits, illegal transitions rejected, review rules, admin-only actions, no self-verify).
- Good process signals: runtime tests caught two real bugs that tsc/eslint missed (route-group collision, missing `aria-checked`). The project explicitly treats docs as source of truth and records decisions with reasons.

## 2. Potential issues

### Security
| ID | Sev | Finding | Evidence |
|---|---|---|---|
| S1 | **High** | `DEMO_MODE` is a **hard-coded constant** in `seed.ts`, not an env var or build flag. When true, the OTP and demo numbers show on the login screen and OTP `123456` is accepted for all demo users, including **admin**. Only a prose note ("must be false for release") guards it; no check or CI fails a release build. [INFERENCE: easy to forget] | KI-014, D-019, SECURITY |
| S2 | Med | `/dev/components` ships in the app; also the demo data and the admin demo account live in the same bundle | KI-010 |
| S3 | Med | Real authorisation depends entirely on RLS + SECURITY DEFINER functions, which have **only been run on plain PostgreSQL with hand-written stand-ins**. Stand-ins for `auth.uid()`, `auth.jwt()`, roles and the `storage`/`realtime` schemas can hide Supabase-specific behaviour | KI-016, TESTING caveat |
| S4 | Med | The 22 behaviour checks and the stubs were written by the same agent that recommended the base draft. No independent review of the SQL is recorded | DEVELOPMENT_LOG |
| S5 | Med | Storage policies (photos, portfolio, inspection photos) are listed as untested; rate limiting, backups and quote-expiry cron are not wired | DATABASE_PLAN gaps, SECURITY |
| S6 | Med | The 60-second lockout is per phone number. In a real backend, this lets anyone lock out a victim's login by sending wrong codes (denial of service). Needs per-IP/device limits and SMS-cost controls at Supabase/Edge | D-021 [INFERENCE] |
| S7 | Low | Session is in memory only (reload = logout). Safe, but when persistence is added it must use secure storage on native, not AsyncStorage/localStorage | KI-012 |
| S8 | Low | SECURITY.md is largely "planned". There is no dependency-audit step, secret scanning or CI | SECURITY |

### Backend ↔ frontend conflicts and drift
| ID | Sev | Finding | Evidence |
|---|---|---|---|
| C1 | **High** | **Two sources of truth for the job state machine.** Frontend plans a TS state machine in `features/jobs`; DB holds `allowed_job_transitions` (32 rows). API_PLAN says "same definition" but names no mechanism (codegen, shared JSON, parity test). Drift is likely over 20+ phases. | ARCHITECTURE #2, API_PLAN, DATABASE_PLAN |
| C2 | **High** | **KI-016:** verified phone is never copied from `auth.users` to `profiles.phone`; client inserts the profile with `phone` NULL. Anything keyed on `profiles.phone` (admin search, notifications, provider contact, uniqueness) breaks. Fix is known (trigger or RPC) but deferred. | KI-016, DATABASE_PLAN |
| C3 | Med | **Same pattern for pricing:** frontend wants "deterministic documented pricing" in the mock service (Phase 8), while API_PLAN puts pricing in Edge Functions. Two implementations unless one spec and shared tests exist. | ARCHITECTURE #3, API_PLAN |
| C4 | Med | **Reconciliation deferred to Phase 22**, while Phases 3–21 build screens and types against the in-memory model. Naming already differs (`reviews` vs ratings; extra `deleted` status). Late reconciliation means rework in many screens. | DATABASE_PLAN, KI-017 |
| C5 | Med | Two separate demo-data sources: `src/services/demo/seed.ts` and the DB `seed.sql`/`generate_seed.py`. No rule keeps ids, names and categories aligned. | FILE_MAP, DATABASE_PLAN |
| C6 | Med | **Multi-country design principle vs Jordan-only DB.** ARCHITECTURE #6 says design for multi-country currency/locale/tax. DB is hard-wired to JOD and a Jordan-only phone CHECK. Acceptable for launch, but the docs should state it is an intentional constraint. | ARCHITECTURE #6, DATABASE_PLAN |
| C7 | Med | "Compare **nearby** providers" needs distance search; DB has area-based `provider_service_areas`, no PostGIS (listed as a gap), and map provider is undecided. | SESSION_HANDOFF, DATABASE_PLAN, ROADMAP |
| C8 | Med | The schema already contains `payments`, `payment_events`, commission and `inspections`, but the payment gateway, commission model and "what free inspection means" are undecided. Schema may bake in wrong assumptions. | ROADMAP vs DATABASE_PLAN |
| C9 | Med | Money handling in TS is not decided. DB uses 3-decimal numerics; JS floats risk rounding errors. Needs a rule (integer fils or a decimal library) before Phase 8. [INFERENCE] | DATABASE_PLAN |
| C10 | Low | `account_status` has `deleted` the UI does not model; `reviews` vs "ratings" folder/name. | KI-017 |
| C11 | Low | `files_zip` ships its own `DATABASE_PLAN.md`/`BACKEND_HANDOFF.md`, risking confusion with `docs/DATABASE_PLAN.md`. | FILE_MAP |

### Process and documentation
| ID | Sev | Finding | Evidence |
|---|---|---|---|
| P1 | **High** | **Master prompt is not in the repo.** Requirements (14 states, §17; phases, §31; rename checklist, §38; roles, pricing) exist only there. No agent, including me, can verify requirements. | AI_INSTRUCTIONS #9 |
| P2 | **High** | **No shared remote or CI.** Work moves as ZIPs; git tags are local; "Backup Status: no remote". With several agents (Claude 1/2/3) this risks divergent copies and lost work. This session received docs only, which shows the problem. | SESSION_HANDOFF Backup Status |
| P3 | Med | The comparison that led to "claude22 recommended" is skewed: behaviour checks exist only for claude22 ("none written" for files_zip), so 22/22 vs "none" is not like-for-like. A larger schema is not automatically better, and the owner's instruction is "don't overbuild". | DATABASE_PLAN, D-024, AI_INSTRUCTIONS #8 |
| P4 | Med | Stale docs ([DOC-CONFLICT]): PROJECT_STATUS "Next task: Phase 1"; TESTING references deleted `nav_smoke.py`; RESEARCH "NOT YET DONE" lists completed items; FILE_MAP `_layout.tsx` description outdated; ENVIRONMENT omits `DEMO_MODE`. Stale handoff docs mislead the next agent. | See Understanding §13 |
| P5 | Med | `npm run verify` is tsc + eslint only. Unit tests and Playwright are separate manual commands (AI_INSTRUCTIONS #10 requires all). Python/bash/`pkill` based; the owner is on Windows and cannot run them easily. | TESTING, AI_INSTRUCTIONS |
| P6 | Med | Decisions made "by judgment", not comparison: zustand, zod, tsx, IBM Plex font. Honest and recorded, but D-005 (i18n library) and D-015 (forms library) never got a final decision. | DECISIONS |
| P7 | Low | Expo SDK 57 is "latest stable" with 58 in beta. Upgrade will change RTL defaults (D-011 uses manual `forceRTL`) and Expo Go compatibility (KI-003). Plan the upgrade; do not hit it mid-phase. | D-001, D-011 |
| P8 | Low | SESSION_HANDOFF "User Actions" has `C:\\Dev\\PROJECT_APP` (double backslash typo). | SESSION_HANDOFF |

### UX / accessibility / brand
| ID | Sev | Finding | Evidence |
|---|---|---|---|
| U1 | Med | Native behaviour is unknown: RTL on first launch (KI-001), keyboard types, OTP autofill (KI-018), never on a real phone (KI-006). Primary market is mobile. | KNOWN_ISSUES |
| U2 | Med | No screen-reader testing (TalkBack/VoiceOver). Toast is single-slot and not swipe-dismissable; an important error could replace another. Unknown whether toasts are announced (live region). | KI-008, TESTING |
| U3 | Med | Marketplace UX study is repeatedly deferred (Phase 1, then 3, then 6). Phase 3 is the first real customer screen. Competitor research rests on store listings and one anecdotal review. | RESEARCH |
| U4 | Low | Reload logs the user out on web; acceptable for demo, bad for demo reviewers. | KI-012 |
| U5 | Low | Light theme only; a dark logo variant already exists. | KI-009, logo |
| U6 | Low | Logo: Latin "Servex" wordmark only, in an Arabic-first RTL app. No Arabic wordmark/lockup is mentioned. The file is a comparison sheet with baked-in captions, so it needs a clean source before it can become icon/splash. No name availability/trademark/store-name check is recorded anywhere. | Image, D-025 |
| U7 | Low | OTP UX details (resend, countdown, change number) are not mentioned in any doc; check in `verify.tsx`. | [NOT VERIFIABLE] |

## 3. Missing

### Missing from the project (per docs)
- `docs/MASTER_PROMPT.md` (and the 14 job state names/32 transitions in any repo doc).
- Real phone/emulator test run; `expo-doctor` run; CI; remote git; automated release gate for `DEMO_MODE`.
- A defined split of duties for Claude 1 / Claude 2 / Claude 3 (no doc mentions them).
- Central job state machine, pricing engine, central demo data for services/providers/jobs (only auth demo users exist).
- Per-screen error state (KI-013); a forms library decision; an i18n library decision.

### Missing from the documented DB table list [INFERENCE: confirm against master prompt/SQL]
No table appears for: customer saved addresses/locations; push device tokens (needed for Phase 24); chat/messages between customer and provider; provider live location/tracking; support tickets; promo/coupons. Job location may live inline in `jobs`; I could not check. `provider_specialties` and `provider_services` may overlap.

### Not provided to me, so unaudited
`src/**`, `supabase/_drafts/**`, `tests/**`, `package.json`, `app.json`, `README.md`, `AGENTS.md`.

## 4. Planned / future (per docs)

Phase 3 Customer Home (after UX study + owner answers) · Phase 4 services/categories · Phase 5 maps/location · Phase 6 provider discovery · Phase 8 pricing · Phase 20/22 Supabase, RLS, DB reconciliation (KI-016/017) · Phase 23 maps/geocoding · Phase 24 push · Phase 25 payments (Jordan gateway) · Phases 26–28 EAS build, stores, OTA · English locale + direction switching with reload · dark mode · secure session persistence · quote-expiry cron, PostGIS, notification fan-out, invoice hardening, storage policy tests · rename to Servex (if confirmed).

## 5. Open decisions

| # | Decision | Owner needed? | Blocks |
|---|---|---|---|
| 1 | Is "Servex" the final name? (plus Arabic name, trademark/store-name check) | Yes | Phase 3 start, rename, icons, bundle id |
| 2 | Confirm `claude22` as SQL base (D-024) | Yes | Phase 22, data model alignment in Phase 3/4 |
| 3 | Login method: phone OTP default, never confirmed (D-019) and which SMS provider for Jordan | Yes | Phase 22 |
| 4 | Commission model (currently 0, pending) | Yes | Phase 8 |
| 5 | What "free inspection" means (fees, cancellation, no-show, re-offer) | Yes | Phases 8+, DB flow |
| 6 | Payment gateway for Jordan | Yes | Phase 25 |
| 7 | Map/geocoding provider and PostGIS | Yes | Phases 5/23 |
| 8 | Can one person hold both customer and provider roles? (frontend assumes one role; DB `profiles` role is unclear to me) | Yes | Phase 22 |
| 9 | Where is the admin experience: in the mobile app or a separate web app? (D-003 hints at future admin web) | Yes | Phase 20+ |
| 10 | Single source of truth for the state machine and pricing (mechanism) | Team | Before jobs work |
| 11 | When to reconcile types with DB (now vs Phase 22) | Team | Phase 3/4 |
| 12 | TS money representation | Team | Phase 8 |
| 13 | i18n library, forms library | Team | Before many forms |
| 14 | `/dev/components` and `DEMO_MODE` release gating | Team | Any release |
| 15 | Expo SDK upgrade timing (58) | Team | KI-003 |

## 6. What Claude 1 and Claude 2 should know before continuing

1. **Do not trust "passing" as "working on Supabase".** The DB drafts have never touched real Supabase. Prefer a scratch Supabase project or `supabase db reset` early, not at Phase 22.
2. **Do not start building jobs/pricing screens until the state-machine and pricing source-of-truth question (C1, C3) is answered.**
3. **Phase 3/4 data types should follow DB `categories`/`services` now** (handoff already says so), to reduce Phase 22 rework (C4, C5).
4. **Treat `DEMO_MODE` as a release blocker** with an automated check (S1). The admin demo login is reachable while it is true.
5. **Never apply `supabase/_drafts/**` SQL or move it into `migrations/`** without the owner (D-024). **Never rename to Servex** before confirmation (D-025). **Keep real folders for roles, `aria-*` props, no hardcoded strings, logical start/end props.**
6. **Save the master prompt in the repo** and add the 14 states and 32 transitions to a doc; right now only the SQL knows them.
7. **Agree on ownership and a shared remote.** No document defines Claude 1/2/3 duties. Who edits `supabase/_drafts/` versus `src/`? Where do changes meet? A shared private repo would remove the ZIP hand-offs.
8. **Fix stale docs first** (list in P4); the next agent starts from them.
9. **Verify the open items I could not see:** `search_path` on every SECURITY DEFINER function, whether `create_job` lets the customer choose the provider (core marketplace rule) and supports re-offer after a no-show, whether `transition_job` is the only way to change status (`cancel_job`/`complete_job` exist separately), what `jobs` stores for location, and `supabase/_drafts/claude22/0005_rls.sql` grants for `anon`.
10. **Send me the missing files** (source, `supabase/_drafts/`, `tests/`, `package.json`, README, master prompt) for a real code and SQL audit; this report would then change from "docs consistency" to verified findings.
