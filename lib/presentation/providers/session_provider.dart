import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/child_profile.dart';
import '../../domain/milestone_engine.dart';

/// In-progress screening session, shared across the flow screens.
///
/// Holds the enrollment profile plus the optional questionnaire outcome.
/// Persisted to SQLite only when the screening completes — this state is
/// in-memory and resets with [SessionNotifier.reset].
class SessionState {
  const SessionState({
    this.childProfile,
    this.milestoneAnswers = const {},
    this.milestoneSummary,
    this.questionnaireSkipped = false,
  });

  /// Enrollment details from the child profile screen.
  final ChildProfile? childProfile;

  /// Question id -> हाँ (true) / नहीं (false) from the milestone screen.
  final Map<String, bool> milestoneAnswers;

  /// Context-only questionnaire result; never gates the acoustic outcome.
  final MilestoneSummary? milestoneSummary;

  /// Worker chose to skip the optional questionnaire.
  final bool questionnaireSkipped;

  SessionState copyWith({
    ChildProfile? childProfile,
    Map<String, bool>? milestoneAnswers,
    MilestoneSummary? milestoneSummary,
    bool? questionnaireSkipped,
  }) {
    return SessionState(
      childProfile: childProfile ?? this.childProfile,
      milestoneAnswers: milestoneAnswers ?? this.milestoneAnswers,
      milestoneSummary: milestoneSummary ?? this.milestoneSummary,
      questionnaireSkipped: questionnaireSkipped ?? this.questionnaireSkipped,
    );
  }
}

class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier() : super(const SessionState());

  void setChildProfile(ChildProfile profile) {
    state = state.copyWith(childProfile: profile);
  }

  /// Records a single हाँ/नहीं answer as the worker taps through.
  void recordMilestoneAnswer(String questionId, bool answer) {
    state = state.copyWith(
      milestoneAnswers: {...state.milestoneAnswers, questionId: answer},
    );
  }

  /// Stores the finished questionnaire (answers plus computed summary).
  void setQuestionnaire(Map<String, bool> answers, MilestoneSummary summary) {
    state = state.copyWith(
      milestoneAnswers: answers,
      milestoneSummary: summary,
    );
  }

  void markQuestionnaireSkipped() {
    state = state.copyWith(questionnaireSkipped: true);
  }

  void reset() {
    state = const SessionState();
  }
}

final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>((
  ref,
) {
  return SessionNotifier();
});
