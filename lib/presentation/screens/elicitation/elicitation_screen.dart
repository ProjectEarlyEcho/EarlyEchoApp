import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../../widgets/app_ui.dart';

/// Step 4 of the screening flow — the three timed elicitation protocols.
///
/// Placeholder for Phase 5; protocol timers, pictograms and Hindi audio
/// instructions land there. The durations shown come straight from
/// [EarlyEchoConstants] so the worker-facing copy can never drift from the
/// protocol contract.
class ElicitationScreen extends StatelessWidget {
  const ElicitationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('ध्वनि प्रेरण')),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppStepIndicator(
                current: 4,
                total: 7,
                label: 'चरण 4/7 • ध्वनि प्रेरण (Elicitation)',
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: AppSurface(
                      color: scheme.primaryContainer.withValues(alpha: 0.4),
                      borderColor: scheme.primaryContainer,
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        children: [
                          AppIconBadge(
                            icon: Icons.toys_rounded,
                            color: scheme.primary,
                            size: 72,
                          ),
                          const SizedBox(height: 22),
                          Text(
                            'तीन क्रमिक गतिविधियाँ',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'हर गतिविधि में बच्चे की आवाज़ रिकॉर्ड होती है — कुल '
                            'लगभग ${EarlyEchoConstants.elicitationTotalSeconds} '
                            'सेकंड।',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 20),
                          const _ProtocolRow(
                            icon: Icons.music_note_rounded,
                            title: 'रैटल',
                            subtitle: 'रैटल की आवाज़ सुनाएँ',
                            seconds: EarlyEchoConstants.rattleProtocolSeconds,
                          ),
                          const _ProtocolRow(
                            icon: Icons.visibility_rounded,
                            title: 'खिलौना छुपाना',
                            subtitle: 'खिलौना छुपाकर अचानक दिखाएँ',
                            seconds: EarlyEchoConstants.toyHideProtocolSeconds,
                          ),
                          const _ProtocolRow(
                            icon: Icons.graphic_eq_rounded,
                            title: 'अनुकरण',
                            subtitle: '"आ... आ... आ..." का अनुकरण करें',
                            seconds:
                                EarlyEchoConstants.imitationProtocolSeconds,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => context.push('/processing'),
                icon: const Icon(Icons.mic_rounded),
                label: const Text('रिकॉर्डिंग शुरू करें'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProtocolRow extends StatelessWidget {
  const _ProtocolRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.seconds,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$seconds सेकंड',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: scheme.primary),
          ),
        ],
      ),
    );
  }
}
