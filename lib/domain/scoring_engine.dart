import '../data/models/biomarker_result.dart';
import '../data/models/session_features.dart';

/// Threshold rules that convert raw acoustic biomarkers into a
/// RED / YELLOW / GREEN risk classification.
///
/// Rules (see EarlyEcho_CONTEXT.md §3.5):
/// - VTTL flagged when median turn-taking latency > 1000 ms (all ages).
/// - PFV flagged when semitone std dev < 15.0 (age >= 36 months only).
/// - CVR flagged below the age-bucketed minimum ratio.
/// - 0 flags -> GREEN, 1 flag -> YELLOW, >= 2 flags -> RED.
class ScoringEngine {
  static const double vttlThresholdMs = 1000.0;
  static const double pfvFlatThresholdSemitones = 15.0;
  static const int pfvMinAgeMonths = 36;

  static const int childMinAgeMonths = 12;
  static const int childMaxAgeMonths = 60;

  /// Minimum Child Vocalization Ratio per age bucket.
  static const double cvrThreshold12to24 = 0.08;
  static const double cvrThreshold24to36 = 0.12;
  static const double cvrThreshold36to60 = 0.15;

  static BiomarkerResult score(SessionFeatures features) {
    if (!features.isComplete) {
      return BiomarkerResult(
        riskLevel: RiskLevel.yellow,
        vttlFlagged: false,
        pfvFlagged: false,
        cvrFlagged: false,
        hindiExplanation:
            'ऑडियो विश्लेषण अधूरा रहा। कृपया दोबारा स्क्रीनिंग करें।',
        qualityReasons: features.qualityReasons,
        incomplete: true,
      );
    }

    final vttlFlagged = features.vttlMs > vttlThresholdMs;
    final pfvFlagged =
        features.childAgeMonths >= pfvMinAgeMonths &&
        features.pfvStd < pfvFlatThresholdSemitones;
    final cvrFlagged =
        features.cvrRatio < cvrThresholdForAge(features.childAgeMonths);

    final flags = <bool>[vttlFlagged, pfvFlagged, cvrFlagged];
    final flagCount = flags.where((f) => f).length;

    final riskLevel = switch (flagCount) {
      0 => RiskLevel.green,
      1 => RiskLevel.yellow,
      _ => RiskLevel.red,
    };

    return BiomarkerResult(
      riskLevel: riskLevel,
      vttlFlagged: vttlFlagged,
      pfvFlagged: pfvFlagged,
      cvrFlagged: cvrFlagged,
      hindiExplanation: _explanationFor(riskLevel),
    );
  }

  /// CVR minimum by age bucket: 12–24m -> 0.08, 24–36m -> 0.12,
  /// 36–60m -> 0.15. Boundary months belong to the higher bucket.
  static double cvrThresholdForAge(int childAgeMonths) {
    if (childAgeMonths < 24) return cvrThreshold12to24;
    if (childAgeMonths < 36) return cvrThreshold24to36;
    return cvrThreshold36to60;
  }

  static String _explanationFor(RiskLevel level) {
    return switch (level) {
      RiskLevel.green => 'इस बच्चे का भाषा विकास उम्र के अनुसार है।',
      RiskLevel.yellow =>
        'एक बायोमार्कर चिंता का संकेत देता है। 3 महीने में दोबारा स्क्रीनिंग की सलाह दी जाती है।',
      RiskLevel.red =>
        'इस बच्चे के लिए शीघ्र DEIC मूल्यांकन की सलाह दी जाती है।',
    };
  }
}
