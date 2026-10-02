/**
 * Servex — analytics event types.
 *
 * Architecture-independent: types only, no vendor SDK, no platform imports.
 * Drop this at `src/services/analytics/types.ts`.
 *
 * The taxonomy is defined in docs/marketing/EVENT_TAXONOMY.md.
 * No commercial analytics provider is hard-coded here by design.
 */

export type UserRole = 'customer' | 'provider' | 'admin';
export type CityCode = 'amman' | 'irbid';
export type Locale = 'ar' | 'en';
export type Platform = 'ios' | 'android' | 'web';

/** Ambient context attached to every event. */
export interface AnalyticsContext {
  userId?: string;
  role?: UserRole;
  city?: CityCode;
  locale?: Locale;
  platform?: Platform;
}

/** Allowed property value types. No PII. */
export type AnalyticsPropertyValue = string | number | boolean | null | undefined;

export type AnalyticsProperties = Record<string, AnalyticsPropertyValue>;

/** Core event names (see EVENT_TAXONOMY.md). */
export type AnalyticsEventName =
  | 'landing_page_view'
  | 'signup_started'
  | 'signup_completed'
  | 'role_selected'
  | 'customer_home_viewed'
  | 'service_search'
  | 'service_selected'
  | 'provider_viewed'
  | 'request_started'
  | 'request_submitted'
  | 'quote_received'
  | 'quote_accepted'
  | 'booking_completed'
  | 'provider_signup'
  | 'provider_profile_completed'
  | 'provider_service_added'
  | 'provider_request_accepted'
  // optional / later
  | 'quote_rejected'
  | 'request_cancelled'
  | 'request_expired'
  | 'dispute_opened'
  | 'review_submitted'
  | 'referral_shared'
  | 'referral_converted'
  | 'offer_redeemed';

/** A tracked event. */
export interface AnalyticsEvent {
  name: AnalyticsEventName;
  properties?: AnalyticsProperties;
  timestamp: string;
}

/**
 * A provider-agnostic analytics backend.
 * Implement this to connect a real vendor later without touching call sites.
 */
export interface AnalyticsProvider {
  /** Called once when the provider is registered. */
  init(context: AnalyticsContext): void | Promise<void>;
  /** Merge updated ambient context (e.g. after login or role selection). */
  setContext(context: Partial<AnalyticsContext>): void;
  /** Record a single event. */
  track(name: AnalyticsEventName, properties?: AnalyticsProperties): void;
  /** Optional screen/view tracking. */
  screen?(name: string, properties?: AnalyticsProperties): void;
  /** Optional: flush buffered events. */
  flush?(): Promise<void>;
}
