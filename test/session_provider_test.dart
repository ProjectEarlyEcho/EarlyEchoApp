import 'package:earlyecho/data/models/child_profile.dart';
import 'package:earlyecho/domain/milestone_engine.dart';
import 'package:earlyecho/presentation/providers/session_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const profile = ChildProfile(
    childAgeMonths: 30,
    anganwadiId: 'IN-MP-042',
    stateCode: 'Madhya Pradesh',
    districtCode: 'Indore',
    workerName: 'सीमा',
  );

  ProviderContainer makeContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  test('starts empty', () {
    final state = makeContainer().read(sessionProvider);

    expect(state.childProfile, isNull);
    expect(state.milestoneAnswers, isEmpty);
    expect(state.milestoneSummary, isNull);
    expect(state.questionnaireSkipped, isFalse);
  });

  test('setChildProfile stores the enrollment details', () {
    final container = makeContainer();
    container.read(sessionProvider.notifier).setChildProfile(profile);

    final state = container.read(sessionProvider);
    expect(state.childProfile, same(profile));
    expect(state.childProfile!.childAgeMonths, 30);
    expect(state.childProfile!.isAgeValid, isTrue);
  });

  test('recordMilestoneAnswer accumulates हाँ/नहीं answers', () {
    final container = makeContainer();
    final notifier = container.read(sessionProvider.notifier);

    notifier.recordMilestoneAnswer('q_walks_alone', true);
    notifier.recordMilestoneAnswer('q_points_to_ask', false);
    notifier.recordMilestoneAnswer('q_walks_alone', false); // retap overrides

    final answers = container.read(sessionProvider).milestoneAnswers;
    expect(answers, {'q_walks_alone': false, 'q_points_to_ask': false});
  });

  test('setQuestionnaire stores answers and summary together', () {
    final container = makeContainer();
    final notifier = container.read(sessionProvider.notifier);

    const questions = <MilestoneQuestion>[
      MilestoneQuestion(
        id: 'a',
        ageMinMonths: 12,
        ageMaxMonths: 36,
        questionHi: 'प्रश्न अ',
      ),
      MilestoneQuestion(
        id: 'b',
        ageMinMonths: 12,
        ageMaxMonths: 36,
        questionHi: 'प्रश्न ब',
      ),
    ];
    const answers = {'a': true, 'b': false};
    final summary = MilestoneEngine.summarize(
      questions: questions,
      answers: answers,
      childAgeMonths: 30,
    );

    notifier.setQuestionnaire(answers, summary);

    final state = container.read(sessionProvider);
    expect(state.milestoneAnswers, answers);
    expect(state.milestoneSummary, same(summary));
    expect(state.milestoneSummary!.concernCount, 1);
  });

  test('profile and questionnaire persist together until reset', () {
    final container = makeContainer();
    final notifier = container.read(sessionProvider.notifier);

    notifier.setChildProfile(profile);
    notifier.markQuestionnaireSkipped();

    var state = container.read(sessionProvider);
    expect(state.childProfile, same(profile));
    expect(state.questionnaireSkipped, isTrue);

    notifier.reset();
    state = container.read(sessionProvider);
    expect(state.childProfile, isNull);
    expect(state.questionnaireSkipped, isFalse);
  });
}
