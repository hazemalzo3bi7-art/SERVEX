import type { User } from '@/types/auth';

export type AuthErrorCode =
  | 'invalid_phone'
  | 'invalid_code'
  | 'too_many_attempts'
  | 'no_pending_verification'
  | 'invalid_profile'
  | 'phone_taken'
  | 'account_suspended';

export class AuthError extends Error {
  constructor(public readonly code: AuthErrorCode, public readonly retryAfterMs?: number) {
    super(code);
    this.name = 'AuthError';
  }
}

export type VerifyResult = { status: 'signed_in'; user: User } | { status: 'needs_profile'; phone: string };

/**
 * Auth boundary. UI/state only depend on this interface; Phase 22 replaces the in-memory
 * implementation with Supabase Auth (real OTP via SMS provider) without touching screens.
 */
export interface AuthService {
  /** Starts phone verification. Returns the normalised E.164 phone. */
  requestOtp(phone: string): Promise<string>;
  verifyOtp(phone: string, code: string): Promise<VerifyResult>;
  /** Only allowed after a successful verifyOtp for that phone. Never creates admins. */
  completeRegistration(phone: string, profile: { name: string; role: string }): Promise<User>;
  signOut(): Promise<void>;
}
