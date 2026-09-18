import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/app_ui.dart';

/// Saved screening results — the worker's record of past sessions.
///
/// Placeholder for Phase 6; the list of locally stored sessions (child,
/// date, risk band, sync state) lands there. Only numeric results are kept —
/// audio is never stored.
class ResultHistoryScreen extends ConsumerWidget {
  const ResultHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(appLocaleProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.tr('title_history', l10n))),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Center(
            child: SingleChildScrollView(
              child: AppSurface(
                color: scheme.secondaryContainer.withValues(alpha: 0.4),
                borderColor: scheme.secondaryContainer,
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    AppIconBadge(
                      icon: Icons.history_toggle_off_rounded,
                      color: scheme.secondary,
                      size: 72,
                    ),
                    const SizedBox(height: 22),
                    Text(
                      AppStrings.tr('hist_title', l10n),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      AppStrings.tr('hist_body', l10n),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
