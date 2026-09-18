import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/app_ui.dart';

/// The worker's landing screen — entry point into the screening flow.
///
/// Placeholder for Phase 6; the recent-screenings list and the pending-sync
/// banner land there. For now it exposes the three top-level destinations:
/// starting a new screening, reviewing past results, and opening settings.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('EarlyEcho'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'पुरानी जाँचें',
            onPressed: () => context.push('/history'),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'सेटिंग्स',
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const AppSectionHeader(
                          title: 'नमस्ते!',
                          subtitle:
                              'बच्चे की आवाज़ से विकास की शुरुआती जाँच — '
                              'ध्वनि-आधारित स्क्रीनिंग।',
                        ),
                        const SizedBox(height: 16),
                        AppSurface(
                          color: scheme.primaryContainer.withValues(alpha: 0.4),
                          borderColor: scheme.primaryContainer,
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            children: [
                              AppIconBadge(
                                icon: Icons.hearing_rounded,
                                color: scheme.primary,
                                size: 72,
                              ),
                              const SizedBox(height: 22),
                              Text(
                                'ध्वनि-आधारित विकास जाँच',
                                textAlign: TextAlign.center,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'तीन छोटी गतिविधियों में बच्चे की आवाज़ '
                                'रिकॉर्ड होती है। यह निदान नहीं, केवल '
                                'शुरुआती जाँच है।',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        AppSurface(
                          color: scheme.secondaryContainer.withValues(
                            alpha: 0.4,
                          ),
                          borderColor: scheme.secondaryContainer,
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              AppIconBadge(
                                icon: Icons.shield_outlined,
                                color: scheme.secondary,
                                size: 40,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'निजता पहले',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'ऑडियो इसी फ़ोन पर जाँचा जाता है — '
                                      'रिकॉर्डिंग फ़ोन से बाहर नहीं जाती।',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => context.push('/child-profile'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('नई स्क्रीनिंग शुरू करें'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => context.push('/history'),
                icon: const Icon(Icons.history_rounded),
                label: const Text('पुरानी जाँचें देखें'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
