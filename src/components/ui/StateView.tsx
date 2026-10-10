import { StyleSheet, View } from 'react-native';
import { colors, spacing } from '@/constants/theme';
import { AppText } from './AppText';
import { Button } from './Button';

type Props = { title: string; message?: string; actionLabel?: string; onAction?: () => void; tone?: 'neutral' | 'error' };

/** Shared empty / error state: always explains what happened and offers a next step (no dead ends). */
export function StateView({ title, message, actionLabel, onAction, tone = 'neutral' }: Props) {
  const bg = tone === 'error' ? colors.dangerBg : colors.infoBg;
  const fg = tone === 'error' ? colors.danger : colors.primary;
  return (
    <View style={styles.wrap} accessibilityRole={tone === 'error' ? 'alert' : undefined}>
      <View style={[styles.badge, { backgroundColor: bg }]}>
        <AppText variant="title" color={fg}>{tone === 'error' ? '!' : '؟'}</AppText>
      </View>
      <AppText variant="heading" style={styles.center}>{title}</AppText>
      {message ? <AppText muted style={styles.center}>{message}</AppText> : null}
      {actionLabel && onAction ? <Button label={actionLabel} onPress={onAction} variant="secondary" /> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { alignItems: 'center', gap: spacing.sm, padding: spacing.lg },
  badge: { width: 64, height: 64, borderRadius: 32, alignItems: 'center', justifyContent: 'center', marginBottom: spacing.sm },
  center: { textAlign: 'center' },
});
