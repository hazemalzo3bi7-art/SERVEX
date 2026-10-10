import assert from 'node:assert/strict';
import { test } from 'node:test';
import { formatJordanPhone, normalizeJordanMobile } from '@/utils/phone';

test('accepts common Jordanian mobile formats', () => {
  for (const input of ['0791234567', '791234567', '+962791234567', '00962791234567', '962791234567', '+962 0791234567', '079-123-4567', '(079) 123 4567']) {
    assert.equal(normalizeJordanMobile(input), '+962791234567', input);
  }
});
test('accepts Arabic-Indic digits', () => assert.equal(normalizeJordanMobile('٠٧٩١٢٣٤٥٦٧'), '+962791234567'));
test('accepts 77/78/79 prefixes only', () => {
  assert.equal(normalizeJordanMobile('0771234567'), '+962771234567');
  assert.equal(normalizeJordanMobile('0781234567'), '+962781234567');
  assert.equal(normalizeJordanMobile('0761234567'), null);
  assert.equal(normalizeJordanMobile('0651234567'), null); // landline area code
});
test('rejects wrong length, letters, empty', () => {
  for (const input of ['', '079123456', '07912345678', '07a1234567', 'abc', '+971501234567', '   ']) {
    assert.equal(normalizeJordanMobile(input), null, input);
  }
});
test('formats for display', () => assert.equal(formatJordanPhone('+962791234567'), '+962 79 123 4567'));
