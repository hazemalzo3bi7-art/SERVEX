import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createAuthStore } from '@/state/authStore';
import { createMemoryAuthService } from '@/services/auth/memoryAuthService';
import { DEMO_OTP } from '@/services/demo/seed';

const fresh = () => createAuthStore(createMemoryAuthService());

test('full existing-user login flow', async () => {
  const s = fresh();
  assert.equal(await s.getState().requestOtp('079 000 0003'), true);
  assert.equal(s.getState().pendingPhone, '+962790000003');
  assert.equal(await s.getState().verifyOtp(DEMO_OTP), 'signed_in');
  assert.equal(s.getState().user?.role, 'provider');
  await s.getState().signOut();
  assert.equal(s.getState().user, null);
});

test('invalid phone sets a translatable error key and does not call the service', async () => {
  const s = fresh();
  assert.equal(await s.getState().requestOtp('nope'), false);
  assert.equal(s.getState().errorKey, 'error.phone.invalid');
  assert.equal(s.getState().pendingPhone, null);
});

test('code must be 6 digits; Arabic digits accepted', async () => {
  const s = fresh();
  await s.getState().requestOtp('0790000002');
  assert.equal(await s.getState().verifyOtp('12'), 'error');
  assert.equal(s.getState().errorKey, 'error.code.format');
  assert.equal(await s.getState().verifyOtp('١٢٣٤٥٦'), 'signed_in');
});

test('wrong code sets error, user stays signed out', async () => {
  const s = fresh();
  await s.getState().requestOtp('0790000002');
  assert.equal(await s.getState().verifyOtp('111111'), 'error');
  assert.equal(s.getState().errorKey, 'error.code.invalid');
  assert.equal(s.getState().user, null);
});

test('new user registration flow', async () => {
  const s = fresh();
  await s.getState().requestOtp('0781112222');
  assert.equal(await s.getState().verifyOtp(DEMO_OTP), 'needs_profile');
  assert.equal(await s.getState().completeRegistration({ name: 'ياسمين حداد', role: 'customer' }), true);
  assert.equal(s.getState().user?.role, 'customer');
});

test('cannot register without verifying; cannot become admin', async () => {
  const s = fresh();
  assert.equal(await s.getState().completeRegistration({ name: 'Eve Admin', role: 'admin' }), false);
  assert.equal(s.getState().errorKey, 'error.session.expired');
  await s.getState().requestOtp('0781112222');
  await s.getState().verifyOtp(DEMO_OTP);
  assert.equal(await s.getState().completeRegistration({ name: 'Eve Admin', role: 'admin' }), false);
  assert.equal(s.getState().user, null);
});

test('double submit while busy is ignored', async () => {
  const s = createAuthStore(createMemoryAuthService({ latencyMs: 20 }));
  const [a, b] = await Promise.all([s.getState().requestOtp('0790000002'), s.getState().requestOtp('0790000002')]);
  assert.deepEqual([a, b], [true, false]);
});

test('registration errors name the field that is wrong (name vs role)', async () => {
  const s = fresh();
  await s.getState().requestOtp('0781112222');
  await s.getState().verifyOtp(DEMO_OTP);
  assert.equal(await s.getState().completeRegistration({ name: '', role: 'customer' }), false);
  assert.equal(s.getState().errorKey, 'error.name.invalid');
  assert.equal(await s.getState().completeRegistration({ name: 'ياسمين حداد', role: '' }), false);
  assert.equal(s.getState().errorKey, 'error.role.invalid'); // regression: used to say "invalid name"
  assert.equal(await s.getState().completeRegistration({ name: 'ياسمين حداد', role: 'provider' }), true);
});
