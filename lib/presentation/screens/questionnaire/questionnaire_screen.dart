import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/app_ui.dart';

/// Step 2 of the screening flow — optional CDC milestone questionnaire.
///
/// Placeholder for Phase 3; the questions come later from a Hindi asset.
class QuestionnaireScreen extends StatelessWidget {
  const QuestionnaireScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('प्रश्नावली')),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppStepIndicator(
                current: 2,
                total: 7,
                label: 'चरण 2/7 • प्रश्नावली (वैकल्पिक)',
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
                            icon: Icons.quiz_outlined,
                            color: scheme.secondary,
                            size: 72,
                          ),
                          const SizedBox(height: 22),
                          Text(
                            'वैकल्पिक सवाल',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'CDC विकास मील के पत्थरों के सवाल केवल संदर्भ के '
                            'लिए होंगे। स्क्रीनिंग ध्वनि-आधारित है, इसलिए इस '
                            'चरण को छोड़ा भी जा सकता है।',
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
                onPressed: () => context.push('/consent'),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('सहमति की ओर बढ़ें'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
