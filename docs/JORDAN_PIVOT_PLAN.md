# Servex — Jordan-First Pivot Plan

**Status:** PLAN ONLY — no implementation performed.
**Date:** 2026-10-02
**Decision basis:** `docs/DECISIONS_JORDAN_PIVOT.md` (D-035 → D-040), which supersede D-026 / D-027.
**Scope:** complete impact analysis of the Israel-first / English-first / LTR implementation, and the ordered plan to pivot to Jordan-first / Arabic-first / RTL.

> This document is an **analysis and plan**. It does not change code. It is intended as the single reference for the implementation phase.

---

## 1. Current Israel-first implementation (verified against source)

The repository currently implements an **Israel-first, English-only, LTR** product:

| Area | Current implementation | Evidence |
|---|---|---|
| Market | **Israel first**, Jordan later | `docs/DECISIONS.md` D-026/D-027, `docs/CURRENT_PROJECT_STATE.md`, `docs/AI_INSTRUCTIONS.md`, `docs/ROADMAP.md` |
| Language | **English only**; `DEFAULT_LOCALE = 'en'` | `src/i18n/index.ts` |
| Direction | **LTR**; web renders `lang="en" dir="ltr"`; RTL forced OFF | `src/app/+html.tsx`, `src/i18n/rtl.ts` |
| Demo location | **Florentin, Tel Aviv-Yafo, Israel** | `src/services/demo/catalog.ts` |
| Phone | accepts **`+972` and `+962`** | `src/utils/phone.ts` |
| Categories | 12 demo categories (Western/general service set) | `src/services/demo/catalog.ts`, `src/services/demo/seed.ts` |
| Product name | **Servex** (final) | D-028 |
| Theme | **Light** (already correct) | KI-009 |
| Backend | `claude22` SQL draft, **unapplied**, and **Jordan-only** (`+962`, `amman`/`irbid`, 6 categories) | `supabase/_drafts/` |

**Key structural finding:** the *product* is Israel-first while the *database draft* is Jordan-only. That contradiction is **KI-019**. The pivot resolves it **in the database's favour** — the DB does not need to be un-Jordanised; the app needs to become Jordanian.

### Verified build state (executed during this analysis)

| Check | Result |
|---|---|
| `npm ci` | ✅ succeeded |
| `npm run verify` (tsc + eslint) | ✅ exit 0 |
| `npm test` | ✅ 38/38 unit tests pass |
| git | ✅ clean tree, tags `phase-0-complete` … `phase-3-complete` |

---

## 2. Required Jordan pivot changes

1. **Market & content** — replace all Israel-first framing with Jordan-first (Amman + Irbid).
2. **Locale** — make Arabic the default (`DEFAULT_LOCALE = 'ar'`); English secondary.
3. **Direction** — enable RTL at platform level; web `lang="ar" dir="rtl"`.
4. **Phone** — validate Jordanian `+962` only; remove `+972` from the launch path.
5. **Location model** — Amman + Irbid; replace the Tel Aviv demo location.
6. **Categories/services** — align the demo catalog with the Jordanian `claude22` catalog (or explicitly reconcile the two).
7. **Strings** — complete, reviewed Arabic for every user-facing string; audit for Israel-specific terms.
8. **Docs** — update all stale D-026/D-027 citations.
9. **Tests** — update fixtures (phone numbers, locations, locale expectations) and re-baseline.
10. **Marketing** — reconcile the previously generated Jordan marketing package with the real codebase (see §10).

---

## 3. Files affected

### 3a. Documentation (20 files in `docs/`)
- `docs/AI_INSTRUCTIONS.md`
- `docs/API_PLAN.md`
- `docs/AUDIT_README.md`
- `docs/CHANGELOG.md`
- `docs/CURRENT_PROJECT_STATE.md`
- `docs/DATABASE_PLAN.md`
- `docs/DECISIONS.md`
- `docs/DEPLOYMENT.md`
- `docs/DEVELOPMENT_LOG.md`
- `docs/ENVIRONMENT.md`
- `docs/FILE_MAP.md`
- `docs/KNOWN_ISSUES.md`
- `docs/MASTER_FILE_INVENTORY.md`
- `docs/PROJECT_ARCHITECTURE.md`
- `docs/PROJECT_STATUS.md`
- `docs/RESEARCH.md`
- `docs/ROADMAP.md`
- `docs/SECURITY.md`
- `docs/SESSION_HANDOFF.md`
- `docs/TESTING.md`

