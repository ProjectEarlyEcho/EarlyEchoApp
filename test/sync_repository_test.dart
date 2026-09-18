import 'package:earlyecho/data/local/database_helper.dart';
import 'package:earlyecho/data/models/biomarker_result.dart';
import 'package:earlyecho/data/models/session_model.dart';
import 'package:earlyecho/data/repositories/session_repository.dart';
import 'package:earlyecho/data/repositories/sync_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Hand-written fake upload port: records uploads and throws for session ids
/// listed in [failingIds], simulating a network/server failure.
class FakeScreeningUploader implements ScreeningUploader {
  final List<String> uploadedIds = [];
  final Set<String> failingIds;

  FakeScreeningUploader({Set<String>? failingIds})
    : failingIds = failingIds ?? {};

  @override
  Future<void> upload(SessionModel session) async {
    if (failingIds.contains(session.id)) {
      throw Exception('upload failed');
    }
    uploadedIds.add(session.id);
  }
}

class FakeConsentLogUploader implements ConsentLogUploader {
  final List<String> uploadedIds = [];

  @override
  Future<void> uploadConsentLog(ConsentLog log) async {
    uploadedIds.add(log.id);
  }
}

SessionModel buildSession(String id) {
  return SessionModel(
    id: id,
    anganwadiId: 'AW-001',
    stateCode: 'BR',
    districtCode: 'PAT',
    childAgeMonths: 30,
    sessionDate: DateTime.utc(2026, 9, 18, 10),
    riskLevel: RiskLevel.green,
    vttlMs: 1500,
    pfvStd: 1.8,
    cvrRatio: 0.5,
    vttlFlagged: false,
    pfvFlagged: false,
    cvrFlagged: false,
    audioSourceUsed: 'unprocessed',
  );
}

void main() {
  late DatabaseHelper helper;
  late SessionRepository sessions;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    helper = DatabaseHelper(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    sessions = SessionRepository(helper: helper);
    await helper.database;
  });

  tearDown(() async {
    await helper.close();
  });

  test('successful uploads mark sessions synced', () async {
    await sessions.saveSession(buildSession('s-1'));
    await sessions.saveSession(buildSession('s-2'));
    final uploader = FakeScreeningUploader();
    final repo = SyncRepository(uploader: uploader, sessions: sessions);

    final result = await repo.syncPending();

    expect(result.attempted, 2);
    expect(result.uploaded, 2);
    expect(result.failed, 0);
    expect(result.remaining, 0);
    expect(result.allSynced, isTrue);
    expect(uploader.uploadedIds, ['s-1', 's-2']);
    expect((await sessions.getSessionById('s-1'))!.syncedToCloud, isTrue);
    expect((await sessions.getSessionById('s-2'))!.syncedToCloud, isTrue);
  });

  test('failed uploads stay queued for retry', () async {
    await sessions.saveSession(buildSession('s-1'));
    await sessions.saveSession(buildSession('s-2'));
    final uploader = FakeScreeningUploader(failingIds: {'s-2'});
    final repo = SyncRepository(uploader: uploader, sessions: sessions);

    final result = await repo.syncPending();

    expect(result.uploaded, 1);
    expect(result.failed, 1);
    expect(result.remaining, 1);
    expect(result.allSynced, isFalse);
    expect((await sessions.getSessionById('s-1'))!.syncedToCloud, isTrue);
    expect((await sessions.getSessionById('s-2'))!.syncedToCloud, isFalse);

    // A retry with a healthy uploader drains the rest of the queue.
    final retry = SyncRepository(
      uploader: FakeScreeningUploader(),
      sessions: sessions,
    );
    final retryResult = await retry.syncPending();
    expect(retryResult.uploaded, 1);
    expect(retryResult.remaining, 0);
  });

  test('pendingCount reflects the unsynced queue depth', () async {
    final repo = SyncRepository(
      uploader: FakeScreeningUploader(),
      sessions: sessions,
    );

    expect(await repo.pendingCount(), 0);
    await sessions.saveSession(buildSession('s-1'));
    await sessions.saveSession(buildSession('s-2'));
    expect(await repo.pendingCount(), 2);
    await repo.syncPending();
    expect(await repo.pendingCount(), 0);
  });

  test('syncPending with no pending sessions is a no-op', () async {
    final uploader = FakeScreeningUploader();
    final repo = SyncRepository(uploader: uploader, sessions: sessions);

    final result = await repo.syncPending();

    expect(result.attempted, 0);
    expect(result.uploaded, 0);
    expect(result.allSynced, isTrue);
    expect(uploader.uploadedIds, isEmpty);
  });

  test('syncPending without an uploader reports offline', () async {
    await sessions.saveSession(buildSession('s-1'));
    // Supabase is not initialized in tests, so the default uploader lookup
    // yields null — the same state as a device with no credentials.
    final repo = SyncRepository(sessions: sessions);

    final result = await repo.syncPending();

    expect(result.offline, isTrue);
    expect(result.attempted, 0);
    expect(result.remaining, 1);
    expect((await sessions.getSessionById('s-1'))!.syncedToCloud, isFalse);
  });

  test('linked consent logs are uploaded and marked synced', () async {
    await sessions.saveSession(buildSession('s-1'));
    await sessions.logConsent(
      ConsentLog(
        id: 'c-1',
        sessionId: 's-1',
        consentedAt: DateTime.utc(2026, 9, 19),
      ),
    );
    final consentUploader = FakeConsentLogUploader();
    final repository = SyncRepository(
      uploader: FakeScreeningUploader(),
      consentUploader: consentUploader,
      sessions: sessions,
    );

    await repository.syncPending();

    expect(consentUploader.uploadedIds, ['c-1']);
    expect(await sessions.getUnsyncedConsentLogs(), isEmpty);
  });
}
