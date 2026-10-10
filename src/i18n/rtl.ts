import { I18nManager, Platform } from 'react-native';

// Arabic-first launch => layout is RTL (DECISIONS D-011). Web direction is set in src/app/+html.tsx.
// Native: I18nManager flags take effect after the app reloads, so the VERY FIRST launch after install
// may still render LTR (KNOWN_ISSUES KI-001); later phases add a reload step if needed.
export function applyLayoutDirection(): void {
  if (Platform.OS === 'web') return;
  I18nManager.allowRTL(true);
  I18nManager.forceRTL(true);
}
