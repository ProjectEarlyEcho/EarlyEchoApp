import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../data/models/biomarker_result.dart';
import '../../../data/models/session_model.dart';
import '../../widgets/app_ui.dart';

class SessionDetailScreen extends StatelessWidget {
  const SessionDetailScreen({super.key, required this.session});

  final SessionModel session;

  @override
  Widget build(BuildContext context) {
    final color = switch (session.riskLevel) {
      RiskLevel.green => EarlyEchoTheme.riskGreen,
      RiskLevel.yellow => EarlyEchoTheme.riskYellow,
      RiskLevel.red => EarlyEchoTheme.riskRed,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Screening result')),
      body: SafeArea(
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
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('${session.childAgeMonths} months · ${session.sessionDate.toLocal()}'),
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
    children: [Text(label), Text(value, style: Theme.of(context).textTheme.titleSmall)],
  );
}