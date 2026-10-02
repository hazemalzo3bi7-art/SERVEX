/**
 * Servex — analytics abstraction.
 *
 * Architecture-independent: no vendor SDK, no platform imports.
 * Drop this at `src/services/analytics/index.ts`.
 *
 * Default is a NO-OP provider, so the app is safe to ship before a vendor is
 * chosen. Swap in a real provider via `setAnalyticsProvider()` at app start.
 *
 * Usage:
 *   import { track, setAnalyticsContext } from '@/services/analytics';
 *   track('landing_page_view', { page: '/', locale: 'ar' });
 *   setAnalyticsContext({ userId, role: 'customer', city: 'amman' });
 */

import type {
  AnalyticsContext,
  AnalyticsEventName,
  AnalyticsProperties,
  AnalyticsProvider,
} from './types';

export * from './types';

/** Does nothing. Safe default. */
export class NoopAnalyticsProvider implements AnalyticsProvider {
  init(_context: AnalyticsContext): void {}
  setContext(_context: Partial<AnalyticsContext>): void {}
  track(_name: AnalyticsEventName, _properties?: AnalyticsProperties): void {}
  screen(_name: string, _properties?: AnalyticsProperties): void {}
  async flush(): Promise<void> {}
}

/**
 * Logs events. Useful in development only.
 * Never use in production without a real destination — it does not persist.
 */
export class ConsoleAnalyticsProvider implements AnalyticsProvider {
  private context: AnalyticsContext = {};

  init(context: AnalyticsContext): void {
    this.context = { ...context };
  }

  setContext(context: Partial<AnalyticsContext>): void {
    this.context = { ...this.context, ...context };
  }

  track(name: AnalyticsEventName, properties?: AnalyticsProperties): void {
    // eslint-disable-next-line no-console
    console.log('[analytics]', name, { ...this.context, ...(properties ?? {}) });
  }

  screen(name: string, properties?: AnalyticsProperties): void {
    // eslint-disable-next-line no-console
    console.log('[analytics:screen]', name, { ...this.context, ...(properties ?? {}) });
  }

  async flush(): Promise<void> {}
}

let provider: AnalyticsProvider = new NoopAnalyticsProvider();
let context: AnalyticsContext = {};

/** Register the analytics backend. Call once at app start. */
export function setAnalyticsProvider(next: AnalyticsProvider, initialContext: AnalyticsContext = {}): void {
  provider = next;
  context = { ...initialContext };
  void provider.init(context);
}

/** Merge ambient context (after login, role selection, city change, etc.). */
export function setAnalyticsContext(next: Partial<AnalyticsContext>): void {
  context = { ...context, ...next };
  provider.setContext(next);
}

/** Record an event. Never throws — analytics must not break the app. */
export function track(name: AnalyticsEventName, properties?: AnalyticsProperties): void {
  try {
    provider.track(name, properties);
  } catch {
    // Swallow: analytics failures must never crash the app.
  }
}

/** Record a screen view, if the provider supports it. */
export function trackScreen(name: string, properties?: AnalyticsProperties): void {
  try {
    provider.screen?.(name, properties);
  } catch {
    // Swallow.
  }
}

/** Flush buffered events (e.g. on background). */
export async function flushAnalytics(): Promise<void> {
  try {
    await provider.flush?.();
  } catch {
    // Swallow.
  }
}

/** Read-only snapshot of the current ambient context. */
export function getAnalyticsContext(): AnalyticsContext {
  return { ...context };
}
