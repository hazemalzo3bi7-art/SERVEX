import { ActivityIndicator, Pressable, StyleSheet, View } from 'react-native';
import { colors, MIN_TOUCH, radius, spacing } from '@/constants/theme';
import { AppText } from './AppText';

type Variant = 'primary' | 'secondary' | 'ghost';
type Props = {
  label: string;
  onPress?: () => void;
  variant?: Variant;
  loading?: boolean;
  disabled?: boolean;
  accessibilityLabel?: string;
  testID?: string;
};

export function Button({ label, onPress, variant = 'primary', loading, disabled, accessibilityLabel, testID }: Props) {
  const inactive = disabled || loading;
  const fg = variant === 'primary' ? colors.primaryText : colors.primary;
  return (
    <Pressable
      testID={testID}
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel ?? label}
      aria-disabled={!!inactive}
      aria-busy={!!loading}
      disabled={inactive}
      onPress={onPress}
      style={({ pressed }) => [
        styles.base,
        variant === 'primary' && { backgroundColor: pressed ? colors.primaryPressed : colors.primary },
        variant === 'secondary' && { backgroundColor: pressed ? colors.infoBg : colors.surfaceRaised, borderWidth: 1.5, borderColor: colors.primary },
        variant === 'ghost' && { backgroundColor: pressed ? colors.surface : 'transparent' },
        inactive && styles.inactive,
      ]}
    >
      <View style={styles.row}>
        {loading ? <ActivityIndicator color={fg} /> : null}
        <AppText variant="button" color={fg}>{label}</AppText>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  base: { minHeight: 52, minWidth: MIN_TOUCH, paddingHorizontal: spacing.lg, borderRadius: radius.md, alignItems: 'center', justifyContent: 'center' },
  row: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  inactive: { opacity: 0.5 },
});
