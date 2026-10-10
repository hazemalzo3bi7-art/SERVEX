import type { User } from '@/types/auth';

// CENTRAL DEMO DATA (master prompt §25). Fictional people. Numbers are DEMO ONLY: no SMS is ever sent.
export const DEMO_MODE = true;
export const DEMO_OTP = '123456';

export const DEMO_USERS: User[] = [
  { id: 'usr_admin_1', phone: '+962790000001', name: 'إدارة النظام', role: 'admin', status: 'active', createdAt: '2026-01-01T08:00:00.000Z' },
  { id: 'usr_cust_1', phone: '+962790000002', name: 'سارة المصري', role: 'customer', status: 'active', createdAt: '2026-01-05T09:30:00.000Z' },
  { id: 'usr_prov_1', phone: '+962790000003', name: 'محمد العبادي', role: 'provider', status: 'active', createdAt: '2026-01-06T10:15:00.000Z' },
];
