import { createMemoryAuthService } from './memoryAuthService';

export type { AuthService } from './types';
export { AuthError } from './types';
// Single app-wide instance. 450ms latency makes loading states visible in the demo.
export const authService = createMemoryAuthService({ latencyMs: 450 });
