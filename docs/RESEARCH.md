# RESEARCH LOG
**Environment note:** web search WAS available this session. Research below is real; items marked NOT YET DONE were not researched.

## Done (2026-10-01)
- **Expo versions:** SDK 55 released Feb 25 2026; SDK 57 is what `create-expo-app` offers as "Latest"; SDK 58 beta Sep 15 2026 (built for iOS 27; Expo Go store versions update to 58 shortly after stable). Sources: expo.dev changelog, docs.expo.dev/more/create-expo.
- **Expo Router:** file-based, superset of React Navigation, typed routes. SDK 58 beta notes stable data loaders + native tabs. Source: docs.expo.dev/router/introduction.
- **Expo guidance for AI agents:** generated `AGENTS.md` says fetch versioned docs (`docs.expo.dev/versions/v57.0.0/`, `docs.expo.dev/llms.txt`) and use `npx expo install <pkg>` for dependencies. **Future sessions must follow this.**
- **Competitor (Fanni / فني)** — store listings only (Google Play/App Store), no hands-on use: markets 300+ home services, nearest technicians, **free inspection**, multiple payment options, support, **30-day follow-up/warranty**, instant or scheduled orders, "most ordered" on home screen. Third-party descriptions say users can choose a worker by map or rating. One Play review (anecdotal, single) complained of an inspection fee charged despite "free" claim and no replacement technician — a *possible* trust gap around fee transparency + reassignment; verify with more reviews before relying on it.
- **Other Jordan apps seen:** "Jordan Home Care" (Play Store): verified technicians, transparent pricing, tracking, ratings, history. A "FANNI JO" listing (id com.webviewgold.fannijo) looks like a WebView-wrapped app — not confirmed to be the same company as Fanni.

## Phase 1 research (2026-10-01)
- **RTL:** Expo localization docs: layout direction follows RN `I18nManager`; SDK 58+ enables RTL by default (earlier: enabled except in Expo Go). RN docs: `forceRTL` is mainly for testing; Intlayer/Expo GitHub issues (#35394, #39752) confirm `forceRTL` needs an app reload to take effect, so switching direction dynamically is risky -> we fix RTL for the Arabic-only launch (D-011). `dir="rtl"` on web applies immediately. Use `start/end`, avoid absolute left/right.
- **Font:** chose IBM Plex Sans Arabic by judgment (not benchmarked against alternatives); license field in the npm package says MIT AND OFL-1.1.
- **NOT done (deferred, say so honestly):** Uber/Careem/Wolt/Talabat/Airbnb UX study — scheduled just before Phase 3 (home) and Phase 6 (provider discovery) where it matters; state-management and forms libraries — Phase 2.

## Design takeaways (principles, not copying)
Show the fee rules BEFORE requesting; make any "free inspection" terms explicit; define what happens if a provider no-shows (re-offer providers); offer scheduled + instant; surface most-ordered services; show warranty/follow-up terms.

## NOT YET DONE (scheduled)
Uber/Careem/Wolt/Talabat/Airbnb UX patterns (before Phase 1/3/6) · state management & forms & animation libs (Phase 1) · RTL in React Native/Expo (Phase 1) · maps/geocoding providers + Jordan coverage (Phase 5/23) · Supabase/RLS (Phase 20/22) · payments in Jordan (Phase 25) · push (Phase 24) · App/Play store requirements (Phase 27/28).
