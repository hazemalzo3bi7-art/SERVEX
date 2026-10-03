# Servex — Jordan-First Pivot: Decision Record

> **Addendum to `docs/DECISIONS.md`.** This file does **not** edit, rename, or
> reuse any existing decision ID. The next available IDs (the repository's
> highest existing ID is **D-034**) are used below.

**Date:** 2026-10-02
**Status:** DECIDED (owner) — supersedes the Israel-first / English-first / LTR decisions.

## Supersession statement

**D-035 → D-040 below SUPERSEDE the following existing decisions:**

| Superseded | Existing decision (now outdated) |
|---|---|
| **D-026** | English UI, LTR, `DEFAULT_LOCALE = 'en'`, Israel-first market |
| **D-027** | Phone accepts Israeli `+972` **and** Jordanian `+962`; Israel first, Jordan later |
| **D-011** (transitively) | Arabic-first — was superseded by D-026; **restored in substance by D-036** |

`D-026` and `D-027` remain in `docs/DECISIONS.md` as historical record and **must not be edited or renumbered**.
Any document, test, or code comment that cites D-026/D-027 as the *current* market/language/theme direction is now stale and must be updated to cite D-035–D-040.

---

## D-035 — Market pivots to Jordan-first

- **Status:** DECIDED (owner).
- Servex launches in **Jordan**, not Israel.
- **Initial launch cities: Amman + Irbid.**
- Israel is **out of scope** for launch.
- **Supersedes D-026** (market component) and the Israel-first assumptions in `CURRENT_PROJECT_STATE.md`, `SESSION_HANDOFF.md`, `AI_INSTRUCTIONS.md`, `ROADMAP.md`.

**Consequences:**
- Demo/seed location must become a Jordanian location (Amman).
- No Israel-specific content, city model, currency, or legal assumptions may remain in shipped surfaces.

---

## D-036 — Arabic is the primary language; RTL is the primary UX direction

- **Status:** DECIDED (owner).
- **Primary language: Arabic.**
- **Primary UX direction: RTL.**
- Arabic is **not dormant** — it is the default experience.
- **Supersedes D-026** (language + direction components) and **restores the substance of D-011**.

**Consequences:**
- `DEFAULT_LOCALE` must become `'ar'`.
- RTL must be enabled at the platform level (not merely "supported").
- Web `<html>` must render `lang="ar" dir="rtl"`.
- All user-facing strings must have complete, reviewed Arabic translations (no English fallback gaps on primary surfaces).

---

## D-037 — Jordanian phone validation (+962 only)

- **Status:** DECIDED (owner).
- Phone numbers are validated as **Jordanian `+962`** only for launch.
- Israeli `+972` validation must be **removed from the launch path**.
- **Supersedes D-027.**

**Consequences:**
- `src/utils/phone.ts` must validate `+9627[789]XXXXXXX` (9-digit Jordanian mobile).
- Demo/seed phone numbers must be Jordanian.
- Auth copy and i18n error strings must reference the Jordanian format.

---

## D-038 — Jordanian city model: Amman + Irbid

- **Status:** DECIDED (owner).
- City/area model is **Amman** and **Irbid** only for launch.
- **Supersedes** the Israel-first location assumptions (demo location, city enums, area lists).

**Consequences:**
- Demo location becomes a Jordanian area (e.g. Amman — Abdoun / Sweifieh / Jubeiha).
- Any city enum/area list must match `amman` / `irbid`.
- This **reconciles the product with the `claude22` database**, whose `city_code` enum is already `amman` / `irbid` and whose phone CHECK is already `+9627[789]` (resolving **KI-019** in the DB's favour).

---

## D-039 — English becomes a secondary, supported language

- **Status:** DECIDED (owner).
- **English remains supported** through the existing i18n architecture.
- English is **not** the primary launch language and must not be the default locale.
- **Supersedes D-026** (English-only component).

**Consequences:**
- `src/i18n/en.ts` is retained.
- English is reachable via a language switch / device-locale fallback, not as default.
- English UI must not be the first-run experience.

---

## D-040 — Light theme is retained

- **Status:** DECIDED (owner) — confirms existing state.
- The **light theme remains the product theme**.
- No second theme or dark-mode redesign is introduced as part of the pivot.
- (Consistent with existing **KI-009**.)

**Consequences:**
- No new theme tokens or theme-switching infrastructure are added for the pivot.

---

## Relationship to the database

The `claude22` SQL draft (`supabase/_drafts/`) is **already Jordan-aligned**:
`profiles.phone CHECK (phone ~ '^\+9627[789][0-9]{7}$')`, `city_code` enum = `amman`/`irbid`,
and a 6-category Jordanian catalog. The pivot therefore **aligns the product with the DB**
rather than the reverse. See `docs/JORDAN_PIVOT_PLAN.md` §4 and §11 (KI-019).
