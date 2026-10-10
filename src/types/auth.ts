export type Role = 'customer' | 'provider' | 'admin';
/** Roles a person may choose when registering. Admin accounts are NEVER self-registered. */
export type SignUpRole = Exclude<Role, 'admin'>;
export type UserStatus = 'active' | 'suspended';

export interface User {
  id: string;
  /** E.164, e.g. +962791234567 */
  phone: string;
  name: string;
  role: Role;
  status: UserStatus;
  createdAt: string; // ISO 8601
}
