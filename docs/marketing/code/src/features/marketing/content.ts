/**
 * Servex — marketing content configuration (Arabic-first, RTL).
 *
 * Architecture-independent: pure data + types, no UI or platform imports.
 * Drop this at `src/features/marketing/content.ts`.
 *
 * Why a config file: marketing copy must not be scattered across components.
 * Components read from here, so copy can change without touching UI code.
 *
 * NOTE: content here is Arabic-first per decision D-026. Add English under
 * `en` where relevant; the app's i18n layer can consume these structures.
 */

export type Locale = 'ar' | 'en';
export type CityCode = 'amman' | 'irbid';

/** A localized string. Arabic is the primary/launch language. */
export interface LocalizedText {
  ar: string;
  en?: string;
}

/** A promotional banner shown on the customer home. */
export interface MarketingBanner {
  id: string;
  title: LocalizedText;
  subtitle?: LocalizedText;
  ctaLabel: LocalizedText;
  /** Deep link or route the CTA opens. */
  ctaHref: string;
  /** Optional campaign id for attribution. */
  campaignId?: string;
  /** ISO date strings; omit for always-on banners. */
  startsAt?: string;
  endsAt?: string;
  /** Cities this banner targets; omit for all launch cities. */
  cities?: CityCode[];
  /** Visual hint only — real colours come from the design system (D-027). */
  tone?: 'primary' | 'promo' | 'neutral';
}

/** A marketing FAQ entry. */
export interface FaqItem {
  id: string;
  question: LocalizedText;
  answer: LocalizedText;
  /** Audience this FAQ is written for. */
  audience: 'customer' | 'provider' | 'both';
}

/** A landing-page content block. */
export interface LandingSection {
  id: string;
  heading: LocalizedText;
  body: LocalizedText;
  /** Optional ordered bullet points. */
  bullets?: LocalizedText[];
  ctaLabel?: LocalizedText;
  ctaHref?: string;
}

/** A full marketing page definition. */
export interface MarketingPageContent {
  /** Route path, e.g. '/for-providers'. */
  path: string;
  title: LocalizedText;
  /** SEO meta description. Keep <= 160 chars. */
  metaDescription: LocalizedText;
  heroHeading: LocalizedText;
  heroSubheading: LocalizedText;
  heroCtaLabel: LocalizedText;
  heroCtaHref: string;
  sections: LandingSection[];
}

/** Reusable message template (for social/WhatsApp copy managed in-app). */
export interface CampaignMessage {
  id: string;
  channel: 'instagram' | 'tiktok' | 'facebook' | 'whatsapp' | 'in_app';
  audience: 'customer' | 'provider';
  body: LocalizedText;
  /** Optional call to action label. */
  ctaLabel?: LocalizedText;
  ctaHref?: string;
}

/** Marketing metadata for a service category (keyed by DB category slug). */
export interface CategoryMarketingMeta {
  /** Must match `categories.slug` in the database. */
  slug: string;
  /** Short marketing label (may differ from the catalog name). */
  tagline: LocalizedText;
  /** Example search terms users actually type. */
  searchTerms: LocalizedText[];
  /** Whether this category is promoted at launch. */
  launchFeatured: boolean;
}

/* ------------------------------------------------------------------ */
/* Promotional banners                                                 */
/* ------------------------------------------------------------------ */

export const MARKETING_BANNERS: MarketingBanner[] = [
  {
    id: 'first-order-20',
    title: { ar: 'خصم 20% على أول طلب', en: '20% off your first order' },
    subtitle: { ar: 'خدمات موثوقة لبيت أكثر راحة', en: 'Trusted services for a more comfortable home' },
    ctaLabel: { ar: 'اطلب الآن', en: 'Order now' },
    ctaHref: '/customer',
    campaignId: 'launch_first_order_20',
    tone: 'promo',
    cities: ['amman', 'irbid'],
  },
];

/* ------------------------------------------------------------------ */
/* FAQ content                                                         */
/* ------------------------------------------------------------------ */

