import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../data/models/child_profile.dart';
import '../../../domain/milestone_engine.dart';
import '../../../domain/my_child_engine.dart';
import '../../providers/locale_provider.dart';
import '../../providers/session_provider.dart';
import '../../widgets/app_ui.dart';

/// Loads the complete MozhiMuthal developmental question bank.
///
/// Overridable so tests can substitute a hermetic loader.
final milestoneQuestionsLoaderProvider =
    Provider<Future<List<MilestoneQuestion>> Function()>(
      (ref) => () async {
        return MyChildEngine.questions
            .where((question) => !question.isMchatQuestion)
            .map(
              (question) => MilestoneQuestion(
                id: question.id,
                ageMinMonths: question.minAge,
                ageMaxMonths: question.maxAge,
                questionHi: question.prompt,
                questionEn: question.prompt,
                domain: MyChildEngine.questionGroupFor(question),
              ),
            )
            .toList();
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
  final ScrollController _questionScrollController = ScrollController();
  List<MilestoneQuestion>? _questions;
  bool _loadFailed = false;
  int _currentQuestionIndex = 0;

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

  void _showQuestion(int index) {
    setState(() => _currentQuestionIndex = index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _questionScrollController.hasClients) {
        _questionScrollController.jumpTo(0);
      }
    });
  }

  @override
  void dispose() {
    _questionScrollController.dispose();
    super.dispose();
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
    final applicable = MilestoneEngine.questionsForAge(
      all,
      profile.childAgeMonths,
    );
    return applicable.isEmpty ? _olderChildQuestions : applicable;
  }

  static const _olderChildQuestions = <MilestoneQuestion>[
    MilestoneQuestion(
      id: 'older_conversation',
      ageMinMonths: 37,
      ageMaxMonths: 60,
      questionHi: 'क्या बच्चा कम से कम दो बार आगे-पीछे बातचीत कर सकता है?',
      questionEn:
          'Can the child have a conversation with at least two back-and-forth exchanges?',
      domain: 'Communication',
    ),
    MilestoneQuestion(
      id: 'older_questions',
      ageMinMonths: 37,
      ageMaxMonths: 60,
      questionHi: 'क्या बच्चा कौन, क्या, कहाँ या क्यों जैसे सवाल पूछता है?',
      questionEn:
          'Does the child ask questions such as who, what, where, or why?',
      domain: 'Communication',
    ),
    MilestoneQuestion(
      id: 'older_name',
      ageMinMonths: 37,
      ageMaxMonths: 60,
      questionHi: 'क्या बच्चा पूछने पर अपना पहला नाम बताता है?',
      questionEn: 'Does the child say their first name when asked?',
      domain: 'Communication',
    ),
    MilestoneQuestion(
      id: 'older_imaginative_play',
      ageMinMonths: 37,
      ageMaxMonths: 60,
      questionHi: 'क्या बच्चा कल्पना का खेल खेलता है?',
      questionEn: 'Does the child play pretend?',
      domain: 'Learning and play',
    ),
    MilestoneQuestion(
      id: 'older_other_children',
      ageMinMonths: 37,
      ageMaxMonths: 60,
      questionHi: 'क्या बच्चा दूसरे बच्चों को देखकर उनके साथ खेलता है?',
      questionEn: 'Does the child notice and join other children at play?',
      domain: 'Social connection',
    ),
    MilestoneQuestion(
      id: 'older_circle',
      ageMinMonths: 37,
      ageMaxMonths: 60,
      questionHi: 'क्या बच्चा दिखाने पर गोला बना सकता है?',
      questionEn: 'Can the child draw a circle when shown how?',
      domain: 'Learning and play',
    ),
    MilestoneQuestion(
      id: 'older_dress',
      ageMinMonths: 37,
      ageMaxMonths: 60,
      questionHi: 'क्या बच्चा कुछ कपड़े बिना मदद के पहन सकता है?',
      questionEn: 'Can the child put on some clothes without help?',
      domain: 'Everyday skills',
    ),
    MilestoneQuestion(
      id: 'older_fork',
      ageMinMonths: 37,
      ageMaxMonths: 60,
      questionHi: 'क्या बच्चा कांटा इस्तेमाल कर सकता है?',
      questionEn: 'Can the child use a fork?',
      domain: 'Everyday skills',
    ),
  ];

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

    final currentIndex = _currentQuestionIndex.clamp(0, applicable.length - 1);
    final question = applicable[currentIndex];
    final selected = _answers[question.id];
    final isLastQuestion = currentIndex == applicable.length - 1;

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
        Text(
          AppStrings.trf('q_question_n', l10n, {'n': '${currentIndex + 1}'}),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: AppSurface(
            padding: EdgeInsets.zero,
            child: SingleChildScrollView(
              controller: _questionScrollController,
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    question.domain?.toUpperCase() ?? '',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    question.questionForLanguage(l10n?.languageCode),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
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
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: currentIndex == 0
                    ? null
                    : () => _showQuestion(currentIndex - 1),
                icon: const Icon(Icons.arrow_back_rounded),
                label: Text(AppStrings.tr('q_previous', l10n)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: selected == null
                    ? null
                    : () {
                        if (isLastQuestion) {
                          _finish(profile?.childAgeMonths);
                        } else {
                          _showQuestion(currentIndex + 1);
                        }
                      },
                icon: Icon(
                  isLastQuestion
                      ? Icons.arrow_forward_rounded
                      : Icons.navigate_next_rounded,
                ),
                label: Text(
                  isLastQuestion
                      ? AppStrings.tr('q_next', l10n)
                      : AppStrings.tr('q_next_question', l10n),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