### 3b. Source files (`src/`, 67 files)
- `src/app/+html.tsx`
- `src/app/_layout.tsx`
- `src/app/admin/_layout.tsx`
- `src/app/admin/index.tsx`
- `src/app/customer/_layout.tsx`
- `src/app/customer/index.tsx`
- `src/app/customer/profile.tsx`
- `src/app/customer/requests.tsx`
- `src/app/customer/services.tsx`
- `src/app/dev/components.tsx`
- `src/app/index.tsx`
- `src/app/login.tsx`
- `src/app/provider/_layout.tsx`
- `src/app/provider/index.tsx`
- `src/app/register.tsx`
- `src/app/verify.tsx`
- `src/components/ui/AppText.tsx`
- `src/components/ui/Avatar.tsx`
- `src/components/ui/BottomSheet.tsx`
- `src/components/ui/Button.tsx`
- `src/components/ui/Card.tsx`
- `src/components/ui/Chip.tsx`
- `src/components/ui/Icon.tsx`
- `src/components/ui/Logo.tsx`
- `src/components/ui/OptionCard.tsx`
- `src/components/ui/ScreenScroll.tsx`
- `src/components/ui/SearchField.tsx`
- `src/components/ui/SectionHeader.tsx`
- `src/components/ui/Skeleton.tsx`
- `src/components/ui/StateView.tsx`
- `src/components/ui/TextField.tsx`
- `src/components/ui/Toast.tsx`
- `src/components/ui/index.ts`
- `src/constants/theme.ts`
- `src/features/admin/.gitkeep`
- `src/features/auth/AuthScreen.tsx`
- `src/features/auth/RoleHome.tsx`
- `src/features/auth/homeFor.ts`
- `src/features/auth/schemas.ts`
- `src/features/customer/.gitkeep`
- `src/features/customer/catalog.ts`
- `src/features/customer/components/CategoryGrid.tsx`
- `src/features/customer/components/CategoryTile.tsx`
- `src/features/customer/components/LocationBar.tsx`
- `src/features/customer/components/ProviderCard.tsx`
- `src/features/customer/components/SearchResults.tsx`
- `src/features/invoices/.gitkeep`
- `src/features/jobs/.gitkeep`
- `src/features/notifications/.gitkeep`
- `src/features/payments/.gitkeep`
- `src/features/provider/.gitkeep`
- `src/features/ratings/.gitkeep`
- `src/hooks/.gitkeep`
- `src/i18n/ar.ts`
- `src/i18n/en.ts`
- `src/i18n/index.ts`
- `src/i18n/rtl.ts`
- `src/services/auth/index.ts`
- `src/services/auth/memoryAuthService.ts`
- `src/services/auth/types.ts`
- `src/services/demo/catalog.ts`
- `src/services/demo/seed.ts`
- `src/state/authStore.ts`
- `src/types/auth.ts`
- `src/types/catalog.ts`
- `src/utils/phone.ts`
- `src/utils/text.ts`

