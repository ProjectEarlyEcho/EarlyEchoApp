import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/app_ui.dart';

/// First-run language gate — English or Hindi.
///
/// The router redirects here while [appLocaleProvider] is null; picking a
/// language persists it and sends the worker home. Both cards are always
/// labelled in their own language so the choice is obvious even if the
/// current UI language is unfamiliar.
class LanguageSelectionScreen extends ConsumerWidget {
  const LanguageSelectionScreen({super.key});

  Future<void> _pick(WidgetRef ref, BuildContext context, Locale locale) async {
    await ref.read(appLocaleProvider.notifier).select(locale);
    if (context.mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(appLocaleProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Center(
                child: AppIconBadge(
                  icon: Icons.translate_rounded,
                  color: scheme.primary,
                  size: 72,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                AppStrings.tr('language_title', locale),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text(
                AppStrings.tr('language_subtitle', locale),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 28),
              _LanguageCard(
                title: 'English',
                subtitle: 'Use the app in English',
                icon: Icons.language_rounded,
                selected: locale?.languageCode == 'en',
                onTap: () => _pick(ref, context, const Locale('en')),
              ),
              const SizedBox(height: 14),
              _LanguageCard(
                title: 'हिन्दी',
                subtitle: 'ऐप हिन्दी में इस्तेमाल करें',
                icon: Icons.record_voice_over_rounded,
                selected: locale == null || locale.languageCode == 'hi',
                onTap: () => _pick(ref, context, const Locale('hi')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = selected ? scheme.primary : scheme.outlineVariant;
    return AppSurface(
      onTap: onTap,
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.35)
          : scheme.surface,
      borderColor: accent,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          AppIconBadge(icon: icon, color: scheme.primary, size: 48),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (selected) Icon(Icons.check_circle_rounded, color: scheme.primary),
        ],
      ),
    );
  }
}
