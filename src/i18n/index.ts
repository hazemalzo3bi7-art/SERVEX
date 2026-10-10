import { ar } from './ar';
import { en } from './en';

export type TranslationKey = keyof typeof ar;
export type Locale = 'ar' | 'en';

const dictionaries: Record<Locale, Record<TranslationKey, string>> = { ar, en };

// Fixed default locale for now (DECISIONS D-005/D-011). Device/user locale selection comes with English support.
export const DEFAULT_LOCALE: Locale = 'ar';

/** Translate a key. `{name}`-style placeholders are replaced from `params`. */
export function t(key: TranslationKey, params?: Record<string, string | number>, locale: Locale = DEFAULT_LOCALE): string {
  const template = dictionaries[locale][key] ?? dictionaries.en[key] ?? key;
  if (!params) return template;
  return template.replace(/\{(\w+)\}/g, (m, name: string) => (name in params ? String(params[name]) : m));
}
