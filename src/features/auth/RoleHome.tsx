import { useRouter } from 'expo-router';
import { StyleSheet, View } from 'react-native';
import { AppText, Button } from '@/components/ui';
import { colors, spacing } from '@/constants/theme';
import { t, type TranslationKey } from '@/i18n';
import { useAuthStore } from '@/state/authStore';

/** TEMPORARY home for each role until their real experiences are built (customer: Phase 3, provider: 9/18, admin: 19). */
export function RoleHome({ messageKey }: { messageKey: TranslationKey }) {
  const router = useRouter();
  const name = useAuthStore((s) => s.user?.name ?? '');
  const signOut = useAuthStore((s) => s.signOut);
  return (
    <View style={styles.container}>
      <AppText variant="title" style={styles.center}>{t('auth.greeting', { name })}</AppText>
      <AppText muted style={styles.center}>{t(messageKey)}</AppText>
      <Button
        label={t('auth.logout')}
        variant="secondary"
        onPress={async () => {
          await signOut();
          router.replace('/');
        }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, alignItems: 'center', justifyContent: 'center', gap: spacing.lg, backgroundColor: colors.background, padding: spacing.lg },
  center: { textAlign: 'center' },
});
