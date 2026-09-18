import 'package:flutter/material.dart';

import '../../widgets/app_ui.dart';

/// Worker and device preferences.
///
/// Placeholder for Phase 6; the worker's name, default Anganwadi ID, demo
/// mode toggle and sync preferences land there.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('सेटिंग्स')),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Center(
            child: SingleChildScrollView(
              child: AppSurface(
                color: scheme.primaryContainer.withValues(alpha: 0.4),
                borderColor: scheme.primaryContainer,
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    AppIconBadge(
                      icon: Icons.tune_rounded,
                      color: scheme.primary,
                      size: 72,
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'कार्यकर्ता व डिवाइस सेटिंग्स',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'यहाँ कार्यकर्ता का नाम, डिफ़ॉल्ट आंगनबाड़ी आईडी, डेमो '
                      'मोड और सिंक सेटिंग्स रखी जाएंगी।',
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
