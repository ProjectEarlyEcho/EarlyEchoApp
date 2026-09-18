import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/app_ui.dart';

/// Step 5 of the screening flow — on-device analysis of the recording.
///
/// Placeholder for Phase 7; the animated waveform and the method-channel
/// call into the native audio pipeline land there.
class ProcessingScreen extends StatelessWidget {
  const ProcessingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('विश्लेषण')),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppStepIndicator(
                current: 5,
                total: 7,
                label: 'चरण 5/7 • विश्लेषण (Processing)',
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: AppSurface(
                      color: scheme.secondaryContainer.withValues(alpha: 0.4),
                      borderColor: scheme.secondaryContainer,
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        children: [
                          AppIconBadge(
                            icon: Icons.memory_rounded,
                            color: scheme.secondary,
                            size: 72,
                          ),
                          const SizedBox(height: 22),
                          Text(
                            'ऑडियो विश्लेषण',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'रिकॉर्ड की गई आवाज़ इसी फ़ोन पर जाँची जाएगी — इसमें '
                            '8 से 30 सेकंड लग सकते हैं। ऑडियो कभी फ़ोन से बाहर '
                            'नहीं जाता।',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 18),
                          const Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              _MetricPill('VTTL'),
                              _MetricPill('CVR'),
                              _MetricPill('PFV'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => context.push('/result'),
                icon: const Icon(Icons.insights_rounded),
                label: const Text('परिणाम देखें'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: scheme.secondary.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: scheme.secondary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
