import 'package:earlyecho/data/models/biomarker_result.dart';
import 'package:earlyecho/data/models/session_features.dart';
import 'package:earlyecho/domain/scoring_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('risk classification', () {
    test('all-normal biomarkers produce GREEN', () {
      final result = ScoringEngine.score(
        const SessionFeatures(
          vttlMs: 850,
          pfvStd: 22.5,
          cvrRatio: 0.18,
          childAgeMonths: 40,
        ),
      );

      expect(result.riskLevel, RiskLevel.green);
      expect(result.riskLabel, 'GREEN');
      expect(result.flagCount, 0);
      expect(result.incomplete, isFalse);
      expect(result.hindiExplanation, isNotEmpty);
    });

    test('a single flagged biomarker produces YELLOW', () {
      final result = ScoringEngine.score(
        const SessionFeatures(
          vttlMs: 1200,
          pfvStd: 18.2,
          cvrRatio: 0.20,
          childAgeMonths: 40,
        ),
      );

      expect(result.riskLevel, RiskLevel.yellow);
      expect(result.vttlFlagged, isTrue);
      expect(result.pfvFlagged, isFalse);
      expect(result.cvrFlagged, isFalse);
    });

    test('two flagged biomarkers produce RED', () {
      final result = ScoringEngine.score(
        const SessionFeatures(
          vttlMs: 1500,
          pfvStd: 20,
          cvrRatio: 0.06,
          childAgeMonths: 28,
        ),
      );

      expect(result.riskLevel, RiskLevel.red);
      expect(result.flagCount, 2);
    });
  });

  group('biomarker thresholds', () {
    test('VTTL flags strictly above 1000 ms', () {
      final atThreshold = ScoringEngine.score(
        const SessionFeatures(
          vttlMs: 1000,
          pfvStd: 20,
          cvrRatio: 0.20,
          childAgeMonths: 28,
        ),
      );
      expect(atThreshold.vttlFlagged, isFalse);

      final above = ScoringEngine.score(
        const SessionFeatures(
          vttlMs: 1001,
          pfvStd: 20,
          cvrRatio: 0.20,
          childAgeMonths: 28,
        ),
      );
      expect(above.vttlFlagged, isTrue);
    });

    test('PFV is only evaluated for children aged 36 months and above', () {
      final under36 = ScoringEngine.score(
        const SessionFeatures(
          vttlMs: 500,
          pfvStd: 5,
          cvrRatio: 0.20,
          childAgeMonths: 30,
        ),
      );
      expect(under36.pfvFlagged, isFalse);
      expect(under36.riskLevel, RiskLevel.green);

      final over36 = ScoringEngine.score(
        const SessionFeatures(
          vttlMs: 500,
          pfvStd: 5,
          cvrRatio: 0.20,
          childAgeMonths: 36,
        ),
      );
      expect(over36.pfvFlagged, isTrue);
    });

    test('CVR uses age-bucketed thresholds', () {
      // 12–24m bucket: minimum 0.08
      expect(
        ScoringEngine.score(
          const SessionFeatures(
            vttlMs: 500,
            pfvStd: 20,
            cvrRatio: 0.07,
            childAgeMonths: 18,
          ),
        ).cvrFlagged,
        isTrue,
      );
      expect(
        ScoringEngine.score(
          const SessionFeatures(
            vttlMs: 500,
            pfvStd: 20,
            cvrRatio: 0.10,
            childAgeMonths: 18,
          ),
        ).cvrFlagged,
        isFalse,
      );

      // 24–36m bucket: minimum 0.12
      expect(
        ScoringEngine.score(
          const SessionFeatures(
            vttlMs: 500,
            pfvStd: 20,
            cvrRatio: 0.10,
            childAgeMonths: 24,
          ),
        ).cvrFlagged,
        isTrue,
      );

      // 36–60m bucket: minimum 0.15
      expect(
        ScoringEngine.score(
          const SessionFeatures(
            vttlMs: 500,
            pfvStd: 20,
            cvrRatio: 0.13,
            childAgeMonths: 36,
          ),
        ).cvrFlagged,
        isTrue,
      );
      expect(
        ScoringEngine.score(
          const SessionFeatures(
            vttlMs: 500,
            pfvStd: 20,
            cvrRatio: 0.16,
            childAgeMonths: 48,
          ),
        ).cvrFlagged,
        isFalse,
      );
    });

    test('zero vocalization is always flagged', () {
      final result = ScoringEngine.score(
        const SessionFeatures(
          vttlMs: 500,
          pfvStd: 20,
          cvrRatio: 0,
          childAgeMonths: 28,
        ),
      );
      expect(result.cvrFlagged, isTrue);
    });
  });

  group('incomplete analysis', () {
    test('incomplete sessions never produce a definitive result', () {
      final result = ScoringEngine.score(
        const SessionFeatures(
          vttlMs: 0,
          pfvStd: 0,
          cvrRatio: 0,
          childAgeMonths: 24,
          analysisStatus: 'INCOMPLETE',
          qualityReasons: ['too quiet'],
        ),
      );

      expect(result.incomplete, isTrue);
      expect(result.riskLevel, RiskLevel.yellow);
      expect(result.flagCount, 0);
      expect(result.qualityReasons, ['too quiet']);
    });
  });

  group('SessionFeatures.fromChannelMap', () {
    test('parses the Kotlin method-channel response', () {
      final features = SessionFeatures.fromChannelMap({
        'vttl_ms': 850.5,
        'pfv_std': 22.3,
        'cvr_ratio': 0.18,
        'child_age_months': 28,
        'analysis_status': 'COMPLETE',
        'quality_reasons': <String>[],
      });

      expect(features.vttlMs, 850.5);
      expect(features.pfvStd, 22.3);
      expect(features.cvrRatio, 0.18);
      expect(features.childAgeMonths, 28);
      expect(features.isComplete, isTrue);
    });
  });
}
