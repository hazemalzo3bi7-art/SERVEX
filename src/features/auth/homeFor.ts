import type { Href } from 'expo-router';
import type { Role } from '@/types/auth';

/** Single place that maps a role to its home route. */
export function homeFor(role: Role): Href {
  switch (role) {
    case 'customer': return '/customer';
    case 'provider': return '/provider';
    case 'admin': return '/admin';
  }
}
