import type { PropsWithChildren } from 'react';
import { Modal, Pressable, StyleSheet, View } from 'react-native';
import Animated, { FadeIn, SlideInDown } from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { colors, radius, shadow, spacing } from '@/constants/theme';
import { AppText } from './AppText';

type Props = PropsWithChildren<{ visible: boolean; onClose: () => void; title: string; closeLabel: string }>;

/** Modal bottom sheet. Backdrop tap / system back closes it. Slides in; unmounts immediately on close. */
export function BottomSheet({ visible, onClose, title, closeLabel, children }: Props) {
  const insets = useSafeAreaInsets();
  if (!visible) return null;
  return (
    <Modal transparent visible animationType="none" onRequestClose={onClose} statusBarTranslucent>
      <View style={styles.fill}>
        <Animated.View entering={FadeIn.duration(180)} style={styles.fill}>
          <Pressable accessibilityRole="button" accessibilityLabel={closeLabel} style={[styles.fill, { backgroundColor: colors.overlay }]} onPress={onClose} />
        </Animated.View>
        <Animated.View
          entering={SlideInDown.duration(260)}
          accessibilityViewIsModal
          style={[styles.sheet, { paddingBottom: Math.max(insets.bottom, spacing.md) + spacing.sm }]}
        >
          <View style={styles.handle} />
          <AppText variant="heading" accessibilityRole="header">{title}</AppText>
          {children}
        </Animated.View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  fill: { position: 'absolute', top: 0, bottom: 0, start: 0, end: 0, justifyContent: 'flex-end' },
  sheet: { backgroundColor: colors.surfaceRaised, borderTopStartRadius: radius.lg, borderTopEndRadius: radius.lg, padding: spacing.lg, gap: spacing.md, ...shadow.sheet },
  handle: { alignSelf: 'center', width: 40, height: 4, borderRadius: 2, backgroundColor: colors.border, marginBottom: spacing.xs },
});
