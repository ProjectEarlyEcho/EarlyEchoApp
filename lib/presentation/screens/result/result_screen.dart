import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../widgets/app_ui.dart';

/// Step 6 of the screening flow — RED/YELLOW/GREEN risk classification.
///
/// Placeholder for Phase 7; the scored biomarker values and the Hindi
/// explanation text land there. The colour bands already use the shared
/// risk colours so later phases plug into the same visual language.
class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('परिणाम')),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppStepIndicator(
                current: 6,
                total: 7,
                label: 'चरण 6/7 • परिणाम',
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
                            icon: Icons.fact_check_rounded,
                            color: scheme.primary,
                            size: 72,
                          ),
                          const SizedBox(height: 22),
                          Text(
                            'जोखिम वर्गीकरण',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'VTTL, CVR और PFV बायोमार्कर के आधार पर परिणाम इन '
                            'तीन श्रेणियों में से एक में दिखेगा:',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 8),
                          const _RiskRow(
                            color: EarlyEchoTheme.riskGreen,
                            title: 'हरा — सामान्य विकास',
                            subtitle: 'आगे कोई कार्रवाई ज़रूरी नहीं',
                          ),
                          const _RiskRow(
                            color: EarlyEchoTheme.riskYellow,
                            title: 'पीला — एक संकेत',
                            subtitle: '3 महीने में दोबारा स्क्रीनिंग की सलाह',
                          ),
                          const _RiskRow(
                            color: EarlyEchoTheme.riskRed,
                            title: 'लाल — DEIC रेफरल',
                            subtitle: 'शीघ्र विशेषज्ञ मूल्यांकन की सलाह',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => context.push('/referral'),
                icon: const Icon(Icons.description_outlined),
                label: const Text('रेफरल देखें'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RiskRow extends StatelessWidget {
  const _RiskRow({
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 16,
            height: 16,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
