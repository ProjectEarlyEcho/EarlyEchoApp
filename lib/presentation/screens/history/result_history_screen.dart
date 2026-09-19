import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme.dart';
import '../../../data/models/biomarker_result.dart';
import '../../providers/sync_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_ui.dart';

class ResultHistoryScreen extends ConsumerWidget {
  const ResultHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(appLocaleProvider);
    final scheme = Theme.of(context).colorScheme;
    final sessions = ref.watch(savedSessionsProvider);
    final auth = ref.watch(appAuthProvider);
    final sync = ref.watch(syncProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr('title_history', l10n)),
        actions: [
          if (auth.signedIn)
            IconButton(
              icon: sync.isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded),
              tooltip: 'Sync now',
              onPressed: sync.isSyncing
                  ? null
                  : () async {
                      await ref.read(syncProvider.notifier).syncNow();
                      ref.invalidate(savedSessionsProvider);
                    },
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: sessions.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: Text(AppStrings.tr('hist_body', l10n)),
            ),
            data: (items) => items.isEmpty
                ? Center(
                    child: Text(
                      AppStrings.tr('hist_body', l10n),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final session = items[index];
                      final color = switch (session.riskLevel) {
                        RiskLevel.green => EarlyEchoTheme.riskGreen,
                        RiskLevel.yellow => EarlyEchoTheme.riskYellow,
                        RiskLevel.red => EarlyEchoTheme.riskRed,
                      };
                      return AppSurface(
                        onTap: () => context.push('/history/${session.id}', extra: session),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.circle, color: color),
                          title: Text(
                            session.childName ??
                                '${session.childAgeMonths} month screening',
                          ),
                          subtitle: Text(
                            '${session.sessionDate.toLocal()} · ${session.riskLevel.name.toUpperCase()}',
                          ),
                          trailing: Icon(
                            session.syncedToCloud
                                ? Icons.cloud_done_outlined
                                : Icons.cloud_upload_outlined,
                            color: session.syncedToCloud
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}
