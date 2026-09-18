import 'package:earlyecho/data/models/biomarker_result.dart';
import 'package:earlyecho/data/models/session_model.dart';
import 'package:flutter_test/flutter_test.dart';

SessionModel buildSession() {
  return SessionModel(
    id: 'session-1',
    anganwadiId: 'IN-MP-042',
    workerName: 'Asha',
    childAgeMonths: 28,
    sessionDate: DateTime.utc(2026, 8, 15, 10, 30),
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
    decisionTrace: const {
      'vad': {'frames_kept': 10400},
    },
  );
}

void main() {
  group('SessionModel SQLite mapping', () {
    test('toMap/fromMap round-trips all fields', () {
      final session = buildSession();
      final restored = SessionModel.fromMap(session.toMap());

      expect(restored.id, session.id);
      expect(restored.anganwadiId, session.anganwadiId);
      expect(restored.workerName, session.workerName);
      expect(restored.childAgeMonths, session.childAgeMonths);
      expect(restored.sessionDate, session.sessionDate);
      expect(restored.riskLevel, session.riskLevel);
      expect(restored.vttlMs, session.vttlMs);
      expect(restored.pfvStd, session.pfvStd);
      expect(restored.cvrRatio, session.cvrRatio);
      expect(restored.vttlFlagged, isTrue);
      expect(restored.pfvFlagged, isFalse);
      expect(restored.cvrFlagged, isTrue);
      expect(restored.audioSourceUsed, 'UNPROCESSED');
      expect(restored.syncedToCloud, isFalse);
      expect(restored.stateCode, 'Madhya Pradesh');
      expect(restored.districtCode, 'Indore');
      expect(restored.decisionTrace['vad']['frames_kept'], 10400);
    });

    test('booleans map to SQLite integers', () {
      final map = buildSession().toMap();

      expect(map['vttl_flagged'], 1);
      expect(map['pfv_flagged'], 0);
      expect(map['synced'], 0);
    });

    test('decision trace serializes as a JSON string', () {
      final map = buildSession().toMap();

      expect(map['decision_trace'], isA<String>());
      expect(map['decision_trace'], contains('frames_kept'));
    });

    test('empty or missing decision trace decodes to an empty map', () {
      final map = buildSession().toMap()..['decision_trace'] = '';
      expect(SessionModel.fromMap(map).decisionTrace, isEmpty);

      map['decision_trace'] = null;
      expect(SessionModel.fromMap(map).decisionTrace, isEmpty);
    });
  });

  group('SessionModel Supabase JSON', () {
    test('toJson emits snake_case keys and no local-only fields', () {
      final json = buildSession().toJson();

      expect(json['anganwadi_id'], 'IN-MP-042');
      expect(json['child_age_months'], 28);
      expect(json['risk_level'], 'red');
      expect(json['vttl_flagged'], isTrue);
      expect(json['session_date'], '2026-08-15T10:30:00.000Z');
      expect(json.containsKey('synced'), isFalse);
      expect(json.containsKey('decision_trace'), isFalse);
      expect(json.containsKey('child_name'), isFalse);
    });
  });
}
