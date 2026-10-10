import { useRouter } from 'expo-router';
import { useState } from 'react';
import { View } from 'react-native';
import { AppText, Button, Card, TextField } from '@/components/ui';
import { colors, spacing } from '@/constants/theme';
import { AuthScreen } from '@/features/auth/AuthScreen';
import { t } from '@/i18n';
import { DEMO_MODE, DEMO_OTP, DEMO_USERS } from '@/services/demo/seed';
import { useAuthStore } from '@/state/authStore';
import { formatJordanPhone } from '@/utils/phone';

const LTR = '\u2066'; // LTR isolate: keeps digits in order inside RTL text
const PDI = '\u2069';
const demoPhone = (role: 'customer' | 'provider' | 'admin') => {
  const u = DEMO_USERS.find((x) => x.role === role);
  return u ? `${LTR}${formatJordanPhone(u.phone)}${PDI}` : '';
};

export default function Login() {
  const router = useRouter();
  const [phone, setPhone] = useState('');
  const { busy, errorKey, requestOtp, clearError } = useAuthStore();

  const submit = async () => {
    if (await requestOtp(phone)) router.push('/verify');
  };

  return (
    <AuthScreen title={t('auth.login.title')} subtitle={t('auth.login.subtitle')}>
      <TextField
        label={t('auth.phone.label')}
        helper={t('auth.phone.helper')}
        error={errorKey ? t(errorKey) : undefined}
        value={phone}
        onChangeText={(v) => { setPhone(v); if (errorKey) clearError(); }}
        keyboardType="phone-pad"
        inputMode="tel"
        autoComplete="tel"
        textContentType="telephoneNumber"
        returnKeyType="done"
        onSubmitEditing={submit}
        testID="phone-input"
      />
      <Button label={t('auth.continue')} onPress={submit} loading={busy} testID="continue-button" />

      {DEMO_MODE ? (
        <Card style={{ gap: spacing.xs, backgroundColor: colors.infoBg }}>
          <AppText variant="bodyStrong">{t('auth.demo.title')}</AppText>
          <AppText variant="caption">{t('auth.demo.body', { otp: DEMO_OTP })}</AppText>
          <AppText variant="caption" style={{ marginTop: spacing.xs }}>{t('auth.demo.accountsTitle')}</AppText>
          <AppText variant="caption">{t('auth.demo.account.customer', { phone: demoPhone('customer') })}</AppText>
          <AppText variant="caption">{t('auth.demo.account.provider', { phone: demoPhone('provider') })}</AppText>
          <AppText variant="caption">{t('auth.demo.account.admin', { phone: demoPhone('admin') })}</AppText>
        </Card>
      ) : null}

      {DEMO_MODE ? (
        <View>
          <Button label={t('role.devPreview')} variant="ghost" onPress={() => router.push('/dev/components')} />
        </View>
      ) : null}
    </AuthScreen>
  );
}
