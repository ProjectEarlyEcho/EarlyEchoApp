import 'dart:convert';

/// A single CDC-style developmental milestone question.
///
/// Questions live in `assets/data/milestones_hi.json` and are filtered by
/// [appliesTo] so each child only sees milestones expected at their age.
class MilestoneQuestion {
  const MilestoneQuestion({
    required this.id,
    required this.ageMinMonths,
    required this.ageMaxMonths,
    required this.questionHi,
    this.domain,
  });

  /// Stable identifier used as the key in the answers map.
  final String id;

  /// Inclusive age window (months) for which the milestone is expected.
  final int ageMinMonths;
  final int ageMaxMonths;

  /// Hindi question text shown to the worker.
  final String questionHi;

  /// Optional CDC domain tag (social, language, cognitive, motor).
  final String? domain;

  bool appliesTo(int childAgeMonths) =>
      childAgeMonths >= ageMinMonths && childAgeMonths <= ageMaxMonths;

  Map<String, dynamic> toJson() => {
    'id': id,
    'age_min_months': ageMinMonths,
    'age_max_months': ageMaxMonths,
    'question_hi': questionHi,
    if (domain != null) 'domain': domain,
  };

  factory MilestoneQuestion.fromJson(Map<String, dynamic> json) {
    return MilestoneQuestion(
      id: json['id'] as String,
      ageMinMonths: (json['age_min_months'] as num).toInt(),
      ageMaxMonths: (json['age_max_months'] as num).toInt(),
      questionHi: json['question_hi'] as String,
      domain: json['domain'] as String?,
    );
  }
}

/// Overall questionnaire outcome for a session.
enum MilestoneStatus { normal, warning }

/// Aggregated result of the optional milestone questionnaire.
///
/// `true` answers mean "milestone met" (हाँ); `false` means "not yet" (नहीं).
class MilestoneSummary {
  const MilestoneSummary({
    required this.totalApplicable,
    required this.answeredYes,
    required this.answeredNo,
    required this.status,
  });

  /// Questions in the child's age window.
  final int totalApplicable;

  /// Age-applicable questions answered हाँ.
  final int answeredYes;

  /// Age-applicable questions answered नहीं — each counts as a concern.
  final int answeredNo;

  final MilestoneStatus status;

  int get answered => answeredYes + answeredNo;
  int get unanswered => totalApplicable - answered;

  /// Number of missed milestones; kept as the explicit "concern" signal.
  int get concernCount => answeredNo;

  Map<String, dynamic> toJson() => {
    'total_applicable': totalApplicable,
    'answered_yes': answeredYes,
    'answered_no': answeredNo,
    'unanswered': unanswered,
    'concern_count': concernCount,
    'status': status.name,
  };
}

/// Scores the optional CDC milestone questionnaire.
///
/// The questionnaire is a *context-only* signal: its [MilestoneSummary] is
/// stored alongside the session to help the worker and clinician interpret
/// the screening, but it never overrides, gates, or alters the acoustic
/// biomarker result produced by `ScoringEngine`.
class MilestoneEngine {
  MilestoneEngine._();

  /// Number of missed milestones that moves the status to warning.
  static const int warningConcernThreshold = 2;

  /// Parses the bundled `assets/data/milestones_hi.json` document.
  static List<MilestoneQuestion> parseQuestions(String jsonString) {
    final decoded = jsonDecode(jsonString);
    final list = decoded is Map<String, dynamic>
        ? decoded['questions'] as List<dynamic>
        : decoded as List<dynamic>;
    return list
        .map(
          (entry) => MilestoneQuestion.fromJson(entry as Map<String, dynamic>),
        )
        .toList();
  }

  /// Returns only the questions applicable to [childAgeMonths].
  static List<MilestoneQuestion> questionsForAge(
    List<MilestoneQuestion> questions,
    int childAgeMonths,
  ) {
    return questions.where((q) => q.appliesTo(childAgeMonths)).toList();
  }

  /// Tally for [answers] over the age-applicable subset of [questions].
  ///
  /// Answers for questions outside the child's age window are ignored;
  /// a null [childAgeMonths] scores against the full list. Status is
  /// [MilestoneStatus.warning] when the concern count reaches
  /// [warningConcernThreshold]; empty answers therefore score normal.
  static MilestoneSummary summarize({
    required List<MilestoneQuestion> questions,
    required Map<String, bool> answers,
    required int? childAgeMonths,
  }) {
    final applicable = childAgeMonths == null
        ? questions
        : questionsForAge(questions, childAgeMonths);
    var yes = 0;
    var no = 0;
    for (final question in applicable) {
      final answer = answers[question.id];
      if (answer == null) continue;
      if (answer) {
        yes++;
      } else {
        no++;
      }
    }
    return MilestoneSummary(
      totalApplicable: applicable.length,
      answeredYes: yes,
      answeredNo: no,
      status: no >= warningConcernThreshold
          ? MilestoneStatus.warning
          : MilestoneStatus.normal,
    );
  }
}
