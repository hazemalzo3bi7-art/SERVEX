import { useRouter } from 'expo-router';
import { useState, type PropsWithChildren } from 'react';
import { ScrollView, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText, BottomSheet, Button, Card, Skeleton, StateView, TextField, useToast } from '@/components/ui';
import { colors, spacing } from '@/constants/theme';
import { t } from '@/i18n';

// DEV-ONLY preview of the design system. Not part of the product; remove or gate before release.
function Section({ title, children }: PropsWithChildren<{ title: string }>) {
  return (
    <View style={styles.section}>
      <AppText variant="heading">{title}</AppText>
      {children}
    </View>
  );
}

export default function ComponentsPreview() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const toast = useToast();
  const [sheet, setSheet] = useState(false);
  const [text, setText] = useState('');

  return (
    <ScrollView style={styles.root} contentContainerStyle={[styles.content, { paddingTop: insets.top + spacing.md, paddingBottom: insets.bottom + spacing.xl }]}>
      <AppText variant="title">{t('dev.title')}</AppText>

      <Section title={t('dev.typography')}>
        <Card style={styles.gap}>
          <AppText variant="display">{t('dev.sample.display')}</AppText>
          <AppText>{t('dev.sample.body')}</AppText>
          <AppText variant="caption" muted>{t('dev.sample.caption')}</AppText>
        </Card>
      </Section>

      <Section title={t('dev.buttons')}>
        <Button label={t('dev.btn.primary')} onPress={() => toast.show(t('dev.toast.success'), 'success')} />
        <Button label={t('dev.btn.secondary')} variant="secondary" />
        <Button label={t('dev.btn.ghost')} variant="ghost" />
        <Button label={t('dev.btn.loading')} loading />
        <Button label={t('dev.btn.disabled')} disabled />
      </Section>

      <Section title={t('dev.fields')}>
        <TextField label={t('dev.field.label')} placeholder={t('dev.field.placeholder')} helper={t('dev.field.helper')} value={text} onChangeText={setText} multiline />
        <TextField label={t('dev.field.errorLabel')} error={t('dev.field.error')} keyboardType="phone-pad" />
      </Section>

      <Section title={t('dev.states')}>
        <Card style={styles.gap}>
          <Skeleton width="60%" height={20} />
          <Skeleton height={14} />
          <Skeleton width="80%" height={14} />
        </Card>
        <StateView title={t('dev.empty.title')} message={t('dev.empty.message')} actionLabel={t('dev.empty.action')} onAction={() => toast.show(t('dev.toast.info'), 'info')} />
        <StateView tone="error" title={t('dev.error.title')} message={t('dev.error.message')} actionLabel={t('dev.error.action')} onAction={() => toast.show(t('dev.toast.error'), 'error')} />
      </Section>

      <Section title={t('dev.feedback')}>
        <Button label={t('dev.sheet.open')} variant="secondary" onPress={() => setSheet(true)} />
      </Section>

      <Button label={t('common.back')} variant="ghost" onPress={() => (router.canGoBack() ? router.back() : router.replace('/'))} />

      <BottomSheet visible={sheet} onClose={() => setSheet(false)} title={t('dev.sheet.title')} closeLabel={t('dev.sheet.close')}>
        <AppText muted>{t('dev.sheet.body')}</AppText>
        <Button label={t('common.back')} onPress={() => setSheet(false)} />
      </BottomSheet>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.background },
  content: { paddingHorizontal: spacing.lg, gap: spacing.lg },
  section: { gap: spacing.sm },
  gap: { gap: spacing.sm },
});
