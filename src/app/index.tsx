import { Redirect } from 'expo-router';
import { homeFor } from '@/features/auth/homeFor';
import { useAuthStore } from '@/state/authStore';

// Entry point: sends each person to the right place. Guards live in _layout.tsx.
export default function Index() {
  const user = useAuthStore((s) => s.user);
  return <Redirect href={user ? homeFor(user.role) : '/login'} />;
}
