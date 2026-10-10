import { Redirect, useRouter } from 'expo-router';
import { useState } from 'react';
import { AppText, Button, TextField } from '@/components/ui';
import { AuthScreen } from '@/features/auth/AuthScreen';
import { t } from '@/i18n';
import { useAuthStore } from '@/state/authStore';
import { formatJordanPhone } from '@/utils/phone';

export default function Verify() {
  const router = useRouter();
  const [code, setCode] = useState('');
  const { pendingPhone, verifiedPhone, busy, errorKey, verifyOtp, clearError } = useAuthStore();
  // After a successful code for a NEW user, pendingPhone clears and verifiedPhone is set while we navigate to /register.
  const phone = pendingPhone ?? verifiedPhone;

  // Direct visit / expired flow: nothing to verify -> back to login.
  if (!phone) return <Redirect href="/login" />;

  const submit = async () => {
    const outcome = await verifyOtp(code);
    if (outcome === 'signed_in') router.replace('/');
    else if (outcome === 'needs_profile') router.push('/register');
  };

  return (
    <AuthScreen title={t('auth.verify.title')} subtitle={t('auth.verify.subtitle', { phone: `\u2066${formatJordanPhone(phone)}\u2069` })}>
      <TextField
        label={t('auth.code.label')}
        error={errorKey ? t(errorKey) : undefined}
        value={code}
        onChangeText={(v) => { setCode(v); if (errorKey) clearError(); }}
        keyboardType="number-pad"
        inputMode="numeric"
        maxLength={6}
        autoComplete="one-time-code"
        textContentType="oneTimeCode"
        onSubmitEditing={submit}
        testID="code-input"
      />
      <Button label={t('auth.verify.submit')} onPress={submit} loading={busy} testID="verify-button" />
      <Button label={t('auth.verify.changeNumber')} variant="ghost" onPress={() => { clearError(); router.back(); }} />
      <AppText variant="caption" muted style={{ textAlign: 'center' }}>{t('auth.demo.title')}</AppText>
    </AuthScreen>
  );
}
