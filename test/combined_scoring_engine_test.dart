import 'package:earlyecho/data/models/biomarker_result.dart';
import 'package:earlyecho/domain/combined_scoring_engine.dart';
import 'package:earlyecho/domain/milestone_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const greenAudio = BiomarkerResult(
    riskLevel: RiskLevel.green,
    vttlFlagged: false,
    pfvFlagged: false,
    cvrFlagged: false,
    hindiExplanation: '',
  );
  const yellowAudio = BiomarkerResult(
    riskLevel: RiskLevel.yellow,
    vttlFlagged: true,
    pfvFlagged: false,
    cvrFlagged: false,
    hindiExplanation: '',
  );
  const redAudio = BiomarkerResult(
    riskLevel: RiskLevel.red,
    vttlFlagged: true,
    pfvFlagged: false,
    cvrFlagged: true,
    hindiExplanation: '',
  );
  const questionnaireNormal = MilestoneSummary(
    totalApplicable: 4,
    answeredYes: 4,
    answeredNo: 0,
    status: MilestoneStatus.normal,
  );
  const questionnaireWarning = MilestoneSummary(
    totalApplicable: 4,
    answeredYes: 2,
    answeredNo: 2,
    status: MilestoneStatus.warning,
  );

  const availableVideo = <String, dynamic>{
    'analysis_status': 'AVAILABLE',
    'frames_processed': 120,
    'face_visible_ratio': 0.8,
    'frontal_face_ratio': 0.7,
    'eyes_visible_ratio': 0.65,
    'body_visible_ratio': 0.75,
    'movement_score': 0.2,
    'raw_video_retained': false,
  };

  group('CombinedScoringEngine', () {
    test('keeps a clear audio and questionnaire session GREEN', () {
      final result = CombinedScoringEngine.score(
        audioResult: greenAudio,
        milestoneSummary: questionnaireNormal,
        questionnaireSkipped: false,
        videoQuality: availableVideo,
      );

      expect(result.riskLevel, RiskLevel.green);
      expect(result.recommendation, AssessmentRecommendation.routineFollowUp);
      expect(result.confidence, AssessmentConfidence.videoSupported);
      expect(result.videoQuality.framesProcessed, 120);
      expect(result.questionnaireEscalated, isFalse);
      expect(result.toDecisionTrace()['questionnaire_escalated'], isFalse);
    });

    test(
      'elevates a clear audio result to clinician review for questionnaire concerns',
      () {
        final result = CombinedScoringEngine.score(
          audioResult: greenAudio,
          milestoneSummary: questionnaireWarning,
          questionnaireSkipped: false,
          videoQuality: availableVideo,
        );

        expect(result.riskLevel, RiskLevel.yellow);
        expect(result.questionnaireEscalated, isTrue);
        expect(result.recommendation, AssessmentRecommendation.clinicianReview);
      },
    );

    test(
      'keeps an audio warning YELLOW while questionnaire concerns request review',
      () {
        final result = CombinedScoringEngine.score(
          audioResult: yellowAudio,
          milestoneSummary: questionnaireWarning,
          questionnaireSkipped: false,
          videoQuality: const {'analysis_status': 'LIMITED'},
        );

        expect(result.riskLevel, RiskLevel.yellow);
        expect(result.recommendation, AssessmentRecommendation.clinicianReview);
        expect(result.confidence, AssessmentConfidence.videoLimited);
        expect(result.videoRepeatRecommended, isTrue);
      },
    );

    test(
      'preserves the audio-only RED referral rule when video is unavailable',
      () {
        final result = CombinedScoringEngine.score(
          audioResult: redAudio,
          milestoneSummary: questionnaireWarning,
          questionnaireSkipped: false,
          videoQuality: const {'analysis_status': 'UNAVAILABLE'},
        );

        expect(result.riskLevel, RiskLevel.red);
        expect(result.recommendation, AssessmentRecommendation.deicReferral);
        expect(result.confidence, AssessmentConfidence.videoUnavailable);
      },
    );

    test(
      'keeps incomplete audio as a retry regardless of questionnaire or video',
      () {
        const incompleteAudio = BiomarkerResult(
          riskLevel: RiskLevel.yellow,
          vttlFlagged: false,
          pfvFlagged: false,
          cvrFlagged: false,
          hindiExplanation: '',
          incomplete: true,
        );
        final result = CombinedScoringEngine.score(
          audioResult: incompleteAudio,
          milestoneSummary: questionnaireWarning,
          questionnaireSkipped: false,
          videoQuality: availableVideo,
        );

        expect(result.incomplete, isTrue);
        expect(result.recommendation, AssessmentRecommendation.rescreen);
      },
    );
  });

  test('video quality parser bounds ratios and never retains raw video', () {
    final summary = VideoQualitySummary.fromChannelMap(const {
      'analysis_status': 'AVAILABLE',
      'face_visible_ratio': 2.0,
      'movement_score': -1.0,
    });

    expect(summary.faceVisibleRatio, 1.0);
    expect(summary.movementScore, 0.0);
    expect(summary.toJson()['raw_video_retained'], isFalse);
  });
}
