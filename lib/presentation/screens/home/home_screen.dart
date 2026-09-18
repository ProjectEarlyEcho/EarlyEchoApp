import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/app_ui.dart';

/// The worker's landing screen — entry point into the screening flow.
///
/// Exposes the three top-level destinations: starting a new screening,
/// reviewing past results, and opening settings. All user-facing text is
/// localized through [AppStrings] for the selected app language.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(appLocaleProvider);
    final auth = ref.watch(appAuthProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('EarlyEcho'),
        actions: [
          if (auth.configured)
            IconButton(
              icon: Icon(
                auth.signedIn ? Icons.logout_rounded : Icons.login_rounded,
              ),
              tooltip: auth.signedIn ? 'Sign out' : 'Sign in',
              onPressed: () async {
                if (auth.signedIn) {
                  await ref.read(appAuthProvider.notifier).signOut();
                } else if (context.mounted) {
                  context.push('/login');
                }
              },
            ),
          if (auth.signedIn)
            IconButton(
              icon: const Icon(Icons.medical_information_outlined),
              tooltip: 'Care portal',
              onPressed: () => context.push('/care'),
            ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: AppStrings.tr('tooltip_history', l10n),
            onPressed: () => context.push('/history'),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: AppStrings.tr('tooltip_settings', l10n),
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        AppSectionHeader(
                          title: AppStrings.tr('home_greeting', l10n),
                          subtitle: AppStrings.tr('home_greeting_sub', l10n),
                        ),
                        const SizedBox(height: 16),
                        AppSurface(
                          color: scheme.primaryContainer.withValues(alpha: 0.4),
                          borderColor: scheme.primaryContainer,
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            children: [
                              AppIconBadge(
                                icon: Icons.hearing_rounded,
                                color: scheme.primary,
                                size: 72,
                              ),
                              const SizedBox(height: 22),
                              Text(
                                AppStrings.tr('home_hero_title', l10n),
                                textAlign: TextAlign.center,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                AppStrings.tr('home_hero_body', l10n),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        AppSurface(
                          color: scheme.secondaryContainer.withValues(
                            alpha: 0.4,
                          ),
                          borderColor: scheme.secondaryContainer,
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              AppIconBadge(
                                icon: Icons.shield_outlined,
                                color: scheme.secondary,
                                size: 40,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppStrings.tr('home_privacy_title', l10n),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      AppStrings.tr('home_privacy_body', l10n),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => context.push(
                  auth.canSyncScreenings ? '/care/children' : '/child-profile',
                ),
                icon: const Icon(Icons.add_rounded),
                label: Text(AppStrings.tr('home_new_screening', l10n)),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => context.push('/history'),
                icon: const Icon(Icons.history_rounded),
                label: Text(AppStrings.tr('home_view_history', l10n)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
