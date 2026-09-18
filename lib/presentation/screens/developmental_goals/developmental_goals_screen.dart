import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../domain/cdc_developmental_goals.dart';
import '../../providers/locale_provider.dart';
import '../../providers/session_provider.dart';
import '../../widgets/app_ui.dart';

class DevelopmentalGoalsScreen extends ConsumerStatefulWidget {
  const DevelopmentalGoalsScreen({super.key});

  @override
  ConsumerState<DevelopmentalGoalsScreen> createState() =>
      _DevelopmentalGoalsScreenState();
}

class _DevelopmentalGoalsScreenState
    extends ConsumerState<DevelopmentalGoalsScreen> {
  final Set<String> _checkedGoals = {};

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(sessionProvider).childProfile;
    final locale = ref.watch(appLocaleProvider);
    if (profile == null) return const Scaffold(body: SizedBox());
    final group = CdcDevelopmentalGoals.forAge(profile.childAgeMonths);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.tr('title_goals', locale))),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppStepIndicator(
                current: 2,
                total: 8,
                label: AppStrings.stepLabel(
                  2,
                  8,
                  AppStrings.tr('step2_name', locale),
                  locale,
                ),
              ),
              const SizedBox(height: 16),
              AppSurface(
                color: scheme.secondaryContainer.withValues(alpha: .34),
                borderColor: scheme.secondaryContainer,
                child: Text(
                  AppStrings.trf('goals_intro', locale, {
                    'age': group.label,
                    'count': '${group.goalCount}',
                  }),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    for (final entry in group.categories.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Text(
                          entry.key,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      AppSurface(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          children: [
                            for (final goal in entry.value)
                              CheckboxListTile(
                                value: _checkedGoals.contains(goal),
                                onChanged: (checked) => setState(() {
                                  if (checked ?? false) {
                                    _checkedGoals.add(goal);
                                  } else {
                                    _checkedGoals.remove(goal);
                                  }
                                }),
                                title: Text(goal),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    AppSurface(
                      color: scheme.tertiaryContainer.withValues(alpha: .28),
                      borderColor: scheme.tertiaryContainer,
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        AppStrings.tr('goals_disclaimer', locale),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse(CdcDevelopmentalGoals.sourceUrl),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: Text(AppStrings.tr('goals_source', locale)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => context.push('/questionnaire'),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(AppStrings.tr('goals_continue', locale)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
