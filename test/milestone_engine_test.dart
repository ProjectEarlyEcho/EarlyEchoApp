import 'package:earlyecho/domain/milestone_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const questions = <MilestoneQuestion>[
    MilestoneQuestion(
      id: 'a',
      ageMinMonths: 12,
      ageMaxMonths: 24,
      questionHi: 'प्रश्न अ',
    ),
    MilestoneQuestion(
      id: 'b',
      ageMinMonths: 12,
      ageMaxMonths: 24,
      questionHi: 'प्रश्न ब',
    ),
    MilestoneQuestion(
      id: 'c',
      ageMinMonths: 12,
      ageMaxMonths: 24,
      questionHi: 'प्रश्न स',
    ),
    MilestoneQuestion(
      id: 'd',
      ageMinMonths: 36,
      ageMaxMonths: 60,
      questionHi: 'प्रश्न द',
    ),
  ];

  group('parseQuestions', () {
    test('parses the bundled JSON document shape', () {
      const json = '''
      {
        "version": 1,
        "questions": [
          {
            "id": "q_walks_alone",
            "age_min_months": 15,
            "age_max_months": 30,
            "domain": "motor",
            "question_hi": "क्या बच्चा बिना सहारे के कुछ कदम चलता है?"
          }
        ]
      }
      ''';

      final parsed = MilestoneEngine.parseQuestions(json);

      expect(parsed, hasLength(1));
      expect(parsed.single.id, 'q_walks_alone');
      expect(parsed.single.domain, 'motor');
      expect(parsed.single.appliesTo(20), isTrue);
      expect(parsed.single.appliesTo(31), isFalse);
    });
  });

  group('summarize', () {
    test('all yes answers produce a normal status', () {
      final summary = MilestoneEngine.summarize(
        questions: questions,
        answers: const {'a': true, 'b': true, 'c': true},
        childAgeMonths: 18,
      );

      expect(summary.totalApplicable, 3);
      expect(summary.answeredYes, 3);
      expect(summary.concernCount, 0);
      expect(summary.status, MilestoneStatus.normal);
    });

    test('two or more missed milestones produce a warning', () {
      final summary = MilestoneEngine.summarize(
        questions: questions,
        answers: const {'a': false, 'b': false, 'c': true},
        childAgeMonths: 18,
      );

      expect(summary.concernCount, 2);
      expect(summary.status, MilestoneStatus.warning);
    });

    test('a single missed milestone stays normal', () {
      final summary = MilestoneEngine.summarize(
        questions: questions,
        answers: const {'a': true, 'b': false, 'c': true},
        childAgeMonths: 18,
      );

      expect(summary.concernCount, 1);
      expect(summary.status, MilestoneStatus.normal);
    });

    test('only age-applicable questions are counted', () {
      final summary = MilestoneEngine.summarize(
        questions: questions,
        answers: const {'a': true, 'b': true, 'c': true, 'd': false},
        childAgeMonths: 18,
      );

      // Question d targets 36–60 months — its "no" must not count at 18m.
      expect(summary.totalApplicable, 3);
      expect(summary.concernCount, 0);
      expect(summary.status, MilestoneStatus.normal);

      final older = MilestoneEngine.summarize(
        questions: questions,
        answers: const {'a': false, 'd': false},
        childAgeMonths: 40,
      );

      // At 40 months only d applies; a is out of window.
      expect(older.totalApplicable, 1);
      expect(older.concernCount, 1);
    });

    test('empty answers produce a normal, fully unanswered summary', () {
      final summary = MilestoneEngine.summarize(
        questions: questions,
        answers: const {},
        childAgeMonths: 18,
      );

      expect(summary.totalApplicable, 3);
      expect(summary.answered, 0);
      expect(summary.unanswered, 3);
      expect(summary.status, MilestoneStatus.normal);
    });
  });
}