export const FAQ_ITEMS: FaqItem[] = [
  {
    id: 'how-it-works',
    audience: 'both',
    question: { ar: 'كيف يعمل سيرفكس؟', en: 'How does Servex work?' },
    answer: {
      ar: 'تختار الخدمة، تشوف الفنّيين الموثوقين القريبين منك، وتختار الفنّي بنفسك. بعدها يجي للفحص، يرسل لك عرض سعر واضح، وتوافق عليه قبل البدء.',
      en: 'Pick a service, browse nearby verified providers, and choose one yourself. They inspect, send a clear quote, and you approve before work starts.',
    },
  },
  {
    id: 'payment',
    audience: 'customer',
    question: { ar: 'كيف أدفع؟', en: 'How do I pay?' },
    answer: {
      ar: 'الدفع متاح داخل التطبيق. [حدّث هذا النص بعد اعتماد طرق الدفع رسمياً.]',
      en: 'Payment is available in the app. [Update once payment rails are confirmed.]',
    },
  },
  {
    id: 'trust',
    audience: 'customer',
    question: { ar: 'هل الفنّيون موثوقون؟', en: 'Are providers trustworthy?' },
    answer: {
      ar: 'كل فنّي يمر بعملية تحقق قبل التفعيل، وتقدر تشوف تقييماته وعدد المهام المنجزة قبل ما تختاره.',
      en: 'Every provider is verified before activation, and you can see their rating and completed jobs before choosing.',
    },
  },
  {
    id: 'provider-join',
    audience: 'provider',
    question: { ar: 'كيف أنضم كفنّي؟', en: 'How do I join as a provider?' },
    answer: {
      ar: 'سجّل كفنّي، أكمل ملفك، أضف خدماتك ومناطق عملك. بعد المراجعة بنفعّل حسابك وتبدأ تستقبل الطلبات.',
      en: 'Sign up as a provider, complete your profile, and add your services and service areas. After review we activate your account.',
    },
  },
];

/* ------------------------------------------------------------------ */
/* Category marketing metadata (slugs MUST match the database)         */
/* ------------------------------------------------------------------ */

export const CATEGORY_MARKETING: CategoryMarketingMeta[] = [
  {
    slug: 'plumbing',
    tagline: { ar: 'تسريبات؟ انسداد؟ فنّي سباكة قريب منك', en: 'Leaks and clogs — a plumber near you' },
    searchTerms: [{ ar: 'سباك في عمان' }, { ar: 'تسريب مياه' }, { ar: 'انسداد مجاري' }],
    launchFeatured: true,
  },
  {
    slug: 'electrical',
    tagline: { ar: 'كهربائي موثوق لبيتك ومكتبك', en: 'A trusted electrician for home and office' },
    searchTerms: [{ ar: 'كهربائي قريب مني' }, { ar: 'إصلاح كهرباء' }],
    launchFeatured: true,
  },
  {
    slug: 'ac-cooling',
    tagline: { ar: 'صيانة وتكييف — جهّز مكيّفك قبل الصيف', en: 'AC service and cooling — get ready for summer' },
    searchTerms: [{ ar: 'صيانة تكييف عمان' }, { ar: 'تعبئة فريون' }, { ar: 'تركيب مكيف' }],
    launchFeatured: true,
  },
  {
    slug: 'cleaning',
    tagline: { ar: 'تنظيف منازل احترافي', en: 'Professional home cleaning' },
    searchTerms: [{ ar: 'تنظيف منازل اربد' }, { ar: 'شركة تنظيف' }],
    launchFeatured: true,
  },
  {
    slug: 'appliance-repair',
    tagline: { ar: 'إصلاح غسالات وثلاجات وأجهزة منزلية', en: 'Washing machine, fridge and appliance repair' },
    searchTerms: [{ ar: 'إصلاح غسالات عمان' }, { ar: 'تصليح ثلاجة' }],
    launchFeatured: true,
  },
  {
    slug: 'painting',
    tagline: { ar: 'دهان وتشطيبات باحتراف', en: 'Professional painting and finishing' },
    searchTerms: [{ ar: 'دهان منازل' }, { ar: 'معلم دهان' }],
    launchFeatured: false,
  },
];

/* ------------------------------------------------------------------ */
/* Landing pages                                                       */
/* ------------------------------------------------------------------ */

