import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/app_ui.dart';

/// Step 3 of the screening flow — recorded parent consent.
///
/// Placeholder for Phase 4; the Hindi consent audio and the timestamped
/// confirmation log land there.
class ConsentScreen extends StatelessWidget {
  const ConsentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('सहमति')),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppStepIndicator(
                current: 3,
                total: 7,
                label: 'चरण 3/7 • सहमति',
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
                            icon: Icons.record_voice_over_outlined,
                            color: scheme.primary,
                            size: 72,
                          ),
                          const SizedBox(height: 22),
                          Text(
                            'अभिभावक की सहमति',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'रिकॉर्डिंग शुरू करने से पहले अभिभावक को हिंदी में '
                            'सहमति का वाक्य सुनाया जाएगा। "अभिभावक ने सहमति '
                            'दी" चुनने पर सहमति समय के साथ दर्ज हो जाएगी।',
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
                onPressed: () => context.push('/elicitation'),
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('अभिभावक ने सहमति दी'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
