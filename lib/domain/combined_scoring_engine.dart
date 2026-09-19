import '../data/models/biomarker_result.dart';
import 'milestone_engine.dart';

/// Whether the optional camera stream supplied usable capture context.
///
/// These values describe framing quality only. They must never be read as a
/// measurement of a child's attention, behaviour, or development.
enum VideoQualityStatus { available, limited, unavailable }

/// The degree to which the completed assessment is supported by video context.
enum AssessmentConfidence {
  /// The camera captured enough framing context to support review.
  videoSupported,

  /// Camera analysis ran, but the child was insufficiently in frame.
  videoLimited,

  /// No usable camera context was available; audio and questionnaire remain
  /// valid independent inputs.
  videoUnavailable,
}

/// The next step produced by the combined, explainable assessment.
enum AssessmentRecommendation {
  routineFollowUp,
  rescreen,
  clinicianReview,
  deicReferral,
}

/// Low-dimensional, local-only output of the native video pipeline.
class VideoQualitySummary {
  const VideoQualitySummary({
    required this.status,
    this.framesProcessed = 0,
    this.faceVisibleRatio = 0,
    this.frontalFaceRatio = 0,
    this.eyesVisibleRatio = 0,
    this.bodyVisibleRatio = 0,
    this.movementScore = 0,
    this.qualityReasons = const [],
  });

  final VideoQualityStatus status;
  final int framesProcessed;
  final double faceVisibleRatio;
  final double frontalFaceRatio;
  final double eyesVisibleRatio;
  final double bodyVisibleRatio;
  final double movementScore;
  final List<String> qualityReasons;

