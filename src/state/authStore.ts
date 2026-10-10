import { create } from 'zustand';
import { otpSchema, parseWith, phoneSchema, profileSchema } from '@/features/auth/schemas';
import type { TranslationKey } from '@/i18n';
import { AuthError, authService as defaultService, type AuthService } from '@/services/auth';
import type { User } from '@/types/auth';

type VerifyOutcome = 'signed_in' | 'needs_profile' | 'error';

export interface AuthState {
  user: User | null;
  pendingPhone: string | null; // code requested for this phone
  verifiedPhone: string | null; // verified, waiting for profile
  busy: boolean;
  errorKey: TranslationKey | null;
  requestOtp(phone: string): Promise<boolean>;
  verifyOtp(code: string): Promise<VerifyOutcome>;
  completeRegistration(input: { name: string; role: string }): Promise<boolean>;
  signOut(): Promise<void>;
  clearError(): void;
}

const errorKeyFor = (e: unknown): TranslationKey => {
  if (!(e instanceof AuthError)) return 'error.generic';
  switch (e.code) {
    case 'invalid_phone': return 'error.phone.invalid';
    case 'invalid_code': return 'error.code.invalid';
    case 'too_many_attempts': return 'error.code.tooMany';
    case 'no_pending_verification': return 'error.session.expired';
    case 'phone_taken': return 'error.account.exists';
    case 'account_suspended': return 'error.account.suspended';
    default: return 'error.generic';
  }
};

/** Factory so tests can inject a service. The app uses `useAuthStore` below. */
export function createAuthStore(service: AuthService) {
  return create<AuthState>()((set, get) => ({
    user: null,
    pendingPhone: null,
    verifiedPhone: null,
    busy: false,
    errorKey: null,

    async requestOtp(raw) {
      if (get().busy) return false;
      const p = parseWith(phoneSchema, raw);
      if (!p.ok) { set({ errorKey: p.errorKey }); return false; }
      set({ busy: true, errorKey: null });
      try {
        const phone = await service.requestOtp(p.value);
        set({ pendingPhone: phone, verifiedPhone: null, busy: false });
        return true;
      } catch (e) {
        set({ busy: false, errorKey: errorKeyFor(e) });
        return false;
      }
    },

    async verifyOtp(raw) {
      const { pendingPhone, busy } = get();
      if (busy) return 'error';
      if (!pendingPhone) { set({ errorKey: 'error.session.expired' }); return 'error'; }
      const c = parseWith(otpSchema, raw);
      if (!c.ok) { set({ errorKey: c.errorKey }); return 'error'; }
      set({ busy: true, errorKey: null });
      try {
        const r = await service.verifyOtp(pendingPhone, c.value);
        if (r.status === 'signed_in') {
          set({ user: r.user, pendingPhone: null, verifiedPhone: null, busy: false });
          return 'signed_in';
        }
        set({ verifiedPhone: r.phone, pendingPhone: null, busy: false });
        return 'needs_profile';
      } catch (e) {
        // A lock clears the pending request: the user must start again after the cool-down.
        set({ busy: false, errorKey: errorKeyFor(e), ...(e instanceof AuthError && e.code === 'too_many_attempts' ? { pendingPhone: null } : {}) });
        return 'error';
      }
    },

    async completeRegistration(input) {
      const { verifiedPhone, busy } = get();
      if (busy) return false;
      if (!verifiedPhone) { set({ errorKey: 'error.session.expired' }); return false; }
      // Validate first so the message names the field that is actually wrong (name vs role).
      const p = parseWith(profileSchema, input);
      if (!p.ok) { set({ errorKey: p.errorKey }); return false; }
      set({ busy: true, errorKey: null });
      try {
        const user = await service.completeRegistration(verifiedPhone, p.value);
        set({ user, verifiedPhone: null, pendingPhone: null, busy: false });
        return true;
      } catch (e) {
        set({ busy: false, errorKey: errorKeyFor(e) });
        return false;
      }
    },

    async signOut() {
      await service.signOut();
      set({ user: null, pendingPhone: null, verifiedPhone: null, errorKey: null, busy: false });
    },

    clearError() {
      set({ errorKey: null });
    },
  }));
}

export const useAuthStore = createAuthStore(defaultService);
