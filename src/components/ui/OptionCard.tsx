import { Pressable, StyleSheet, View } from 'react-native';
import { colors, MIN_TOUCH, radius, spacing } from '@/constants/theme';
import { AppText } from './AppText';

type Props = { title: string; description?: string; selected: boolean; onPress: () => void; testID?: string };

/** Single-choice option (radio semantics). Selection is shown by border + filled dot, not colour alone. */
export function OptionCard({ title, description, selected, onPress, testID }: Props) {
  return (
    <Pressable
      testID={testID}
      accessibilityRole="radio"
      aria-checked={selected}
      accessibilityLabel={description ? `${title}. ${description}` : title}
      onPress={onPress}
      style={[styles.card, selected && styles.selected]}
    >
      <View style={[styles.radio, selected && styles.radioOn]}>{selected ? <View style={styles.dot} /> : null}</View>
      <View style={styles.text}>
        <AppText variant="bodyStrong">{title}</AppText>
        {description ? <AppText variant="caption" muted>{description}</AppText> : null}
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, minHeight: MIN_TOUCH + 16, padding: spacing.md, borderRadius: radius.lg, borderWidth: 1.5, borderColor: colors.border, backgroundColor: colors.surfaceRaised },
  selected: { borderColor: colors.primary, backgroundColor: colors.infoBg },
  radio: { width: 24, height: 24, borderRadius: 12, borderWidth: 2, borderColor: colors.textMuted, alignItems: 'center', justifyContent: 'center' },
  radioOn: { borderColor: colors.primary },
  dot: { width: 12, height: 12, borderRadius: 6, backgroundColor: colors.primary },
  text: { flex: 1, gap: 2 },
});
