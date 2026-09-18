import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../data/models/child_profile.dart';
import '../../../domain/milestone_engine.dart';
import '../../providers/locale_provider.dart';
import '../../providers/session_provider.dart';
import '../../widgets/app_ui.dart';

const _milestoneAssetPath = 'assets/data/milestones_hi.json';

/// Loads and parses the bundled Hindi milestone questions.
///
/// Overridable so tests can substitute a hermetic loader.
final milestoneQuestionsLoaderProvider =
    Provider<Future<List<MilestoneQuestion>> Function()>(
      (ref) => () async {
        final raw = await rootBundle.loadString(_milestoneAssetPath);
        return MilestoneEngine.parseQuestions(raw);
      },
    );

/// Step 2 of the screening flow — optional CDC milestone questionnaire.
///
/// Questions are loaded from `assets/data/milestones_hi.json` and filtered
/// to the enrolled child's age window. Each is answered हाँ/नहीं and the
/// tally is scored by [MilestoneEngine]. The result is context-only — it
/// is stored on the session but never gates navigation; the worker may
/// also skip the whole step.
class QuestionnaireScreen extends ConsumerStatefulWidget {
  const QuestionnaireScreen({super.key});

  @override
  ConsumerState<QuestionnaireScreen> createState() =>
      _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends ConsumerState<QuestionnaireScreen> {
  final Map<String, bool> _answers = {};
  List<MilestoneQuestion>? _questions;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final questions = await ref.read(milestoneQuestionsLoaderProvider)();
      if (!mounted) return;
      setState(() => _questions = questions);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadFailed = true);
    }
  }

  void _answer(MilestoneQuestion question, bool answer) {
    setState(() => _answers[question.id] = answer);
    ref
        .read(sessionProvider.notifier)
        .recordMilestoneAnswer(question.id, answer);
  }

  void _skip() {
    ref.read(sessionProvider.notifier).markQuestionnaireSkipped();
    context.push('/consent');
  }

  void _finish(int? ageMonths) {
    final summary = MilestoneEngine.summarize(
      questions: _questions ?? const <MilestoneQuestion>[],
      answers: _answers,
      childAgeMonths: ageMonths,
    );
    ref.read(sessionProvider.notifier).setQuestionnaire(_answers, summary);
    context.push('/consent');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(appLocaleProvider);
    final profile = ref.watch(sessionProvider).childProfile;
    final questions = _questions;

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.tr('title_questionnaire', l10n))),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppStepIndicator(
                current: 2,
                total: 7,
                label: AppStrings.stepLabel(
                  2,
                  7,
                  AppStrings.tr('step2_name', l10n),
                  l10n,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(child: _buildBody(profile, questions)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _skip,
                      child: Text(AppStrings.tr('q_skip', l10n)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: questions == null
                          ? null
                          : () => _finish(profile?.childAgeMonths),
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(AppStrings.tr('q_next', l10n)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Questions inside the child's age window. With no enrolled profile all
  /// questions are shown so the step still works standalone.
  List<MilestoneQuestion> _applicableFor(ChildProfile? profile) {
    final all = _questions ?? const <MilestoneQuestion>[];
    if (profile == null) return all;
    return MilestoneEngine.questionsForAge(all, profile.childAgeMonths);
  }

  Widget _buildBody(ChildProfile? profile, List<MilestoneQuestion>? questions) {
    final l10n = ref.watch(appLocaleProvider);
    if (_loadFailed) {
      return Center(child: Text(AppStrings.tr('q_load_failed', l10n)));
    }
    if (questions == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final applicable = _applicableFor(profile);
    if (applicable.isEmpty) {
      return Center(child: Text(AppStrings.tr('q_none', l10n)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.trf('q_progress', l10n, {
            'n': '${_answers.length}',
            'total': '${applicable.length}',
          }),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: applicable.isEmpty ? 0 : _answers.length / applicable.length,
            minHeight: 7,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          AppStrings.tr('q_context_note', l10n),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: applicable.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final question = applicable[index];
              final selected = _answers[question.id];
              return AppSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.trf('q_question_n', l10n, {
                        'n': '${index + 1}',
                      }),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      question.questionHi,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 14),
                    SegmentedButton<bool>(
                      emptySelectionAllowed: true,
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: true,
                          label: Text(AppStrings.tr('q_yes', l10n)),
                        ),
                        ButtonSegment(
                          value: false,
                          label: Text(AppStrings.tr('q_no', l10n)),
                        ),
                      ],
                      selected: selected == null
                          ? const <bool>{}
                          : <bool>{selected},
                      onSelectionChanged: (selection) =>
                          _answer(question, selection.first),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
