/// Numeric feature vector returned by the Kotlin native audio pipeline.
///
/// Contains only low-dimensional acoustic measurements — never audio,
/// never spectrograms. Mirrors the Method Channel response contract.
class SessionFeatures {
  const SessionFeatures({
    required this.vttlMs,
    required this.pfvStd,
    required this.cvrRatio,
    required this.childAgeMonths,
    this.analysisStatus = 'COMPLETE',
    this.qualityReasons = const [],
  });

  /// Vocal Turn-Taking Latency: median adult→child silence gap in ms.
  final double vttlMs;

  /// Prosodic F0 Variance: standard deviation of pitch in semitones.
  final double pfvStd;

  /// Child Vocalization Ratio: child voiced time / total session time.
  final double cvrRatio;

  final int childAgeMonths;

  /// Pipeline status, e.g. `COMPLETE` or `INCOMPLETE`.
  final String analysisStatus;

  final List<String> qualityReasons;

  bool get isComplete => analysisStatus == 'COMPLETE';

  /// Parses the map returned over the `com.earlyecho/audio_pipeline`
  /// Method Channel by the Kotlin pipeline.
  factory SessionFeatures.fromChannelMap(Map<dynamic, dynamic> map) {
    return SessionFeatures(
      vttlMs: (map['vttl_ms'] as num?)?.toDouble() ?? 0,
      pfvStd: (map['pfv_std'] as num?)?.toDouble() ?? 0,
      cvrRatio: (map['cvr_ratio'] as num?)?.toDouble() ?? 0,
      childAgeMonths: (map['child_age_months'] as num?)?.toInt() ?? 0,
      analysisStatus: map['analysis_status'] as String? ?? 'INCOMPLETE',
      qualityReasons:
          (map['quality_reasons'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}
