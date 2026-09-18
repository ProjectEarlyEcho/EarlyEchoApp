/// Screening outcome classification.
///
/// - [green]: 0 biomarkers flagged, typical development.
/// - [yellow]: 1 biomarker flagged, rescreen in 3 months.
/// - [red]: 2+ biomarkers flagged, refer to DEIC.
enum RiskLevel { green, yellow, red }

/// Output of [ScoringEngine.score] for a single screening session.
class BiomarkerResult {
  const BiomarkerResult({
    required this.riskLevel,
    required this.vttlFlagged,
    required this.pfvFlagged,
    required this.cvrFlagged,
    required this.hindiExplanation,
    this.qualityReasons = const [],
    this.incomplete = false,
  });

  final RiskLevel riskLevel;
  final bool vttlFlagged;
  final bool pfvFlagged;
  final bool cvrFlagged;

  /// Plain-language explanation of the result shown to the worker.
  final String hindiExplanation;

  /// Reasons an analysis was degraded (e.g. too quiet, clipped audio).
  final List<String> qualityReasons;

  /// True when the native pipeline could not complete the analysis.
  /// An incomplete session never produces a definitive screening result.
  final bool incomplete;

  String get riskLabel => riskLevel.name.toUpperCase();

  int get flagCount =>
      (vttlFlagged ? 1 : 0) + (pfvFlagged ? 1 : 0) + (cvrFlagged ? 1 : 0);
}