### 3c. Files containing Israel-first / English-first / LTR markers
- `docs/AI_INSTRUCTIONS.md`
- `docs/CHANGELOG.md`
- `docs/CURRENT_PROJECT_STATE.md`
- `docs/DATABASE_PLAN.md`
- `docs/DECISIONS.md`
- `docs/DEVELOPMENT_LOG.md`
- `docs/FILE_MAP.md`
- `docs/KNOWN_ISSUES.md`
- `docs/MASTER_FILE_INVENTORY.md`
- `docs/PROJECT_ARCHITECTURE.md`
- `docs/PROJECT_STATUS.md`
- `docs/ROADMAP.md`
- `docs/SECURITY.md`
- `docs/SESSION_HANDOFF.md`
- `docs/TESTING.md`
- `src/app/+html.tsx`
- `src/app/login.tsx`
- `src/i18n/ar.ts`
- `src/i18n/en.ts`
- `src/i18n/rtl.ts`
- `src/services/demo/catalog.ts`
- `src/services/demo/seed.ts`
- `src/utils/phone.ts`
- `tests/auth_smoke.py`
- `tests/customer_home_smoke.py`
- `tests/design_smoke.py`
- `tests/unit/phone.test.ts`

### 3d. Files touching RTL / direction
- `docs/AUDIT_README.md`
- `docs/CHANGELOG.md`
- `docs/CURRENT_PROJECT_STATE.md`
- `docs/DECISIONS.md`
- `docs/DEVELOPMENT_LOG.md`
- `docs/FILE_MAP.md`
- `docs/KNOWN_ISSUES.md`
- `docs/MASTER_FILE_INVENTORY.md`
- `docs/PROJECT_ARCHITECTURE.md`
- `docs/PROJECT_STATUS.md`
- `docs/RESEARCH.md`
- `docs/TESTING.md`
- `src/app/+html.tsx`
- `src/app/login.tsx`
- `src/i18n/rtl.ts`
- `src/utils/phone.ts`
- `tests/auth_smoke.py`
- `tests/design_smoke.py`

### 3e. Files touching phone validation
- `docs/AUDIT_README.md`
- `docs/CHANGELOG.md`
- `docs/CURRENT_PROJECT_STATE.md`
- `docs/DATABASE_PLAN.md`
- `docs/DECISIONS.md`
- `docs/DEVELOPMENT_LOG.md`
- `docs/FILE_MAP.md`
- `docs/KNOWN_ISSUES.md`
- `docs/MASTER_FILE_INVENTORY.md`
- `docs/PROJECT_STATUS.md`
- `docs/RESEARCH.md`
- `docs/ROADMAP.md`
- `docs/SECURITY.md`
- `docs/SESSION_HANDOFF.md`
- `docs/TESTING.md`
- `src/app/customer/profile.tsx`
- `src/app/dev/components.tsx`
- `src/app/login.tsx`
- `src/app/verify.tsx`
- `src/features/auth/schemas.ts`
- `src/features/customer/components/CategoryGrid.tsx`
- `src/i18n/ar.ts`
- `src/i18n/en.ts`
- `src/services/auth/memoryAuthService.ts`
- `src/services/auth/types.ts`
- `src/services/demo/catalog.ts`
- `src/services/demo/seed.ts`
- `src/state/authStore.ts`
- `src/types/auth.ts`
- `src/utils/phone.ts`
- `tests/auth_smoke.py`
- `tests/customer_home_smoke.py`
- `tests/design_smoke.py`
- `tests/unit/authService.test.ts`
- `tests/unit/authStore.test.ts`
- `tests/unit/phone.test.ts`
- `supabase/_drafts/claude22/0002_core_tables.sql`
- `supabase/_drafts/claude22/0005_rls.sql`
- `supabase/_drafts/claude22/generate_seed.py`
- `supabase/_drafts/claude22/seed.sql`
- `supabase/_drafts/claude22/static_check.py`
- `supabase/_drafts/files_zip/20260101000000_core_schema.sql`
- `supabase/_drafts/files_zip/20260101000100_rls.sql`
- `supabase/_drafts/files_zip/DATABASE_PLAN.md`
- `supabase/_drafts/validation/stubs.sql`

### 3f. Files touching locale
- `docs/CURRENT_PROJECT_STATE.md`
- `docs/DECISIONS.md`
- `docs/FILE_MAP.md`
- `docs/MASTER_FILE_INVENTORY.md`
- `docs/PROJECT_ARCHITECTURE.md`
- `src/features/customer/catalog.ts`
- `src/i18n/index.ts`
- `src/i18n/rtl.ts`

