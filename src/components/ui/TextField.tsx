import { useState } from 'react';
import { StyleSheet, TextInput, View, type TextInputProps } from 'react-native';
import { colors, fonts, MIN_TOUCH, radius, spacing } from '@/constants/theme';
import { AppText } from './AppText';

type Props = TextInputProps & { label: string; error?: string; helper?: string };

export function TextField({ label, error, helper, style, onFocus, onBlur, ...rest }: Props) {
  const [focused, setFocused] = useState(false);
  return (
    <View style={styles.wrap}>
      <AppText variant="bodyStrong">{label}</AppText>
      <TextInput
        accessibilityLabel={label}
        placeholderTextColor={colors.textMuted}
        onFocus={(e) => { setFocused(true); onFocus?.(e); }}
        onBlur={(e) => { setFocused(false); onBlur?.(e); }}
        textAlignVertical={rest.multiline ? 'top' : 'center'}
        style={[styles.input, rest.multiline && styles.multiline, focused && styles.focused, !!error && styles.error, style]}
        {...rest}
      />
      {error ? <AppText variant="caption" color={colors.danger} accessibilityLiveRegion="polite">{error}</AppText>
        : helper ? <AppText variant="caption" muted>{helper}</AppText> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { gap: spacing.xs },
  input: { minHeight: MIN_TOUCH + 4, borderWidth: 1.5, borderColor: colors.border, borderRadius: radius.md, paddingHorizontal: spacing.md, paddingVertical: spacing.sm + 2, backgroundColor: colors.surfaceRaised, color: colors.text, fontFamily: fonts.regular, fontSize: 16 },
  multiline: { minHeight: 110 },
  focused: { borderColor: colors.primary },
  error: { borderColor: colors.danger },
});
