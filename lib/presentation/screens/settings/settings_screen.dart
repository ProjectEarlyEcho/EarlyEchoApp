import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/app_ui.dart';

/// Worker and device preferences.
///
/// Placeholder for the settings milestone — the worker's name, default
/// Anganwadi ID, demo mode toggle and sync preferences land there. The
/// language row is live: it clears the saved choice and returns to the
/// first-run picker.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(appLocaleProvider);
    final auth = ref.watch(appAuthProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.tr('title_settings', l10n))),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  AppSurface(
                    color: scheme.primaryContainer.withValues(alpha: 0.4),
                    borderColor: scheme.primaryContainer,
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        AppIconBadge(
                          icon: Icons.tune_rounded,
                          color: scheme.primary,
                          size: 72,
                        ),
                        const SizedBox(height: 22),
                        Text(
                          AppStrings.tr('settings_title', l10n),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          AppStrings.tr('settings_body', l10n),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (auth.configured) ...[
                    AppSurface(
                      onTap: auth.signedIn
                          ? null
                          : () => context.push('/login'),
                      child: Row(
                        children: [
                          AppIconBadge(
                            icon: auth.signedIn
                                ? Icons.account_circle_outlined
                                : Icons.login_rounded,
                            color: scheme.secondary,
                            size: 40,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.tr('settings_account', l10n),
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  auth.signedIn
                                      ? auth.displayName?.trim().isNotEmpty ==
                                                true
                                            ? auth.displayName!
                                            : auth.user!.email ??
                                                  AppStrings.tr(
                                                    'settings_signed_in',
                                                    l10n,
                                                  )
                                      : AppStrings.tr(
                                          'settings_not_signed_in',
                                          l10n,
                                        ),
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                if (auth.signedIn && auth.user?.email != null)
                                  Text(
                                    '${auth.user!.email} · ${_roleLabel(auth.role, l10n)}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                          if (auth.signedIn)
                            IconButton(
                              icon: const Icon(Icons.logout_rounded),
                              tooltip: AppStrings.tr('settings_sign_out', l10n),
                              onPressed: () =>
                                  ref.read(appAuthProvider.notifier).signOut(),
                            )
                          else
                            Text(
                              AppStrings.tr('settings_sign_in', l10n),
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: scheme.primary),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  AppSurface(
                    onTap: () async {
                      await ref.read(appLocaleProvider.notifier).reset();
                      if (context.mounted) context.go('/language');
                    },
                    child: Row(
                      children: [
                        AppIconBadge(
                          icon: Icons.translate_rounded,
                          color: scheme.primary,
                          size: 40,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.tr('settings_language', l10n),
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n?.languageCode == 'en'
                                    ? 'English'
                                    : 'हिन्दी',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          AppStrings.tr('settings_language_change', l10n),
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: scheme.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _roleLabel(AppUserRole? role, Locale? locale) => switch (role) {
    AppUserRole.parent => AppStrings.tr('settings_role_parent', locale),
    AppUserRole.careWorker => AppStrings.tr(
      'settings_role_care_worker',
      locale,
    ),
    AppUserRole.admin => AppStrings.tr('settings_role_admin', locale),
    null => '',
  };
}
