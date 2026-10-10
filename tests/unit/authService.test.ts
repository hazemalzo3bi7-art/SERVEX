import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createMemoryAuthService } from '@/services/auth/memoryAuthService';
import { AuthError } from '@/services/auth/types';
import { DEMO_OTP } from '@/services/demo/seed';

const rejects = async (p: Promise<unknown>, code: string) =>
  assert.rejects(p, (e: unknown) => e instanceof AuthError && e.code === code);

test('existing demo user signs in with the demo code', async () => {
  const s = createMemoryAuthService();
  const phone = await s.requestOtp('0790000002');
  const r = await s.verifyOtp(phone, DEMO_OTP);
  assert.equal(r.status, 'signed_in');
  if (r.status === 'signed_in') assert.equal(r.user.role, 'customer');
});

test('invalid phone is rejected', async () => rejects(createMemoryAuthService().requestOtp('123'), 'invalid_phone'));

test('verify without requesting a code is rejected', async () =>
  rejects(createMemoryAuthService().verifyOtp('0790000002', DEMO_OTP), 'no_pending_verification'));

test('wrong code is rejected, correct code still works afterwards', async () => {
  const s = createMemoryAuthService();
  const phone = await s.requestOtp('0790000002');
  await rejects(s.verifyOtp(phone, '000000'), 'invalid_code');
  assert.equal((await s.verifyOtp(phone, DEMO_OTP)).status, 'signed_in');
});

test('5 wrong codes lock the phone for 60s, then it unlocks', async () => {
  let t = 1_000_000;
  const s = createMemoryAuthService({ now: () => t });
  const phone = await s.requestOtp('0790000002');
  for (let i = 0; i < 4; i++) await rejects(s.verifyOtp(phone, '000000'), 'invalid_code');
  await rejects(s.verifyOtp(phone, '000000'), 'too_many_attempts');
  await rejects(s.requestOtp(phone), 'too_many_attempts'); // still locked
  await rejects(s.verifyOtp(phone, DEMO_OTP), 'too_many_attempts'); // even the right code is refused while locked
  t += 60_001;
  await s.requestOtp(phone);
  assert.equal((await s.verifyOtp(phone, DEMO_OTP)).status, 'signed_in');
});

test('new phone: verify -> needs_profile -> register creates an active user', async () => {
  const s = createMemoryAuthService();
  const phone = await s.requestOtp('0771234567');
  const v = await s.verifyOtp(phone, DEMO_OTP);
  assert.equal(v.status, 'needs_profile');
  const u = await s.completeRegistration(phone, { name: '  رنا   الخطيب ', role: 'provider' });
  assert.equal(u.name, 'رنا الخطيب'); // trimmed + collapsed
  assert.equal(u.role, 'provider');
  assert.equal(u.status, 'active');
  // second login is a normal sign-in
  const p2 = await s.requestOtp(phone);
  assert.equal((await s.verifyOtp(p2, DEMO_OTP)).status, 'signed_in');
});

test('registration requires verification first', async () =>
  rejects(createMemoryAuthService().completeRegistration('+962771234567', { name: 'Test User', role: 'customer' }), 'no_pending_verification'));

test('admin can NEVER be self-registered', async () => {
  const s = createMemoryAuthService();
  const phone = await s.requestOtp('0771234567');
  await s.verifyOtp(phone, DEMO_OTP);
  await rejects(s.completeRegistration(phone, { name: 'Eve Admin', role: 'admin' }), 'invalid_profile');
  await rejects(s.completeRegistration(phone, { name: 'Eve Admin', role: 'superuser' }), 'invalid_profile');
});

test('too-short name is rejected', async () => {
  const s = createMemoryAuthService();
  const phone = await s.requestOtp('0771234567');
  await s.verifyOtp(phone, DEMO_OTP);
  await rejects(s.completeRegistration(phone, { name: 'A', role: 'customer' }), 'invalid_profile');
});

test('verified phone cannot be registered twice', async () => {
  const s = createMemoryAuthService();
  const phone = await s.requestOtp('0771234567');
  await s.verifyOtp(phone, DEMO_OTP);
  await s.completeRegistration(phone, { name: 'Lina Said', role: 'customer' });
  await rejects(s.completeRegistration(phone, { name: 'Lina Said', role: 'customer' }), 'no_pending_verification');
});

test('suspended users cannot sign in', async () => {
  const s = createMemoryAuthService({
    seed: [{ id: 'u1', phone: '+962790000009', name: 'Suspended User', role: 'customer', status: 'suspended', createdAt: '2026-01-01T00:00:00.000Z' }],
  });
  const phone = await s.requestOtp('0790000009');
  await rejects(s.verifyOtp(phone, DEMO_OTP), 'account_suspended');
});
