import { useEffect } from 'react';
import type { DimensionValue, ViewStyle } from 'react-native';
import Animated, { useAnimatedStyle, useReducedMotion, useSharedValue, withRepeat, withTiming } from 'react-native-reanimated';
import { colors, radius } from '@/constants/theme';

type Props = { width?: DimensionValue; height?: number; style?: ViewStyle };

/** Loading placeholder. Pulses, but stays static when the user prefers reduced motion. */
export function Skeleton({ width = '100%', height = 16, style }: Props) {
  const reduced = useReducedMotion();
  const opacity = useSharedValue(1);
  useEffect(() => {
    if (!reduced) opacity.value = withRepeat(withTiming(0.45, { duration: 800 }), -1, true);
  }, [reduced, opacity]);
  const anim = useAnimatedStyle(() => ({ opacity: opacity.value }));
  return (
    <Animated.View
      accessibilityElementsHidden
      importantForAccessibility="no-hide-descendants"
      style={[{ width, height, borderRadius: radius.sm, backgroundColor: colors.border }, anim, style]}
    />
  );
}