  factory VideoQualitySummary.fromChannelMap(Object? raw) {
    if (raw is! Map) {
      return const VideoQualitySummary(status: VideoQualityStatus.unavailable);
    }
    final map = Map<String, dynamic>.from(raw);
    final status = switch (map['analysis_status']?.toString().toUpperCase()) {
      'AVAILABLE' => VideoQualityStatus.available,
      'LIMITED' => VideoQualityStatus.limited,
      _ => VideoQualityStatus.unavailable,
    };
    double ratio(String key) =>
        ((map[key] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0).toDouble();

    return VideoQualitySummary(
      status: status,
      framesProcessed: (map['frames_processed'] as num?)?.toInt() ?? 0,
      faceVisibleRatio: ratio('face_visible_ratio'),
      frontalFaceRatio: ratio('frontal_face_ratio'),
      eyesVisibleRatio: ratio('eyes_visible_ratio'),
      bodyVisibleRatio: ratio('body_visible_ratio'),
      movementScore: ratio('movement_score'),
      qualityReasons:
          (map['quality_reasons'] as List?)
              ?.map((reason) => reason.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'analysis_status': status.name.toUpperCase(),
    'frames_processed': framesProcessed,
    'face_visible_ratio': faceVisibleRatio,
    'frontal_face_ratio': frontalFaceRatio,
    'eyes_visible_ratio': eyesVisibleRatio,
    'body_visible_ratio': bodyVisibleRatio,
    'movement_score': movementScore,
    'quality_reasons': qualityReasons,
    'raw_video_retained': false,
  };
}

/// Explainable result formed from acoustic biomarkers, questionnaire answers,
/// and optional video capture quality.
///
/// The audio [riskLevel] remains the only automatic referral signal. A
/// questionnaire warning can only raise a GREEN acoustic result to YELLOW for
/// clinician review. Video affects confidence and repeat guidance, never risk.
class CombinedScreeningResult {
  const CombinedScreeningResult({
    required this.audioResult,
    required this.milestoneSummary,
    required this.questionnaireSkipped,
    required this.videoQuality,
    required this.riskLevel,
    required this.confidence,
    required this.recommendation,
  });

  final BiomarkerResult audioResult;
  final MilestoneSummary? milestoneSummary;
  final bool questionnaireSkipped;
  final VideoQualitySummary videoQuality;
  final RiskLevel riskLevel;
  final AssessmentConfidence confidence;
  final AssessmentRecommendation recommendation;

  bool get incomplete => audioResult.incomplete;

  /// Audio-quality reasons are retained for the existing retry screen when
  /// capture did not produce a valid acoustic feature vector.
  List<String> get qualityReasons => audioResult.qualityReasons;

  bool get questionnaireWarning =>
      !questionnaireSkipped &&
      milestoneSummary?.status == MilestoneStatus.warning;

  bool get questionnaireEscalated =>
      !incomplete &&
      audioResult.riskLevel == RiskLevel.green &&
      questionnaireWarning &&
      riskLevel == RiskLevel.yellow;

  bool get videoRepeatRecommended =>
      videoQuality.status == VideoQualityStatus.limited;

  /// Stored with each session so a clinician can independently see the basis
  /// of the displayed recommendation without access to raw recordings.
  Map<String, dynamic> toDecisionTrace() => {
    'version': 'combined-assessment-v1',
    'risk_level': riskLevel.name,
    'recommendation': recommendation.name,
    'confidence': confidence.name,
    'audio': {
      'risk_level': audioResult.riskLevel.name,
      'flag_count': audioResult.flagCount,
      'vttl_flagged': audioResult.vttlFlagged,
      'pfv_flagged': audioResult.pfvFlagged,
      'cvr_flagged': audioResult.cvrFlagged,
      'analysis_incomplete': audioResult.incomplete,
    },
    'questionnaire': questionnaireSkipped
        ? <String, dynamic>{'status': 'skipped'}
        : milestoneSummary?.toJson() ??
              <String, dynamic>{'status': 'not_completed'},
    'questionnaire_escalated': questionnaireEscalated,
    'video_quality': videoQuality.toJson(),
  };
}

/// Combines the three collection paths without treating video detections as a
/// diagnostic or behavioural model.
class CombinedScoringEngine {
  CombinedScoringEngine._();

  static CombinedScreeningResult score({
    required BiomarkerResult audioResult,
    required MilestoneSummary? milestoneSummary,
    required bool questionnaireSkipped,
    Object? videoQuality,
  }) {
    final video = VideoQualitySummary.fromChannelMap(videoQuality);
    final confidence = switch (video.status) {
      VideoQualityStatus.available => AssessmentConfidence.videoSupported,
      VideoQualityStatus.limited => AssessmentConfidence.videoLimited,
      VideoQualityStatus.unavailable => AssessmentConfidence.videoUnavailable,
    };
    final questionnaireWarning =
        !questionnaireSkipped &&
        milestoneSummary?.status == MilestoneStatus.warning;

    if (audioResult.incomplete) {
      return CombinedScreeningResult(
        audioResult: audioResult,
        milestoneSummary: milestoneSummary,
        questionnaireSkipped: questionnaireSkipped,
        videoQuality: video,
        riskLevel: audioResult.riskLevel,
        confidence: confidence,
        recommendation: AssessmentRecommendation.rescreen,
      );
    }

    final riskLevel = switch (audioResult.riskLevel) {
      RiskLevel.red => RiskLevel.red,
      RiskLevel.yellow => RiskLevel.yellow,
      RiskLevel.green when questionnaireWarning => RiskLevel.yellow,
      RiskLevel.green => RiskLevel.green,
    };
    final recommendation = switch (riskLevel) {
      RiskLevel.red => AssessmentRecommendation.deicReferral,
      RiskLevel.yellow when questionnaireWarning =>
        AssessmentRecommendation.clinicianReview,
      RiskLevel.yellow => AssessmentRecommendation.rescreen,
      RiskLevel.green => AssessmentRecommendation.routineFollowUp,
    };

    return CombinedScreeningResult(
      audioResult: audioResult,
      milestoneSummary: milestoneSummary,
      questionnaireSkipped: questionnaireSkipped,
      videoQuality: video,
      riskLevel: riskLevel,
      confidence: confidence,
      recommendation: recommendation,
    );
  }
}
