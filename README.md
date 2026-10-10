# PROJECT_APP (temporary name)

On-demand local services marketplace for **Jordan (Amman, Irbid)**: the customer picks a service, sees nearby providers, compares them, and requests one directly. Final brand name: **not chosen** (see docs/DECISIONS.md D-010).

**Status:** Phase 2 (demo auth + roles) complete. Brand name NOT confirmed (candidate: Servex). Read `docs/PROJECT_STATUS.md` first, then `docs/SESSION_HANDOFF.md`.

## Run it (first time)
1. Install Node.js 22 LTS from nodejs.org.
2. Open a terminal in this folder and run `npm install` (takes ~1 min).
3. Run `npm run web` -> opens the app in your browser. Success = Arabic right-to-left login screen with a blue "demo mode" box; log in with 0790000002 and code 123456 -> customer home with a greeting and a logout button. The ghost button معاينة التصميم shows all UI components.
4. For a phone: install **Expo Go** (must match SDK 57 — see docs/KNOWN_ISSUES.md KI-003), run `npm start`, scan the QR code.

## Checks
`npm run typecheck` · `npm run lint` · `npm run verify` (both) · `npm test` (24 unit tests)
Demo login: any Jordanian mobile number (e.g. 0791234567) + code 123456. Ready-made: 0790000002 customer, 0790000003 provider, 0790000001 admin.

## Docs
All in `docs/`. Stack: Expo SDK 57, React Native 0.86, TypeScript, Expo Router (routes in `src/app/`).
