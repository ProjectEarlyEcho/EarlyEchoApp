import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/app_ui.dart';

/// Step 7 of the screening flow — the DEIC referral letter.
///
/// Placeholder for Phase 8; the generated letter, PDF export and the
/// WhatsApp share intent land there.
class ReferralScreen extends StatelessWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('रेफरल')),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppStepIndicator(
                current: 7,
                total: 7,
                label: 'चरण 7/7 • रेफरल',
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
                            'DEIC रेफरल पत्र',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'रेफरल पत्र में बच्चे की उम्र, जाँच की तारीख, बायोमार्कर '
                            'मान और निकटतम DEIC (जिला प्रारंभिक हस्तक्षेप केंद्र) का '
                            'संपर्क शामिल होगा। पत्र WhatsApp के माध्यम से साझा किया '
                            'जा सकेगा।',
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
                label: const Text('होम पर लौटें'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
