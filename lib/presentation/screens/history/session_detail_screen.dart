import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../data/models/biomarker_result.dart';
import '../../../data/models/session_model.dart';
import '../../providers/sync_provider.dart';
import '../../widgets/app_ui.dart';

final _sessionDetailProvider = FutureProvider.autoDispose
    .family<SessionModel?, String>((ref, id) {
      return ref.watch(sessionRepositoryProvider).getSessionById(id);
    });

class SessionDetailScreen extends ConsumerWidget {
  const SessionDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(_sessionDetailProvider(sessionId));
    const unavailable = Center(
      child: Text('Screening result is not available for this account.'),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Screening result')),
      body: session.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => unavailable,
        data: (record) =>
            record == null ? unavailable : _details(context, record),
      ),
    );
  }

  Widget _details(BuildContext context, SessionModel session) {
    final color = switch (session.riskLevel) {
      RiskLevel.green => EarlyEchoTheme.riskGreen,
      RiskLevel.yellow => EarlyEchoTheme.riskYellow,
      RiskLevel.red => EarlyEchoTheme.riskRed,
    };
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppSurface(
            color: color.withValues(alpha: .12),
            borderColor: color,
            child: Column(
              children: [
                Icon(Icons.circle, color: color, size: 42),
                const SizedBox(height: 10),
                Text(
                  session.riskLevel.name.toUpperCase(),
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(color: color),
                ),
                const SizedBox(height: 6),
                Text(
                  '${session.childAgeMonths} months · ${session.sessionDate.toLocal()}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppSurface(
            child: Column(
              children: [
                _Metric('VTTL', '${session.vttlMs.toStringAsFixed(0)} ms'),
                const Divider(),
                _Metric('CVR', session.cvrRatio.toStringAsFixed(3)),
                const Divider(),
                _Metric('PFV', '${session.pfvStd.toStringAsFixed(1)} ST'),
                const Divider(),
                _Metric(
                  'Cloud sync',
                  session.syncedToCloud ? 'Synced' : 'Queued for sync',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label),
      Text(value, style: Theme.of(context).textTheme.titleSmall),
    ],
  );
}
