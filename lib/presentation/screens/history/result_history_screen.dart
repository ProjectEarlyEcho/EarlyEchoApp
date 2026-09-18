import 'package:flutter/material.dart';

import '../../widgets/app_ui.dart';

/// Saved screening results — the worker's record of past sessions.
///
/// Placeholder for Phase 6; the list of locally stored sessions (child,
/// date, risk band, sync state) lands there. Only numeric results are kept —
/// audio is never stored.
class ResultHistoryScreen extends StatelessWidget {
  const ResultHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('पुरानी जाँचें')),
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
                      'सहेजी गई जाँचें',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'पूरी हुई स्क्रीनिंग यहाँ दिखेगी — बच्चे की उम्र, जाँच की '
                      'तारीख और जोखिम श्रेणी (हरा/पीला/लाल) के साथ। केवल '
                      'संख्यात्मक परिणाम सहेजे जाते हैं, ऑडियो नहीं।',
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
