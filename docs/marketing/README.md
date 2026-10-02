# Servex — Marketing System (staged for integration)

**Status:** Prepared from the project documentation and the fixed launch decisions (D-026/D-027). **Not yet wired into the app source** — the Servex codebase was not available in this session, so no application code, build, or commit was performed here.

## What this package is

A complete, Jordan-specific launch marketing system for Servex, delivered as documentation plus architecture-independent code that is ready to drop into the repository once the source is available.

## Layout

```
docs/marketing/
  MARKETING_STRATEGY.md      Full launch strategy (positioning, segments, channels, phases)
  CUSTOMER_ACQUISITION.md    Channel-by-channel customer playbook
  PROVIDER_ACQUISITION.md    Trade-by-trade provider recruitment playbook
  REFERRAL_STRATEGY.md       Referral/growth mechanics
  CONTENT_CALENDAR.md        30-day launch content calendar (Arabic-first)
  LAUNCH_CHECKLIST.md        Pre-launch → launch → post-launch
  KPI_FRAMEWORK.md           KPI definitions and formulas
  EVENT_TAXONOMY.md          Analytics event names, triggers, properties + funnel
  templates/                 11 reusable Arabic campaign templates

code/
  src/features/marketing/content.ts          Marketing content config (pure TS)
  src/services/analytics/types.ts            Analytics event types (pure TS)
  src/services/analytics/index.ts            Analytics abstraction (no-op + console providers)
  supabase/_drafts/referrals/0001_referrals.sql   Referral schema draft (owner approval required)
```

## How to integrate

1. Copy `docs/marketing/**` into the repository's `docs/marketing/`.
2. Copy the three `code/src/**` files to the matching paths under `src/`.
3. **Do not** copy the referral SQL into `supabase/migrations/` without the owner's explicit approval (project decision **D-024**: parked drafts must not be moved into migrations without the owner). It is staged under `_drafts/` deliberately.
4. Verify the code files compile against the real UI kit and `t()` i18n signature before merging — they were written against the documented architecture, not against verified source.

## Ground rules respected

- **D-026** — Jordan, Arabic-first, RTL primary, Amman + Irbid.
- **D-027** — light theme; the dark/gold admin reference is inspiration only.
- No invented financial figures — all numbers are labelled **[ASSUMPTION]**.
- No fake SEO claims, no invented results, no hard-coded analytics vendor.
