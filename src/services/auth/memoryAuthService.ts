import { parseWith, phoneSchema, profileSchema } from '@/features/auth/schemas';
import { DEMO_OTP, DEMO_USERS } from '@/services/demo/seed';
import type { User } from '@/types/auth';
import { AuthError, type AuthService } from './types';

type Options = { seed?: User[]; otp?: string; now?: () => number; maxAttempts?: number; lockMs?: number; latencyMs?: number };

/** In-memory DEMO implementation. Not secure: the code is a known constant. Replaced in Phase 22. */
export function createMemoryAuthService(opts: Options = {}): AuthService {
  const { seed = DEMO_USERS, otp = DEMO_OTP, now = Date.now, maxAttempts = 5, lockMs = 60_000, latencyMs = 0 } = opts;
  const users = new Map<string, User>(seed.map((u) => [u.phone, { ...u }]));
  const pending = new Set<string>(); // phones with a requested code
  const verified = new Set<string>(); // phones verified but not yet registered
  const attempts = new Map<string, { count: number; lockedUntil: number }>();
  let counter = users.size;

  const wait = () => (latencyMs > 0 ? new Promise<void>((r) => setTimeout(r, latencyMs)) : Promise.resolve());
  const normalize = (raw: string): string => {
    const p = parseWith(phoneSchema, raw);
    if (!p.ok) throw new AuthError('invalid_phone');
    return p.value;
  };
  const assertNotLocked = (phone: string) => {
    const a = attempts.get(phone);
    if (a && a.lockedUntil > now()) throw new AuthError('too_many_attempts', a.lockedUntil - now());
  };

  return {
    async requestOtp(raw) {
      await wait();
      const phone = normalize(raw);
      assertNotLocked(phone);
      pending.add(phone); // demo: nothing is sent
      return phone;
    },

    async verifyOtp(raw, code) {
      await wait();
      const phone = normalize(raw);
      assertNotLocked(phone);
      if (!pending.has(phone)) throw new AuthError('no_pending_verification');

      if (code !== otp) {
        const a = attempts.get(phone) ?? { count: 0, lockedUntil: 0 };
        a.count += 1;
        if (a.count >= maxAttempts) {
          a.count = 0;
          a.lockedUntil = now() + lockMs;
          attempts.set(phone, a);
          pending.delete(phone);
          throw new AuthError('too_many_attempts', lockMs);
        }
        attempts.set(phone, a);
        throw new AuthError('invalid_code');
      }

      attempts.delete(phone);
      pending.delete(phone);
      const existing = users.get(phone);
      if (existing) {
        if (existing.status === 'suspended') throw new AuthError('account_suspended');
        return { status: 'signed_in', user: { ...existing } };
      }
      verified.add(phone);
      return { status: 'needs_profile', phone };
    },

    async completeRegistration(raw, profile) {
      await wait();
      const phone = normalize(raw);
      if (!verified.has(phone)) throw new AuthError('no_pending_verification');
      if (users.has(phone)) throw new AuthError('phone_taken');
      const parsed = parseWith(profileSchema, profile); // rejects role "admin" and bad names
      if (!parsed.ok) throw new AuthError('invalid_profile');
      counter += 1;
      const user: User = {
        id: `usr_${counter}`,
        phone,
        name: parsed.value.name,
        role: parsed.value.role,
        status: 'active',
        createdAt: new Date(now()).toISOString(),
      };
      users.set(phone, user);
      verified.delete(phone);
      return { ...user };
    },

    async signOut() {
      await wait();
    },
  };
}
