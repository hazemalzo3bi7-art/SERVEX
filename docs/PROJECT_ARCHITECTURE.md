# ARCHITECTURE (Phase 0)
**Stack:** Expo SDK 57 · React Native 0.86 · React 19 · TypeScript (strict) · Expo Router (file-based, typed routes) · React Compiler enabled (template default).

## Layout
- `src/app/` — ROUTES ONLY (Expo SDK 57 convention). `customer/`, `provider/`, `admin/` are real URL segments (`/customer` ...). NOT route groups: groups add no URL segment and collided on `/` (see DEVELOPMENT_LOG).
- `src/features/<domain>/` — domain logic + screens' building blocks (auth, customer, provider, jobs, payments, invoices, ratings, notifications, admin). Empty in Phase 0.
- `src/components/` shared UI · `src/services/` data access behind interfaces · `src/state/` app state · `src/hooks` · `src/types` · `src/utils` · `src/constants` (theme tokens) · `src/i18n` (ar default, en).
- `@/*` alias -> `src/*`.

## UI layer (Phase 1)
Tokens in `src/constants/theme.ts` -> UI kit `src/components/ui/*` (import from `@/components/ui`). RTL: web `+html.tsx`, native `src/i18n/rtl.ts`. Use logical props (start/end); text via `AppText`; strings via `t()`; every interactive element needs an accessibility role/label and >=48dp target. Fonts loaded in root layout (splash held until ready).

## Principles
1. **Service-interface boundary:** UI talks to `services/*` interfaces. Phase 1-21 implement them in-memory (mock); Phase 22 swaps to Supabase without touching screens.
2. **Central job state machine** in `features/jobs` (statuses per master prompt §17). No status logic in screens.
3. **Central demo data** in one module (no scattered mocks). **Deterministic pricing** (documented when built).
4. **i18n from day one:** no hardcoded UI strings; `t(key)`. Keys typed from `ar.ts`; `en.ts` must match.
5. **Roles:** customer / provider / admin are separate route trees; real guards arrive in Phase 2.
6. Design for multi-country (currency, locale, tax) but implement none of it yet.

## Auth layer (Phase 2)
`src/types/auth.ts` -> `src/features/auth/schemas.ts` (zod, i18n-key errors) -> `src/services/auth/*` (`AuthService` interface; in-memory demo impl; Phase 22 = Supabase Auth) -> `src/state/authStore.ts` (zustand; validates first, maps `AuthError` to i18n keys) -> screens `src/app/{login,verify,register}.tsx`. Guards: `Stack.Protected` in `src/app/_layout.tsx` by role; `src/app/index.tsx` redirects by role via `homeFor`. Demo data lives only in `src/services/demo/seed.ts`.
## Backend (not integrated)
SQL drafts in `supabase/_drafts/` (see DATABASE_PLAN.md). Nothing in the app talks to a database yet.
