// Phase 1 design tokens. Colours are NEUTRAL placeholders: final brand identity is not chosen (DECISIONS D-010).
// Light theme only for now; dark theme planned (tokens are centralised so it can be added in one place).
export const colors = {
  background: '#FFFFFF',
  surface: '#F6F7F9',
  surfaceRaised: '#FFFFFF',
  text: '#111418',
  textMuted: '#4F5966', // contrast on white ~7:1
  primary: '#1F3A5F',
  primaryPressed: '#16304F',
  primaryText: '#FFFFFF',
  border: '#E3E6EA',
  success: '#1E7B4F',
  successBg: '#E6F4EC',
  danger: '#B3261E',
  dangerBg: '#FCEBEA',
  info: '#1F3A5F',
  infoBg: '#E8EEF6',
  overlay: 'rgba(17,20,24,0.45)',
} as const;

export const spacing = { xs: 4, sm: 8, md: 16, lg: 24, xl: 32 } as const;
export const radius = { sm: 8, md: 12, lg: 20, pill: 999 } as const;
export const MIN_TOUCH = 48; // accessibility: minimum touch target (dp)

export const fonts = {
  regular: 'IBMPlexSansArabic_400Regular',
  medium: 'IBMPlexSansArabic_500Medium',
  semibold: 'IBMPlexSansArabic_600SemiBold',
  bold: 'IBMPlexSansArabic_700Bold',
} as const;

export type TextVariant = 'display' | 'title' | 'heading' | 'body' | 'bodyStrong' | 'caption' | 'button';
// Arabic needs generous line height so diacritics are not clipped.
export const typography: Record<TextVariant, { fontFamily: string; fontSize: number; lineHeight: number }> = {
  display: { fontFamily: fonts.bold, fontSize: 28, lineHeight: 40 },
  title: { fontFamily: fonts.bold, fontSize: 22, lineHeight: 32 },
  heading: { fontFamily: fonts.semibold, fontSize: 18, lineHeight: 28 },
  body: { fontFamily: fonts.regular, fontSize: 16, lineHeight: 26 },
  bodyStrong: { fontFamily: fonts.medium, fontSize: 16, lineHeight: 26 },
  caption: { fontFamily: fonts.regular, fontSize: 13, lineHeight: 20 },
  button: { fontFamily: fonts.semibold, fontSize: 16, lineHeight: 24 },
};

export const shadow = {
  card: { shadowColor: '#000', shadowOpacity: 0.06, shadowRadius: 12, shadowOffset: { width: 0, height: 4 }, elevation: 2 },
  sheet: { shadowColor: '#000', shadowOpacity: 0.12, shadowRadius: 20, shadowOffset: { width: 0, height: -4 }, elevation: 12 },
} as const;