### 3g. i18n module
- `src/i18n/ar.ts`
- `src/i18n/en.ts`
- `src/i18n/index.ts`
- `src/i18n/rtl.ts`

### 3h. Auth module
- `src/features/auth/AuthScreen.tsx`
- `src/features/auth/RoleHome.tsx`
- `src/features/auth/homeFor.ts`
- `src/features/auth/schemas.ts`
- `src/services/auth/index.ts`
- `src/services/auth/memoryAuthService.ts`
- `src/services/auth/types.ts`
- `src/state/authStore.ts`
- `src/types/auth.ts`

### 3i. Tests (8 files)
- `tests/auth_smoke.py`
- `tests/customer_home_smoke.py`
- `tests/design_smoke.py`
- `tests/serve_dist.py`
- `tests/unit/authService.test.ts`
- `tests/unit/authStore.test.ts`
- `tests/unit/catalog.test.ts`
- `tests/unit/phone.test.ts`

### 3j. Database drafts
- `supabase/_drafts/claude22/0001_enums.sql`
- `supabase/_drafts/claude22/0002_core_tables.sql`
- `supabase/_drafts/claude22/0003_workflow_tables.sql`
- `supabase/_drafts/claude22/0004_functions.sql`
- `supabase/_drafts/claude22/0005_rls.sql`
- `supabase/_drafts/claude22/0006_storage_realtime.sql`
- `supabase/_drafts/claude22/generate_seed.py`
- `supabase/_drafts/claude22/seed.sql`
- `supabase/_drafts/claude22/static_check.py`
- `supabase/_drafts/files_zip/20260101000000_core_schema.sql`
- `supabase/_drafts/files_zip/20260101000100_rls.sql`
- `supabase/_drafts/files_zip/APPEND_TO_PROJECT_DOCS.md`
- `supabase/_drafts/files_zip/BACKEND_HANDOFF.md`
- `supabase/_drafts/files_zip/DATABASE_PLAN.md`
- `supabase/_drafts/validation/behave_a.sql`
- `supabase/_drafts/validation/behave_a_extra.sql`
- `supabase/_drafts/validation/run.sh`
- `supabase/_drafts/validation/stubs.sql`

### 3k. Scripts
- _(none found)_

---

## 4. Database changes required

**Headline: the `claude22` draft is already Jordan-aligned. The pivot reduces DB work.**

| Item | Current (claude22) | Pivot action |
|---|---|---|
| Phone CHECK | `^\+9627[789][0-9]{7}$` | ✅ **No change** — already Jordanian |
| `city_code` enum | `amman`, `irbid` | ✅ **No change** — already Jordanian |
| Categories | 6 Jordanian categories | ✅ Keep; reconcile app demo catalog to match |
| Currency | JOD `numeric(…,3)` | ✅ Keep (verify against final market decision) |
| `profiles.phone` copy | never populated (KI-016) | Fix as part of auth work |
| Apply state | **unapplied** | Requires **explicit owner approval** before any apply (D-024) |

**Actions:**
1. Do **not** apply or edit `supabase/_drafts/**` without owner approval (D-024).
2. Reconcile the app's demo catalog (12 categories) against the DB catalog (6 categories) — decide which is authoritative, or map them explicitly. (This is KI-019.)
3. Confirm the JOD/currency decision before any payment work.

---

## 5. Authentication / phone changes

| File | Change |
|---|---|
| `src/utils/phone.ts` | Validate **`+9627[789]XXXXXXX`** only; remove `+972` branch |
| `src/services/demo/seed.ts` | Replace Israeli demo numbers with Jordanian demo numbers |
| `src/i18n/en.ts` + Arabic catalog | Update phone-format error/hint strings |
| `src/features/auth/*` | Verify normalisation, validation, and copy for the Jordanian format |
| tests | Update phone fixtures and expectations |

**Rule:** the DB CHECK is `+9627[789][0-9]{7}` — the client must match it exactly to avoid a client/DB mismatch.

---

## 6. i18n / RTL changes

