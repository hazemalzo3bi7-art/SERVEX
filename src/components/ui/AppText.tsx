import { Text, type TextProps } from 'react-native';
import { colors, typography, type TextVariant } from '@/constants/theme';

type Props = TextProps & { variant?: TextVariant; muted?: boolean; color?: string };

export function AppText({ variant = 'body', muted, color, style, ...rest }: Props) {
  return (
    <Text
      accessibilityRole={variant === 'display' || variant === 'title' ? 'header' : undefined}
      style={[typography[variant], { color: color ?? (muted ? colors.textMuted : colors.text) }, style]}
      {...rest}
    />
  );
}