export const MARKETING_PAGES: MarketingPageContent[] = [
  {
    path: '/',
    title: { ar: 'سيرفكس — خدمات منزلية موثوقة في عمّان وإربد', en: 'Servex — trusted home services in Amman and Irbid' },
    metaDescription: {
      ar: 'احجز فنّياً موثوقاً لخدمات السباكة والكهرباء والتكييف والتنظيف في عمّان وإربد. سعر واضح قبل البدء، وتختار الفنّي بنفسك.',
      en: 'Book a verified home-services professional in Amman and Irbid. Clear pricing before work starts, and you choose your provider.',
    },
    heroHeading: { ar: 'خدمة منزلية موثوقة، بسعر واضح', en: 'Trusted home service, clearly priced' },
    heroSubheading: {
      ar: 'فنّيون موثّقون في عمّان وإربد. أنت تختار الفنّي، وتوافق على السعر قبل البدء.',
      en: 'Verified providers in Amman and Irbid. You choose the provider and approve the price before work starts.',
    },
    heroCtaLabel: { ar: 'اطلب خدمة', en: 'Request a service' },
    heroCtaHref: '/customer',
    sections: [
      {
        id: 'how',
        heading: { ar: 'كيف يعمل سيرفكس؟', en: 'How Servex works' },
        body: { ar: 'ثلاث خطوات بسيطة.', en: 'Three simple steps.' },
        bullets: [
          { ar: 'اختر الخدمة والمنطقة', en: 'Choose the service and area' },
          { ar: 'اختر الفنّي الموثّق بنفسك', en: 'Choose your verified provider' },
          { ar: 'وافق على عرض السعر وابدأ', en: 'Approve the quote and start' },
        ],
      },
      {
        id: 'trust',
        heading: { ar: 'لماذا سيرفكس؟', en: 'Why Servex' },
        body: {
          ar: 'لأنّنا نبني الثقة بشكل واضح: تحقق من الفنّيين، تقييمات حقيقية، وسعر معلن قبل البدء.',
          en: 'Because trust is visible: provider verification, real reviews, and pricing agreed before work starts.',
        },
        bullets: [
          { ar: 'فنّيون موثّقون', en: 'Verified providers' },
          { ar: 'سعر واضح قبل البدء', en: 'Clear price before work' },
          { ar: 'أنت تختار الفنّي', en: 'You choose your provider' },
        ],
      },
    ],
  },
  {
    path: '/for-providers',
    title: { ar: 'انضم كفنّي إلى سيرفكس', en: 'Join Servex as a provider' },
    metaDescription: {
      ar: 'انضم لفنّيي سيرفكس في عمّان وإربد. استقبل طلبات في منطقتك، اختر الطلب المناسب، وحدّد وقتك بنفسك.',
      en: 'Join Servex providers in Amman and Irbid. Receive requests in your area, choose the jobs you want, and set your own hours.',
    },
    heroHeading: { ar: 'استقبل طلبات في منطقتك', en: 'Receive requests in your area' },
    heroSubheading: {
      ar: 'أنت تختار الطلب اللي يناسبك، وتحدّد وقتك بنفسك.',
      en: 'You choose the jobs that suit you and set your own hours.',
    },
    heroCtaLabel: { ar: 'سجّل كفنّي', en: 'Sign up as a provider' },
    heroCtaHref: '/register?role=provider',
    sections: [
      {
        id: 'benefits',
        heading: { ar: 'مميزات الانضمام', en: 'Why join' },
        body: { ar: 'شروط واضحة، ودعم مستمر.', en: 'Clear terms and ongoing support.' },
        bullets: [
          { ar: 'أنت تختار الطلب', en: 'You choose the job' },
          { ar: 'تحدّد وقتك', en: 'You set your hours' },
          { ar: 'سعر واضح ومتفق عليه قبل البدء', en: 'Clear agreed price before starting' },
        ],
      },
    ],
  },
  {
    path: '/how-it-works',
    title: { ar: 'كيف يعمل سيرفكس', en: 'How Servex works' },
    metaDescription: {
      ar: 'تعرّف على خطوات طلب خدمة منزلية موثوقة عبر سيرفكس في عمّان وإربد.',
      en: 'Learn the steps to request a trusted home service through Servex in Amman and Irbid.',
    },
    heroHeading: { ar: 'من الطلب إلى الإنجاز', en: 'From request to completion' },
    heroSubheading: { ar: 'خطوات واضحة، بلا مفاجآت.', en: 'Clear steps, no surprises.' },
    heroCtaLabel: { ar: 'ابدأ الآن', en: 'Get started' },
    heroCtaHref: '/customer',
    sections: [],
  },
  {
    path: '/about',
    title: { ar: 'عن سيرفكس', en: 'About Servex' },
    metaDescription: {
      ar: 'سيرفكس منصّة أردنية لخدمات منزلية موثوقة في عمّان وإربد.',
      en: 'Servex is a Jordanian platform for trusted home services in Amman and Irbid.',
    },
    heroHeading: { ar: 'نبني الثقة في الخدمات المنزلية', en: 'Building trust in home services' },
    heroSubheading: { ar: 'منصّة أردنية، عربية أولاً.', en: 'A Jordanian platform, Arabic-first.' },
    heroCtaLabel: { ar: 'تواصل معنا', en: 'Contact us' },
    heroCtaHref: '/contact',
    sections: [],
  },
  {
    path: '/contact',
    title: { ar: 'تواصل مع سيرفكس', en: 'Contact Servex' },
    metaDescription: {
      ar: 'تواصل مع فريق سيرفكس للاستفسارات والدعم في عمّان وإربد.',
      en: 'Contact the Servex team for questions and support in Amman and Irbid.',
    },
    heroHeading: { ar: 'نحن هنا للمساعدة', en: 'We are here to help' },
    heroSubheading: { ar: 'راسلنا وسنرد عليك في أقرب وقت.', en: 'Message us and we will respond soon.' },
    heroCtaLabel: { ar: 'راسلنا على واتساب', en: 'Message us on WhatsApp' },
    heroCtaHref: 'https://wa.me/',
    sections: [],
  },
];

