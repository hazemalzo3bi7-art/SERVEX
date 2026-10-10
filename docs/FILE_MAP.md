# FILE MAP  (Audience: S=shared C=customer P=provider A=admin)
| Path | Purpose | Key deps | Aud |
|---|---|---|---|
| package.json | scripts + deps (Expo SDK 57) | expo, expo-router | S |
| app.json | Expo config; placeholder bundle ids; typedRoutes, reactCompiler | — | S |
| tsconfig.json | strict TS, `@/*`->`src/*` | expo/tsconfig.base | S |
| eslint.config.js | ESLint 9 flat config | eslint-config-expo | S |
| .env.example | documents env vars (no secrets) | — | S |
| .gitignore | ignores node_modules, .env, native dirs | — | S |
| AGENTS.md | Expo's agent instructions (keep!) | — | S |
| README.md | how to run | — | S |
| src/app/_layout.tsx | root Stack, status bar | expo-router | S |
| src/app/+html.tsx | web root HTML: lang=ar dir=rtl | expo-router/html | S |
| src/app/dev/components.tsx | DEV-ONLY design system preview (KI-010) | ui kit | S |
| src/app/index.tsx | entry: redirects to /login or the role home | authStore, homeFor | S |
| src/components/ui/AppText.tsx | typography component (variants) | theme | S |
| src/components/ui/Button.tsx | primary/secondary/ghost, loading/disabled, a11y | AppText | S |
| src/components/ui/Card.tsx | raised surface | theme | S |
| src/components/ui/TextField.tsx | labelled input with helper/error | AppText | S |
| src/components/ui/Skeleton.tsx | pulsing loading block (reduced-motion aware) | reanimated | S |
| src/components/ui/StateView.tsx | empty/error state with action | AppText, Button | S |
| src/components/ui/Toast.tsx | ToastProvider + useToast | reanimated, safe-area | S |
| src/components/ui/BottomSheet.tsx | modal bottom sheet | reanimated, safe-area | S |
| src/components/ui/index.ts | barrel export of the UI kit | — | S |
| src/i18n/rtl.ts | applies native RTL flags at startup | react-native | S |
| tests/design_smoke.py | Playwright runtime test of design system + RTL | playwright | S |
| src/app/customer/index.tsx | customer home stub | RoleHome | C |
| src/app/provider/index.tsx | provider home stub | RoleHome | P |
| src/app/admin/index.tsx | admin home stub | RoleHome | A |
| src/constants/theme.ts | design tokens: colours (neutral placeholder), spacing, radius, typography, shadows | — | S |
| src/i18n/index.ts | `t()`, locales, default 'ar' | ar, en | S |
| src/i18n/ar.ts | Arabic strings (source of keys) | — | S |
| src/i18n/en.ts | English strings (typed to match ar) | ar | S |
| src/features/*/.gitkeep, src/{services,state,hooks,types,utils}/.gitkeep, | empty placeholders for planned modules | — | S |
| assets/images/* | template icons/splash (PLACEHOLDER art, replace with brand) | — | S |
| src/types/auth.ts | Role, SignUpRole, User types | — | S |
| src/utils/phone.ts | Jordanian mobile normalisation/formatting, Arabic digits | — | S |
| src/features/auth/schemas.ts | zod schemas (phone, otp, profile); errors = i18n keys; `parseWith` | zod | S |
| src/features/auth/AuthScreen.tsx | shared layout for auth screens (keyboard-safe, safe-area) | ui kit | S |
| src/features/auth/RoleHome.tsx | TEMP role home (greeting + logout) | authStore | C/P/A |
| src/features/auth/homeFor.ts | role -> home route | expo-router | S |
| src/services/demo/seed.ts | CENTRAL demo data: DEMO_MODE, DEMO_OTP, 3 demo users | — | S |
| src/services/auth/types.ts | `AuthService` interface, `AuthError` | — | S |
| src/services/auth/memoryAuthService.ts | in-memory demo implementation (lockout, no self-admin) | schemas, seed | S |
| src/services/auth/index.ts | app-wide `authService` instance | memoryAuthService | S |
| src/state/authStore.ts | zustand auth store (`createAuthStore`, `useAuthStore`) | zustand, authService | S |
| src/components/ui/OptionCard.tsx | radio-style choice card (`aria-checked`) | AppText | S |
| src/app/login.tsx, verify.tsx, register.tsx | auth screens (unauthenticated only) | authStore | S |
| src/app/{customer,provider,admin}/_layout.tsx | per-role Stack layouts (guarded in root layout) | expo-router | C/P/A |
| tests/unit/*.test.ts | unit tests (phone, auth service, auth store) | tsx, node:test | S |
| tests/serve_dist.py | static server with deep-link fallback for web export tests | python | S |
| tests/auth_smoke.py | Playwright e2e: auth + role guards | playwright | S |
| supabase/_drafts/claude22/* | backend SQL draft A (recommended base), NOT applied | — | S |
| supabase/_drafts/files_zip/* | backend SQL draft B + its docs, NOT applied, reference only | — | S |
| supabase/_drafts/validation/* | stubs + run.sh + behaviour checks to execute drafts on PG16 | postgresql | S |
| docs/brand/servex_logo_candidate.png | candidate logo (name NOT confirmed) | — | S |
| docs/* | project documentation (this set) | — | S |
| scripts/ | empty (template script removed) | — | S |
