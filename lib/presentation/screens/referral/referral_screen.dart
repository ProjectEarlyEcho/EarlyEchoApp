import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/app_ui.dart';

/// Step 7 of the screening flow — the DEIC referral letter.
///
/// Placeholder for Phase 8; the generated letter, PDF export and the
/// WhatsApp share intent land there.
class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(appLocaleProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.tr('title_referral', l10n))),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppStepIndicator(
                current: 7,
                total: 7,
                label: AppStrings.stepLabel(
                  7,
                  7,
                  AppStrings.tr('step7_name', l10n),
                  l10n,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: AppSurface(
                      color: scheme.errorContainer.withValues(alpha: 0.4),
                      borderColor: scheme.errorContainer,
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        children: [
                          AppIconBadge(
                            icon: Icons.description_outlined,
                            color: scheme.error,
                            size: 72,
                          ),
                          const SizedBox(height: 22),
                          Text(
                            AppStrings.tr('ref_title', l10n),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            AppStrings.tr('ref_body', l10n),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home_rounded),
                label: Text(AppStrings.tr('ref_home', l10n)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
