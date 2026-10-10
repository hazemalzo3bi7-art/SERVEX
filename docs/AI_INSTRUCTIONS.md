# INSTRUCTIONS FOR ANY AI WORKING ON THIS PROJECT
1. Read README, PROJECT_STATUS, PROJECT_ARCHITECTURE, FILE_MAP, DECISIONS, DEVELOPMENT_LOG, SESSION_HANDOFF first. Files are the source of truth, not chat memory.
2. Expo changes every SDK: check `expo` version in package.json, read `https://docs.expo.dev/versions/v57.0.0/` and `https://docs.expo.dev/llms.txt` before touching Expo/RN APIs (see AGENTS.md). Install packages with `npx expo install <pkg>`.
3. Work in phases (master prompt §31): plan, build, test, review, fix, document, git checkpoint, update handoff. Never skip the handoff. Do not start a later phase before the owner says so.
4. Research before choosing libraries; record in RESEARCH.md/DECISIONS.md; never claim research you did not do.
5. Update FILE_MAP on every file add/move/delete. Run `npm run verify` and a RUNTIME navigation test — compile checks alone missed a real bug (D-003).
6. Owner is not an engineer: give click-by-click instructions.
7. Marketplace rules: customer CHOOSES the provider; central job state machine; central demo data; deterministic documented pricing; demo payment only (no real card data); Arabic-first RTL with i18n keys, no hardcoded strings; English for code/docs.
8. Priorities: security > correctness > UX > maintainability > scalability > performance > speed. Don't overbuild. Don't invent a brand name.
9. The full original master prompt is NOT stored in the repo yet. Owner should save it as `docs/MASTER_PROMPT.md` (see SESSION_HANDOFF).
10. Run `npm run verify`, `npm test` AND the Playwright tests (tests/auth_smoke.py, tests/design_smoke.py) before every checkpoint. Use `aria-*` props for state (D-022). Never put SQL from `supabase/_drafts/` into `supabase/migrations/` or apply it to a real project without the owner's decision (D-024). Never rename the app to "Servex" until the owner confirms (D-025). In sandbox scripts avoid `pkill -f <name>` patterns that match your own command line (use `pkill -f "[s]erve_dist"`).