| File | Change |
|---|---|
| `src/i18n/index.ts` | `DEFAULT_LOCALE` → `'ar'`; keep `en` as a supported locale |
| `src/i18n/rtl.ts` | Enable RTL by default instead of forcing LTR |
| `src/i18n/ar.ts` (Arabic catalog) | Ensure complete coverage for all primary surfaces |
| `src/i18n/en.ts` | Retain as secondary |
| `src/app/+html.tsx` | `lang="ar"` and `dir="rtl"` |
| `src/app/_layout.tsx` | Apply RTL/direction at the root |
| `app.json` / Expo config | Review `locales`/localization settings |

**RTL rules to enforce:**
- Use logical `start`/`end` properties only.
- Mirror **directional** icons (back/forward/chevrons); **do not** mirror non-directional icons (search, camera, share).
- Timelines/progress (job tracker) flow **right → left**.
- **Phone numbers and prices stay LTR** even inside RTL layouts.
- Decide the **numeral convention** (Arabic-Indic ٠١٢ vs Western 012) as a design-system rule.

---

## 7. UI changes

| Surface | Change |
|---|---|
| Customer home | Arabic-first copy; RTL layout; Jordanian location row |
| Category grid | Reconcile 12 → DB categories (or map); Arabic labels/icons |
| Search | Arabic normalisation (alef/hamza, taa marbuta, Arabic-Indic digits) |
| Provider cards / profiles | RTL order; Arabic labels; trust badges |
| Auth screens | Arabic copy; Jordanian phone input (LTR-aligned input, RTL layout) |
| Empty/loading/error states | Arabic copy; RTL illustration direction |
| Web landing (`+html`) | `lang="ar" dir="rtl"`; Arabic SEO metadata |

**Constraint:** the light theme is retained (D-040) — do **not** introduce a second theme during the pivot.

---

## 8. Test changes

| Test type | Change |
|---|---|
| Unit tests (8 files in `tests/`) | Update phone fixtures, locale expectations, category counts, location strings |
| Phone validation tests | Assert `+962` accepted and `+972` rejected |
| i18n tests | Assert default locale is `ar`; assert no missing keys on primary surfaces |
| RTL tests | Assert `dir=rtl` on web; assert logical-property usage |
| Playwright suites | Update selectors/copy that assume English; assert Arabic + RTL rendering |
| Snapshot/design tests | Re-baseline for Arabic typography and RTL layout |

**Gate:** `npm run verify` and `npm test` must remain green after every step.

---

## 9. Documentation changes

