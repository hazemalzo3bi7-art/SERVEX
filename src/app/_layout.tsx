import {
  IBMPlexSansArabic_400Regular,
  IBMPlexSansArabic_500Medium,
  IBMPlexSansArabic_600SemiBold,
  IBMPlexSansArabic_700Bold,
  useFonts,
} from '@expo-google-fonts/ibm-plex-sans-arabic';
import { Stack } from 'expo-router';
import * as SplashScreen from 'expo-splash-screen';
import { StatusBar } from 'expo-status-bar';
import { useEffect } from 'react';
import { ToastProvider } from '@/components/ui';
import { useAuthStore } from '@/state/authStore';
import { applyLayoutDirection } from '@/i18n/rtl';

applyLayoutDirection();
SplashScreen.preventAutoHideAsync().catch(() => {});

export default function RootLayout() {
  const role = useAuthStore((s) => s.user?.role ?? null);
  const [loaded, error] = useFonts({
    IBMPlexSansArabic_400Regular,
    IBMPlexSansArabic_500Medium,
    IBMPlexSansArabic_600SemiBold,
    IBMPlexSansArabic_700Bold,
  });
  // On font error we still render (system font fallback) rather than hang on the splash screen.
  const ready = loaded || !!error;
  useEffect(() => {
    if (ready) SplashScreen.hideAsync().catch(() => {});
  }, [ready]);
  if (!ready) return null;

  return (
    <ToastProvider>
      <StatusBar style="dark" />
      <Stack screenOptions={{ headerShown: false, animation: 'slide_from_right' }}>
        {/* Client-side guards only (Expo docs: not a replacement for server-side access control).
            Real enforcement = Supabase RLS in Phase 22. Unlisted routes (index, dev/*) stay reachable. */}
        <Stack.Protected guard={role === null}>
          <Stack.Screen name="login" />
          <Stack.Screen name="verify" />
          <Stack.Screen name="register" />
        </Stack.Protected>
        <Stack.Protected guard={role === 'customer'}>
          <Stack.Screen name="customer" />
        </Stack.Protected>
        <Stack.Protected guard={role === 'provider'}>
          <Stack.Screen name="provider" />
        </Stack.Protected>
        <Stack.Protected guard={role === 'admin'}>
          <Stack.Screen name="admin" />
        </Stack.Protected>
      </Stack>
    </ToastProvider>
  );
}
