import 'package:earlyecho/data/local/database_helper.dart';
import 'package:earlyecho/data/models/biomarker_result.dart';
import 'package:earlyecho/data/models/session_model.dart';
import 'package:earlyecho/data/repositories/session_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

SessionModel buildSession({
  required String id,
  DateTime? sessionDate,
  bool synced = false,
}) {
  return SessionModel(
    id: id,
    anganwadiId: 'AW-001',
    stateCode: 'BR',
    districtCode: 'PAT',
    workerName: 'Sunita Devi',
    childName: 'Aarav',
    childAgeMonths: 30,
    sessionDate: sessionDate ?? DateTime.utc(2026, 9, 18, 10),
    riskLevel: RiskLevel.yellow,
    vttlMs: 1840.5,
    pfvStd: 2.3,
    cvrRatio: 0.42,
    vttlFlagged: true,
    pfvFlagged: false,
    cvrFlagged: false,
    audioSourceUsed: 'unprocessed',
    syncedToCloud: synced,
    decisionTrace: const {'engine': 'test', 'flags': 1},
  );
}

void main() {
  late DatabaseHelper helper;
  late SessionRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    helper = DatabaseHelper(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    repository = SessionRepository(helper: helper);
    // Force the database open so each test starts from the v1 schema.
    await helper.database;
  });

  tearDown(() async {
    await helper.close();
  });

  test('saveSession then getSessionById round-trips all fields', () async {
    final session = buildSession(id: 's-1');
    await repository.saveSession(session);

    final loaded = await repository.getSessionById('s-1');
    expect(loaded, isNotNull);
    expect(loaded!.id, 's-1');
    expect(loaded.anganwadiId, 'AW-001');
    expect(loaded.stateCode, 'BR');
    expect(loaded.districtCode, 'PAT');
    expect(loaded.workerName, 'Sunita Devi');
    expect(loaded.childName, 'Aarav');
    expect(loaded.childAgeMonths, 30);
    expect(loaded.sessionDate, session.sessionDate);
    expect(loaded.riskLevel, RiskLevel.yellow);
    expect(loaded.vttlMs, 1840.5);
    expect(loaded.pfvStd, 2.3);
    expect(loaded.cvrRatio, 0.42);
    expect(loaded.vttlFlagged, isTrue);
    expect(loaded.pfvFlagged, isFalse);
    expect(loaded.cvrFlagged, isFalse);
    expect(loaded.audioSourceUsed, 'unprocessed');
    expect(loaded.syncedToCloud, isFalse);
    expect(loaded.decisionTrace, {'engine': 'test', 'flags': 1});
  });

  test('getSessionById returns null for an unknown id', () async {
    expect(await repository.getSessionById('missing'), isNull);
  });

  test('getAllSessions returns sessions newest first', () async {
    await repository.saveSession(
      buildSession(id: 'old', sessionDate: DateTime.utc(2026, 9, 1)),
    );
    await repository.saveSession(
      buildSession(id: 'new', sessionDate: DateTime.utc(2026, 9, 18)),
    );
    await repository.saveSession(
      buildSession(id: 'mid', sessionDate: DateTime.utc(2026, 9, 10)),
    );

    final ids = (await repository.getAllSessions()).map((s) => s.id).toList();
    expect(ids, ['new', 'mid', 'old']);
  });

  test('markSynced flips the synced flag and shrinks the queue', () async {
    await repository.saveSession(buildSession(id: 's-1'));
    await repository.saveSession(buildSession(id: 's-2'));

    expect(await repository.getUnsyncedCount(), 2);
    expect(
      (await repository.getUnsyncedSessions()).map((s) => s.id),
      containsAll(['s-1', 's-2']),
    );

    await repository.markSynced('s-1');

    expect(await repository.getUnsyncedCount(), 1);
    final remaining = await repository.getUnsyncedSessions();
    expect(remaining.single.id, 's-2');
    expect((await repository.getSessionById('s-1'))!.syncedToCloud, isTrue);
  });

  test('saveSession upserts on the same id', () async {
    await repository.saveSession(buildSession(id: 's-1'));
    await repository.saveSession(
      buildSession(id: 's-1', sessionDate: DateTime.utc(2026, 9, 19)),
    );

    final all = await repository.getAllSessions();
    expect(all, hasLength(1));
    expect(all.single.sessionDate, DateTime.utc(2026, 9, 19));
  });

  test('deleteSession removes the row and its consent logs', () async {
    await repository.saveSession(buildSession(id: 's-1'));
    await repository.logConsent(
      ConsentLog(
        id: 'c-1',
        sessionId: 's-1',
        anganwadiId: 'AW-001',
        workerName: 'Sunita Devi',
        consentedAt: DateTime.utc(2026, 9, 18, 9, 55),
      ),
    );

    await repository.deleteSession('s-1');

    expect(await repository.getSessionById('s-1'), isNull);
    expect(await repository.getAllSessions(), isEmpty);
    expect(await repository.getConsentLogsForSession('s-1'), isEmpty);
  });

  test('logConsent stores a timestamped audit entry', () async {
    await repository.saveSession(buildSession(id: 's-1'));
    final consentedAt = DateTime.utc(2026, 9, 18, 9, 55);
    await repository.logConsent(
      ConsentLog(
        id: 'c-1',
        sessionId: 's-1',
        anganwadiId: 'AW-001',
        workerName: 'Sunita Devi',
        consentedAt: consentedAt,
      ),
    );

    final logs = await repository.getConsentLogsForSession('s-1');
    expect(logs, hasLength(1));
    expect(logs.single.id, 'c-1');
    expect(logs.single.workerName, 'Sunita Devi');
    expect(logs.single.consentedAt, consentedAt);
    expect(logs.single.synced, isFalse);
  });
}