/* ------------------------------------------------------------------ */
/* Reusable campaign messages                                          */
/* ------------------------------------------------------------------ */

export const CAMPAIGN_MESSAGES: CampaignMessage[] = [
  {
    id: 'launch-announcement',
    channel: 'instagram',
    audience: 'customer',
    body: {
      ar: 'أخيراً… خدمة منزلية موثوقة بضغطة زر. سيرفكس متاح الآن في عمّان وإربد. اختر الخدمة، اختر الفنّي، ووافق على السعر.',
      en: 'Finally — trusted home service at the tap of a button. Servex is now live in Amman and Irbid.',
    },
    ctaLabel: { ar: 'حمّل سيرفكس', en: 'Get Servex' },
  },
  {
    id: 'provider-recruit',
    channel: 'whatsapp',
    audience: 'provider',
    body: {
      ar: 'سيرفكس منصّة تربط فنّيين موثوقين بعملاء في منطقتك. أنت تختار الطلب وتحدّد وقتك. التسجيل دقيقتين.',
      en: 'Servex connects verified providers with customers in your area. You choose the job and set your hours.',
    },
    ctaLabel: { ar: 'سجّل الآن', en: 'Sign up' },
  },
];

/* ------------------------------------------------------------------ */
/* Referral copy (reward text intentionally omitted until approved)    */
/* ------------------------------------------------------------------ */

export const REFERRAL_COPY = {
  customerShare: {
    ar: 'شارك سيرفكس مع صاحبك واستخدم كودك: {code}',
    en: 'Share Servex with a friend using your code: {code}',
  },
  providerShare: {
    ar: 'انضم لسيرفكس كفنّي باستخدام كود الإحالة: {code}',
    en: 'Join Servex as a provider with referral code: {code}',
  },
  /** Do NOT render a reward claim until the owner defines the reward model. */
  rewardPlaceholder: null as LocalizedText | null,
} as const;

/** Convenience: pick a localized string with an Arabic-first fallback. */
export function localized(text: LocalizedText, locale: Locale = 'ar'): string {
  return (locale === 'en' && text.en) || text.ar;
}
