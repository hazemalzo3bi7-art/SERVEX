import { createContext, useCallback, useContext, useMemo, useRef, useState, type PropsWithChildren } from 'react';
import { StyleSheet, View } from 'react-native';
import Animated, { FadeInUp, FadeOutUp } from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { colors, radius, shadow, spacing } from '@/constants/theme';
import { AppText } from './AppText';

type ToastType = 'success' | 'error' | 'info';
type ToastState = { id: number; message: string; type: ToastType } | null;
const ToastContext = createContext<{ show: (message: string, type?: ToastType) => void }>({ show: () => {} });

export const useToast = () => useContext(ToastContext);

export function ToastProvider({ children }: PropsWithChildren) {
  const [toast, setToast] = useState<ToastState>(null);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const insets = useSafeAreaInsets();

  const show = useCallback((message: string, type: ToastType = 'info') => {
    if (timer.current) clearTimeout(timer.current);
    setToast({ id: Date.now(), message, type });
    timer.current = setTimeout(() => setToast(null), 3500);
  }, []);
  const value = useMemo(() => ({ show }), [show]);
  const palette = { success: [colors.successBg, colors.success], error: [colors.dangerBg, colors.danger], info: [colors.infoBg, colors.info] }[toast?.type ?? 'info'];

  return (
    <ToastContext.Provider value={value}>
      {children}
      {toast ? (
        <View pointerEvents="none" style={[styles.host, { top: insets.top + spacing.sm }]}>
          <Animated.View
            key={toast.id}
            entering={FadeInUp.duration(220)}
            exiting={FadeOutUp.duration(180)}
            accessibilityRole="alert"
            accessibilityLiveRegion="polite"
            style={[styles.toast, { backgroundColor: palette[0], borderColor: palette[1] }]}
          >
            <AppText variant="bodyStrong" color={palette[1]}>{toast.message}</AppText>
          </Animated.View>
        </View>
      ) : null}
    </ToastContext.Provider>
  );
}

const styles = StyleSheet.create({
  host: { position: 'absolute', start: spacing.md, end: spacing.md, alignItems: 'center' },
  toast: { maxWidth: 520, width: '100%', borderWidth: 1, borderRadius: radius.md, paddingVertical: spacing.sm + 2, paddingHorizontal: spacing.md, ...shadow.card },
});