| Document | Change |
|---|---|
| `docs/DECISIONS.md` | **Do not edit D-026/D-027.** Add a pointer to `DECISIONS_JORDAN_PIVOT.md` |
| `docs/DECISIONS_JORDAN_PIVOT.md` | **NEW** — D-035 → D-040 (this pivot) |
| `docs/CURRENT_PROJECT_STATE.md` | Replace Israel-first/English/LTR framing with Jordan-first |
| `docs/SESSION_HANDOFF.md` | Update market, locale, direction, next-phase framing |
| `docs/AI_INSTRUCTIONS.md` | Update the market/language rule (currently Israel-first/English) |
| `docs/ROADMAP.md` | Replace Israel-first phases with Jordan-first |
| `docs/KNOWN_ISSUES.md` | Update **KI-019** (now resolved in the DB's favour) and **KI-022** (Arabic no longer dormant) |
| `docs/PROJECT_STATUS.md`, `docs/PROJECT_ARCHITECTURE.md`, `docs/FILE_MAP.md`, `docs/RESEARCH.md` | Audit for Israel/English/LTR references |
| `docs/JORDAN_PIVOT_PLAN.md` | **NEW** — this document |

---

## 10. Marketing implications

The previously generated Jordan marketing package (`docs/marketing/`) was produced **before** the codebase was available. It is directionally correct for the pivot (Jordan, Arabic, RTL, Amman + Irbid) but it is **not reconciled** with the real codebase.

**Actions:**
1. Keep it **marked as draft / not final** until reconciled (owner instruction).
2. Reconcile after the pivot implementation:
   - categories/services in the content config must match the **final** catalog (12 vs 6 decision),
   - phone/CTA links must match real routes,
   - the **currency** used in copy must match the final decision (JOD),
   - the referral draft SQL must be re-checked against the applied schema,
   - the analytics taxonomy must be wired to real screens.
3. Do not publish marketing copy that references features not yet built.

---

## 11. Risks and dependencies

| # | Risk | Impact | Mitigation |
|---|---|---|---|
| R1 | **Locale/RTL regression** | Broken layout on every screen | Enable RTL early; verify on a real device before building more screens |
| R2 | **Catalog mismatch (12 vs 6)** — KI-019 | Rework if not decided first | Decide the authoritative catalog **before** Phase 4 |
| R3 | **DB apply needs owner approval** (D-024) | Backend work blocked | Get explicit approval; do not move `_drafts` into `migrations/` |
| R4 | **Incomplete Arabic translations** | English fallback leaks on primary surfaces | Audit key coverage; block release on missing primary-surface keys |
| R5 | **Phone client/DB mismatch** | Auth failures | Client regex must equal the DB CHECK exactly |
| R6 | **Currency ambiguity (JOD vs other)** | Pricing/payment rework | Confirm currency before any payment work |
| R7 | **Stale decision citations** | Future agents follow the wrong direction | Update every D-026/D-027 citation to D-035–D-040 |
| R8 | **Marketing package drift** | Public copy contradicts the product | Keep it draft until reconciled |
| R9 | **Never run on a device** (KI-018) | RTL/typography issues unseen | Device verification as an explicit step |
| R10 | **Numerals decision pending** | Inconsistent UI | Decide Arabic-Indic vs Western as a design-system rule |

---

## 12. Recommended implementation order

Each step must end with `npm run verify` + `npm test` green.

**Step 1 — Decision & documentation (no code)**
- Commit `docs/DECISIONS_JORDAN_PIVOT.md` and `docs/JORDAN_PIVOT_PLAN.md`.
- Add a pointer in `docs/DECISIONS.md` (without editing D-026/D-027).
- Resolve open decisions: catalog (12 vs 6), currency, numerals.

**Step 2 — i18n & RTL foundation (smallest, highest-leverage)**
- `DEFAULT_LOCALE` → `'ar'`; enable RTL; `+html` → `lang="ar" dir="rtl"`.
- Verify Arabic catalog coverage; keep `en` secondary.
- Verify on a real device (addresses KI-018).

**Step 3 — Phone & auth**
- `src/utils/phone.ts` → `+962` only; update demo numbers, error strings, tests.
- Confirm client regex equals the DB CHECK.

**Step 4 — Location & catalog**
- Replace the Tel Aviv demo location with Amman (+ Irbid).
- Reconcile categories/services with the authoritative catalog.

**Step 5 — UI pass**
- Audit every customer/provider surface for RTL correctness, Arabic copy, and Israel-specific remnants.

**Step 6 — Tests & docs sweep**
- Re-baseline tests; update all docs still citing D-026/D-027.

**Step 7 — Database (only with owner approval)**
- Apply/confirm the Jordanian schema; fix KI-016 (`profiles.phone`).

**Step 8 — Marketing reconciliation**
- Reconcile `docs/marketing/` with the final codebase; then mark it final.

**Step 9 — Continue the roadmap**
- Resume the normal roadmap (Phase 4 onward) on the Jordan-first baseline.

---

## Appendix — Superseded vs new decision map

| Old | Old meaning | New |
|---|---|---|
| D-026 | English UI / LTR / Israel-first | **D-035** (market), **D-036** (language/RTL), **D-039** (English secondary) |
| D-027 | `+972` + `+962`, Israel first | **D-037** (`+962` only), **D-038** (Amman/Irbid) |
| D-011 | Arabic-first (was superseded) | **Restored by D-036** |
| — | — | **D-040** (light theme retained) |
