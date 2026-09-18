import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/app_ui.dart';

/// Step 1 of the screening flow — collects the child's details.
///
/// Placeholder for Phase 3; the form itself is not built yet.
class ChildProfileScreen extends StatelessWidget {
  const ChildProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('बच्चे की जानकारी')),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppStepIndicator(
                current: 1,
                total: 7,
                label: 'चरण 1/7 • बच्चे की जानकारी',
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
                            icon: Icons.child_care_rounded,
                            color: scheme.primary,
                            size: 72,
                          ),
                          const SizedBox(height: 22),
                          Text(
                            'बच्चे का विवरण',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'बच्चे का नाम (वैकल्पिक), उम्र महीनों में (12–60), '
                            'आंगनबाड़ी आईडी, राज्य और जिला यहाँ दर्ज किया जाएगा।',
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
                onPressed: () => context.push('/questionnaire'),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('प्रश्नावली की ओर बढ़ें'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
