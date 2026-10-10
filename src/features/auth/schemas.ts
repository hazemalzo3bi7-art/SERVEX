import { z } from 'zod';
import type { TranslationKey } from '@/i18n';
import { normalizeJordanMobile, toAsciiDigits } from '@/utils/phone';

// Error messages are i18n KEYS, translated by the UI with t(). Reusable later on the server.
export const phoneSchema = z
  .string()
  .refine((v) => normalizeJordanMobile(v) !== null, { error: 'error.phone.invalid' })
  .transform((v) => normalizeJordanMobile(v) as string);

export const otpSchema = z
  .string()
  .transform((v) => toAsciiDigits(v).trim())
  .pipe(z.string().regex(/^\d{6}$/, { error: 'error.code.format' }));

export const profileSchema = z.object({
  name: z
    .string()
    .transform((v) => v.trim().replace(/\s+/g, ' '))
    .pipe(z.string().min(2, { error: 'error.name.invalid' }).max(60, { error: 'error.name.invalid' })),
  role: z.enum(['customer', 'provider'], { error: 'error.role.invalid' }),
});

export type ParseResult<T> = { ok: true; value: T } | { ok: false; errorKey: TranslationKey };

export function parseWith<T>(schema: z.ZodType<T>, value: unknown): ParseResult<T> {
  const r = schema.safeParse(value);
  if (r.success) return { ok: true, value: r.data };
  const msg = r.error.issues[0]?.message ?? '';
  return { ok: false, errorKey: (msg.startsWith('error.') ? msg : 'error.generic') as TranslationKey };
}
