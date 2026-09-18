import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/biomarker_result.dart';
import '../../data/models/child_profile.dart';
import '../../data/models/session_features.dart';
import '../../data/repositories/care_repository.dart';
import '../../domain/milestone_engine.dart';

/// In-progress screening session, shared across the flow screens.
///
/// Holds the enrollment profile, the optional questionnaire outcome, and
/// the confirmed parental-consent marker.
/// Persisted to SQLite only when the screening completes — this state is
/// in-memory and resets with [SessionNotifier.reset].
class SessionState {
  const SessionState({
    this.childProfile,
    this.selectedCareChild,
    this.milestoneAnswers = const {},
    this.milestoneSummary,
    this.questionnaireSkipped = false,
    this.consentedAt,
    this.consentLogId,
    this.protocolTimings = const [],
    this.features,
    this.biomarkerResult,
    this.pipelineResponse = const {},
  });

  /// Enrollment details from the child profile screen.
  final ChildProfile? childProfile;
  final CareChild? selectedCareChild;

  /// Question id -> हाँ (true) / नहीं (false) from the milestone screen.
  final Map<String, bool> milestoneAnswers;

  /// Context-only questionnaire result; never gates the acoustic outcome.
  final MilestoneSummary? milestoneSummary;

  /// Worker chose to skip the optional questionnaire.
  final bool questionnaireSkipped;

  /// Timestamp of the confirmed parental consent — the consent gate
  /// timestamp that is also persisted to `consent_logs`.
  final DateTime? consentedAt;

  /// Local `consent_logs` id for the confirmation, so the row can be
  /// linked to this session once the session is persisted.
  final String? consentLogId;

  /// Capture window per elicitation protocol in the §5.1 contract shape —
  /// `[{'protocol': 'rattle', 'start_ms': 0, 'end_ms': 60000}, ...]` —
  /// handed to the native audio pipeline when the recording is analysed.
  final List<Map<String, Object>> protocolTimings;

  /// Parsed feature vector returned by the native pipeline.
  final SessionFeatures? features;

  /// Scored risk classification derived from [features]. Null until the
  /// pipeline response lands; [BiomarkerResult.incomplete] marks a session
  /// that must be retried rather than screened.
  final BiomarkerResult? biomarkerResult;

  /// Raw channel payload kept for `audio_source_used` and `decision_trace`
  /// when the session is persisted.
  final Map<String, dynamic> pipelineResponse;

  SessionState copyWith({
    ChildProfile? childProfile,
    CareChild? selectedCareChild,
    Map<String, bool>? milestoneAnswers,
    MilestoneSummary? milestoneSummary,
    bool? questionnaireSkipped,
    DateTime? consentedAt,
    String? consentLogId,
    List<Map<String, Object>>? protocolTimings,
    SessionFeatures? features,
    BiomarkerResult? biomarkerResult,
    Map<String, dynamic>? pipelineResponse,
  }) {
    return SessionState(
      childProfile: childProfile ?? this.childProfile,
      selectedCareChild: selectedCareChild ?? this.selectedCareChild,
      milestoneAnswers: milestoneAnswers ?? this.milestoneAnswers,
      milestoneSummary: milestoneSummary ?? this.milestoneSummary,
      questionnaireSkipped: questionnaireSkipped ?? this.questionnaireSkipped,
      consentedAt: consentedAt ?? this.consentedAt,
      consentLogId: consentLogId ?? this.consentLogId,
      protocolTimings: protocolTimings ?? this.protocolTimings,
      features: features ?? this.features,
      biomarkerResult: biomarkerResult ?? this.biomarkerResult,
      pipelineResponse: pipelineResponse ?? this.pipelineResponse,
    );
  }
}

class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier() : super(const SessionState());

  void setChildProfile(ChildProfile profile) {
    state = state.copyWith(childProfile: profile);
  }

  void selectCareChild(CareChild child) {
    state = state.copyWith(selectedCareChild: child);
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

  /// Records that the worker confirmed parental consent on the consent
  /// screen. [consentLogId] is the local `consent_logs` row id, kept so the
  /// audit entry can be linked to this session when it is persisted.
  void recordConsent({
    required DateTime consentedAt,
    required String consentLogId,
  }) {
    state = state.copyWith(
      consentedAt: consentedAt,
      consentLogId: consentLogId,
    );
  }

  /// Records the per-protocol capture windows produced by the guided
  /// elicitation sequence, ready for the native audio pipeline.
  void recordProtocolTimings(List<Map<String, Object>> timings) {
    state = state.copyWith(protocolTimings: timings);
  }

  /// Stores the analysed pipeline outcome: parsed features, the scored
  /// result, and the raw channel payload kept for persistence.
  void recordAnalysisResult({
    required SessionFeatures features,
    required BiomarkerResult result,
    required Map<String, dynamic> rawResponse,
  }) {
    state = state.copyWith(
      features: features,
      biomarkerResult: result,
      pipelineResponse: rawResponse,
    );
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
