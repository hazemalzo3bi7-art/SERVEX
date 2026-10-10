const ARABIC_INDIC = '٠١٢٣٤٥٦٧٨٩';
const EXT_ARABIC_INDIC = '۰۱۲۳۴۵۶۷۸۹'; // Persian/Urdu digits

/** Converts Arabic-Indic / Persian digits to ASCII so people can type in either. */
export function toAsciiDigits(input: string): string {
  return input.replace(/[٠-٩۰-۹]/g, (ch) => {
    const i = ARABIC_INDIC.indexOf(ch);
    return String(i >= 0 ? i : EXT_ARABIC_INDIC.indexOf(ch));
  });
}

/**
 * Normalises a Jordanian MOBILE number to E.164 (+9627XXXXXXXX), or null if invalid.
 * Accepts: 0791234567, 791234567, +962791234567, 00962791234567, 962791234567, +962 0791234567,
 * with spaces/dashes/parentheses and Arabic digits. Mobile prefixes 77/78/79 only.
 * Country-specific by design: other countries add their own rules later (multi-country plan).
 */
export function normalizeJordanMobile(input: string): string | null {
  let s = toAsciiDigits(input).replace(/[\s\-().]/g, '');
  if (s.startsWith('+')) s = s.slice(1);
  else if (s.startsWith('00')) s = s.slice(2);
  if (s.startsWith('962')) s = s.slice(3);
  if (s.startsWith('0')) s = s.slice(1);
  return /^7[789]\d{7}$/.test(s) ? `+962${s}` : null;
}

/** "+962791234567" -> "+962 79 123 4567" (render inside an LTR isolate in RTL UI). */
export function formatJordanPhone(e164: string): string {
  const m = /^\+962(\d{2})(\d{3})(\d{4})$/.exec(e164);
  return m ? `+962 ${m[1]} ${m[2]} ${m[3]}` : e164;
}
