import { Redirect, useRouter } from 'expo-router';
import { useState } from 'react';
import { View } from 'react-native';
import { AppText, Button, OptionCard, TextField } from '@/components/ui';
import { spacing } from '@/constants/theme';
import { AuthScreen } from '@/features/auth/AuthScreen';
import { t } from '@/i18n';
import { useAuthStore } from '@/state/authStore';
import type { SignUpRole } from '@/types/auth';

export default function Register() {
  const router = useRouter();
  const [name, setName] = useState('');
  const [role, setRole] = useState<SignUpRole | null>(null);
  const { verifiedPhone, busy, errorKey, completeRegistration, clearError } = useAuthStore();

  if (!verifiedPhone) return <Redirect href="/login" />;

  const submit = async () => {
    if (await completeRegistration({ name, role: role ?? '' })) router.replace('/');
  };

  return (
    <AuthScreen title={t('auth.register.title')} subtitle={t('auth.register.subtitle')}>
      <TextField
        label={t('auth.name.label')}
        value={name}
        onChangeText={(v) => { setName(v); if (errorKey) clearError(); }}
        autoComplete="name"
        textContentType="name"
        testID="name-input"
      />
      <View style={{ gap: spacing.sm }} accessibilityRole="radiogroup">
        <AppText variant="bodyStrong">{t('auth.role.label')}</AppText>
        <OptionCard testID="role-customer" title={t('auth.role.customer.title')} description={t('auth.role.customer.desc')} selected={role === 'customer'} onPress={() => { setRole('customer'); clearError(); }} />
        <OptionCard testID="role-provider" title={t('auth.role.provider.title')} description={t('auth.role.provider.desc')} selected={role === 'provider'} onPress={() => { setRole('provider'); clearError(); }} />
      </View>
      {errorKey ? <AppText variant="caption" color="#B3261E" accessibilityLiveRegion="polite">{t(errorKey)}</AppText> : null}
      <Button label={t('auth.register.submit')} onPress={submit} loading={busy} testID="register-button" />
    </AuthScreen>
  );
}
