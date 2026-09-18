import 'package:earlyecho/data/models/biomarker_result.dart';
import 'package:earlyecho/data/models/deic_center.dart';
import 'package:earlyecho/data/models/session_model.dart';
import 'package:earlyecho/domain/referral_generator.dart';
import 'package:flutter_test/flutter_test.dart';

SessionModel buildSession() {
  return SessionModel(
    id: 'session-1',
    anganwadiId: 'IN-MP-042',
    childAgeMonths: 28,
    sessionDate: DateTime.utc(2026, 8, 15),
    riskLevel: RiskLevel.red,
    vttlMs: 1450,
    pfvStd: 18.1,
    cvrRatio: 0.065,
    vttlFlagged: true,
    pfvFlagged: false,
    cvrFlagged: true,
    audioSourceUsed: 'UNPROCESSED',
    stateCode: 'Madhya Pradesh',
    districtCode: 'Indore',
  );
}

void main() {
  group('ReferralGenerator.buildLetterText', () {
    test('includes session details and biomarker values', () {
      final letter = ReferralGenerator.buildLetterText(buildSession());

      expect(letter, contains('EarlyEcho'));
      expect(letter, contains('28 महीने'));
      expect(letter, contains('IN-MP-042'));
      expect(letter, contains('Madhya Pradesh'));
      expect(letter, contains('Indore'));
      expect(letter, contains('VTTL: 1450 ms'));
      expect(letter, contains('CVR: 0.065'));
      expect(letter, contains('PFV: 18.1 ST'));
    });

    test('marks flagged biomarkers and normal ones distinctly', () {
      final letter = ReferralGenerator.buildLetterText(buildSession());

      expect(letter, contains('VTTL: 1450 ms ⚠'));
      expect(letter, contains('CVR: 0.065 ⚠'));
      expect(letter, contains('PFV: 18.1 ST ✓'));
    });

    test('includes nearest DEIC contact when provided', () {
      const deic = DeicCenter(
        name: 'District Early Intervention Center, Indore',
        state: 'Madhya Pradesh',
        district: 'Indore',
        contact: 'deic.indore@health.mp.gov.in',
      );

      final letter = ReferralGenerator.buildLetterText(
        buildSession(),
        nearestDeic: deic,
      );

      expect(letter, contains('District Early Intervention Center, Indore'));
      expect(letter, contains('deic.indore@health.mp.gov.in'));
    });

    test('falls back to a directory note when no DEIC is known', () {
      final letter = ReferralGenerator.buildLetterText(buildSession());

      expect(letter, contains('स्थानीय DEIC निर्देशिका देखें'));
    });
  });

  group('DeicCenter.nearest', () {
    const centers = [
      DeicCenter(
        name: 'DEIC Bhopal',
        state: 'Madhya Pradesh',
        district: 'Bhopal',
      ),
      DeicCenter(
        name: 'DEIC Indore',
        state: 'Madhya Pradesh',
        district: 'Indore',
      ),
      DeicCenter(name: 'DEIC Pune', state: 'Maharashtra', district: 'Pune'),
    ];

    test('prefers a same-district center', () {
      final nearest = DeicCenter.nearest(
        centers,
        state: 'Madhya Pradesh',
        district: 'Indore',
      );
      expect(nearest?.name, 'DEIC Indore');
    });

    test('falls back to any center in the same state', () {
      final nearest = DeicCenter.nearest(
        centers,
        state: 'Madhya Pradesh',
        district: 'Ujjain',
      );
      expect(nearest?.state, 'Madhya Pradesh');
    });

    test('returns null when no center matches the state', () {
      final nearest = DeicCenter.nearest(
        centers,
        state: 'Rajasthan',
        district: 'Jaipur',
      );
      expect(nearest, isNull);
    });
  });
}
