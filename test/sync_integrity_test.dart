import 'dart:async';
import 'dart:io';

import 'package:earlyecho/data/local/database_helper.dart';
import 'package:earlyecho/data/models/session_model.dart';
import 'package:earlyecho/data/repositories/session_repository.dart';
import 'package:earlyecho/data/repositories/sync_conflict.dart';
import 'package:earlyecho/data/repositories/sync_repository.dart';
import 'package:earlyecho/presentation/providers/sync_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'session_repository_test.dart' show buildSession;

class ControlledUploader implements ScreeningUploader, ConsentLogUploader {
  Future<void> Function(SessionModel)? onScreening;
  Future<void> Function(ConsentLog)? onConsent;
  final screenings = <SessionModel>[];
  final consents = <ConsentLog>[];

  @override
  Future<void> upload(SessionModel session) async {
    screenings.add(session);
    await onScreening?.call(session);
  }

  @override
  Future<void> uploadConsentLog(ConsentLog log) async {
    consents.add(log);
    await onConsent?.call(log);
  }
}

class RecoveringSessionRepository extends SessionRepository {
  RecoveringSessionRepository({required super.helper, required super.ownerId});
  bool unavailable = true;

  @override
  Future<List<SessionModel>> getUnsyncedSessions() async {
    if (unavailable) throw StateError('Storage temporarily unavailable.');
    return super.getUnsyncedSessions();
  }
}

void main() {
  late DatabaseHelper helper;
  late SessionRepository a;
  late SessionRepository b;
  late ControlledUploader uploader;
  String? activeOwner;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    helper = DatabaseHelper(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    a = SessionRepository(helper: helper, ownerId: 'worker-a');
    b = SessionRepository(helper: helper, ownerId: 'worker-b');
    activeOwner = 'worker-a';
    uploader = ControlledUploader();
  });
  tearDown(() => helper.close());

  SyncRepository sync([SessionRepository? sessions]) => SyncRepository(
    uploader: uploader,
    sessions: sessions ?? a,
    currentOwnerId: () => activeOwner,
  );

  Future<void> seed({
    String id = 'screening',
    String consentId = 'consent',
    SessionRepository? sessions,
  }) async {
    final repository = sessions ?? a;
    await repository.logConsent(
      ConsentLog(
        id: consentId,
        sessionId: null,
        consentedAt: DateTime.utc(2026, 9, 18),
      ),
    );
    await repository.saveSession(buildSession(id: id), consentLogId: consentId);
  }

  test(
    'concurrent local save replays preserve consent and acknowledgement',
    () async {
      await seed();
      await sync().syncPending();
      await Future.wait(
        List.generate(
          8,
          (_) => a.saveSession(
            buildSession(id: 'screening'),
            consentLogId: 'consent',
          ),
        ),
      );
      expect(await a.getAllSessions(), hasLength(1));
      expect((await a.getSessionById('screening'))!.syncedToCloud, isTrue);
      final consent = (await a.getConsentLogsForSession('screening')).single;
      expect(consent.synced, isTrue);
      expect(await sync().pendingCount(), 0);
    },
  );

  test(
    'atomic result and consent linkage rolls back a failed association',
    () async {
      await a.logConsent(
        ConsentLog(
          id: 'consent',
          sessionId: null,
          consentedAt: DateTime.utc(2026),
        ),
      );
      await expectLater(
        a.saveSession(buildSession(id: 'result'), consentLogId: 'missing'),
        throwsStateError,
      );
      expect(await a.getSessionById('result'), isNull);
      await a.saveSession(buildSession(id: 'result'), consentLogId: 'consent');
      await expectLater(
        a.saveSession(buildSession(id: 'other'), consentLogId: 'consent'),
        throwsA(isA<SyncConflictException>()),
      );
      expect(await a.getSessionById('other'), isNull);
      expect((await a.getConsentLogsForSession('result')).single.id, 'consent');
    },
  );

  test(
    'local owners cannot read, delete, acknowledge, replace, or link each other',
    () async {
      await seed();
      expect(await b.getAllSessions(), isEmpty);
      expect(await b.getSessionById('screening'), isNull);
      expect(await b.getUnsyncedCount(), 0);
      expect(await b.getUnsyncedConsentLogs(), isEmpty);
      expect(await b.getConsentLogsForSession('screening'), isEmpty);
      await b.deleteSession('screening');
      await expectLater(
        b.saveSession(buildSession(id: 'screening')),
        throwsA(isA<SyncConflictException>()),
      );
      await expectLater(
        b.markSynced((await a.getSessionById('screening'))!),
        throwsStateError,
      );
      await expectLater(
        b.markConsentLogSynced(
          (await a.getConsentLogsForSession('screening')).single,
        ),
        throwsStateError,
      );
      await b.saveSession(buildSession(id: 'b-result'));
      await expectLater(
        b.attachConsentLogToSession('consent', 'b-result'),
        throwsStateError,
      );
      await expectLater(
        b.logConsent(
          ConsentLog(
            id: 'forged-link',
            sessionId: 'screening',
            consentedAt: DateTime.utc(2026),
          ),
        ),
        throwsStateError,
      );
      expect((await a.getSessionById('screening'))!.syncedToCloud, isFalse);
      expect(
        (await a.getConsentLogsForSession('screening')).single.synced,
        isFalse,
      );
    },
  );

  test(
    'anonymous records stay offline and are never adopted on sign-in',
    () async {
      final offline = SessionRepository(helper: helper);
      await offline.saveSession(buildSession(id: 'offline'));
      final result = await sync(offline).syncPending();
      expect(result.offline, isTrue);
      expect(uploader.screenings, isEmpty);
      expect(await a.getAllSessions(), isEmpty);
      expect(await b.getAllSessions(), isEmpty);
      expect((await offline.getSessionById('offline'))!.ownerId, isNull);
    },
  );

  test(
    'stale acknowledgement cannot mark a recreated different payload synced',
    () async {
      await a.saveSession(buildSession(id: 'screening'));
      final snapshot = (await a.getSessionById('screening'))!;
      await a.deleteSession('screening');
      await a.saveSession(
        buildSession(id: 'screening', sessionDate: DateTime.utc(2026, 11)),
      );
      await expectLater(
        a.markSynced(snapshot),
        throwsA(isA<SyncConflictException>()),
      );
      expect(await a.getUnsyncedCount(), 1);
    },
  );

  test(
    'simultaneous sync callers share one flight and one consent upload',
    () async {
      await seed();
      final entered = Completer<void>();
      final release = Completer<void>();
      uploader.onScreening = (_) async {
        entered.complete();
        await release.future;
      };
      final repository = sync();
      final first = repository.syncPending();
      await entered.future;
      final second = repository.syncPending();
      expect(identical(first, second), isTrue);
      release.complete();
      expect((await first).allSynced, isTrue);
      await second;
      expect(uploader.screenings, hasLength(1));
      expect(uploader.consents, hasLength(1));
    },
  );

  test(
    'syncNow during a delayed upload drains newly saved screening and consent once',
    () async {
      await seed();
      final entered = Completer<void>();
      final release = Completer<void>();
      uploader.onScreening = (record) async {
        if (record.id == 'screening') {
          entered.complete();
          await release.future;
        }
      };
      final notifier = SyncNotifier(sync());
      addTearDown(notifier.dispose);
      final states = <SyncState>[];
      notifier.addListener(states.add);
      final first = notifier.syncNow();
      await entered.future;
      await seed(id: 'second', consentId: 'second-consent');
      final followers = List.generate(8, (_) => notifier.syncNow());
      release.complete();
      final results = await Future.wait([first, ...followers]);
      for (final result in results) {
        expect(result.allSynced, isTrue);
        expect(result.attempted, 2);
        expect(result.uploaded, 2);
        expect(result.consentUploaded, 2);
      }
      expect(uploader.screenings.map((row) => row.id), ['screening', 'second']);
      expect(uploader.consents.map((row) => row.id).toSet(), {
        'consent',
        'second-consent',
      });
      expect(uploader.consents, hasLength(2));
      expect(states.last.pendingCount, 0);
      expect(states.last.isSyncing, isFalse);
      expect(
        (await a.getAllSessions()).every((row) => row.syncedToCloud),
        isTrue,
      );
      expect(await a.getUnsyncedConsentLogs(), isEmpty);
    },
  );

  test(
    'requests arriving during a rescan are coalesced without losing later work',
    () async {
      await seed();
      final enteredA = Completer<void>();
      final enteredB = Completer<void>();
      final releaseA = Completer<void>();
      final releaseB = Completer<void>();
      uploader.onScreening = (record) async {
        if (record.id == 'screening') {
          enteredA.complete();
          await releaseA.future;
        } else if (record.id == 'second') {
          enteredB.complete();
          await releaseB.future;
        }
      };
      final repository = sync();
      final first = repository.syncPending();
      await enteredA.future;
      await seed(id: 'second', consentId: 'second-consent');
      final second = repository.syncPending();
      releaseA.complete();
      await enteredB.future;
      await seed(id: 'third', consentId: 'third-consent');
      final third = repository.syncPending();
      releaseB.complete();
      final results = await Future.wait([first, second, third]);
      expect(
        results.every(
          (result) =>
              result.allSynced &&
              result.uploaded == 3 &&
              result.consentUploaded == 3,
        ),
        isTrue,
      );
      expect(uploader.screenings.map((row) => row.id), [
        'screening',
        'second',
        'third',
      ]);
      expect(uploader.consents, hasLength(3));
    },
  );

  for (final conflict in [false, true]) {
    test(
      'rescan does not busy-retry ${conflict ? 'conflicting' : 'offline'} rows',
      () async {
        await seed();
        final entered = Completer<void>();
        final release = Completer<void>();
        uploader.onScreening = (record) async {
          if (record.id != 'screening') return;
          if (!entered.isCompleted) entered.complete();
          await release.future;
          if (conflict) {
            throw const SyncConflictException('screening', 'screening');
          }
          throw const SocketException('Connection unavailable.');
        };
        final repository = sync();
        final first = repository.syncPending();
        await entered.future;
        await seed(id: 'second', consentId: 'second-consent');
        final followers = List.generate(8, (_) => repository.syncPending());
        release.complete();
        final results = await Future.wait([
          first,
          ...followers,
        ]).timeout(const Duration(seconds: 5));
        expect(results.first.attempted, 2);
        expect(results.first.failed, 1);
        expect(results.first.conflicts, conflict ? 1 : 0);
        expect(results.first.totalRemaining, 2);
        expect(uploader.screenings.map((row) => row.id), [
          'screening',
          'second',
        ]);
        expect(uploader.consents.single.id, 'second-consent');
        // A later explicit flight can retry the retained row normally.
        uploader.onScreening = null;
        expect((await repository.syncPending()).allSynced, isTrue);
        expect(
          uploader.screenings.where((row) => row.id == 'screening'),
          hasLength(2),
        );
      },
    );
  }

  test(
    'new account drains independently and old epoch cannot resume on return',
    () async {
      await seed();
      await seed(id: 'b-result', consentId: 'b-consent', sessions: b);
      final entered = Completer<void>();
      final release = Completer<void>();
      uploader.onScreening = (record) async {
        if (record.id == 'screening') {
          entered.complete();
          await release.future;
        }
      };
      final oldEpoch = sync();
      final pendingA = oldEpoch.syncPending();
      await entered.future;
      await seed(id: 'second', consentId: 'second-consent');
      final followupA = oldEpoch.syncPending();
      activeOwner = 'worker-b';
      oldEpoch.dispose();
      // B's request completes while A's network response is still blocked.
      final resultB = await sync(b).syncPending();
      expect(resultB.allSynced, isTrue);
      expect((await b.getSessionById('b-result'))!.syncedToCloud, isTrue);
      expect(uploader.consents.single.ownerId, 'worker-b');
      activeOwner = 'worker-a';
      release.complete();
      expect((await pendingA).accountChanged, isTrue);
      expect((await followupA).accountChanged, isTrue);
      expect(await a.getUnsyncedCount(), 2);
      expect(await a.getUnsyncedConsentLogs(), hasLength(2));
      expect(uploader.screenings.map((row) => row.id), [
        'screening',
        'b-result',
      ]);
      uploader.onScreening = null;
      expect((await sync().syncPending()).allSynced, isTrue);
      expect(await b.getUnsyncedCount(), 0);
      expect(
        uploader.consents.where((row) => row.ownerId == 'worker-b'),
        hasLength(1),
      );
    },
  );

  test(
    'lost remote acknowledgement survives restart with identical payload',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'earlyecho-sync-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/queue.db';
      final disk = DatabaseHelper(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      addTearDown(disk.close);
      a = SessionRepository(helper: disk, ownerId: 'worker-a');
      await seed();
      uploader.onScreening = (_) async =>
          throw TimeoutException('response lost after commit');
      expect((await sync().syncPending()).failed, 1);
      expect(uploader.consents, isEmpty);
      await disk.close();
      final reopenedDatabase = DatabaseHelper(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      addTearDown(reopenedDatabase.close);
      // Reopen the actual database file, discarding the old connection and queue.
      final reopened = SessionRepository(
        helper: reopenedDatabase,
        ownerId: 'worker-a',
      );
      uploader.onScreening = null;
      expect((await sync(reopened).syncPending()).allSynced, isTrue);
      expect(uploader.screenings, hasLength(2));
      expect(
        uploader.screenings.first.toJson(),
        uploader.screenings.last.toJson(),
      );
      expect(uploader.consents, hasLength(1));
    },
  );

  test(
    'screening conflict preserves queue, skips its consent, and continues others',
    () async {
      await seed();
      await seed(id: 'other', consentId: 'other-consent');
      uploader.onScreening = (record) async {
        if (record.id == 'screening') {
          throw const SyncConflictException('screening', 'screening');
        }
      };
      final result = await sync().syncPending();
      expect(result.conflicts, 1);
      expect(result.failed, 1);
      expect(result.uploaded, 1);
      expect(result.consentUploaded, 1);
      expect(result.totalRemaining, 2);
      expect(uploader.consents.single.id, 'other-consent');
    },
  );

  test(
    'consent-only retry is visible and does not reupload accepted screening',
    () async {
      await seed();
      uploader.onConsent = (_) async =>
          throw const SyncConflictException('consent', 'consent');
      final repository = sync();
      final failed = await repository.syncPending();
      expect(failed.remaining, 0);
      expect(failed.consentFailed, 1);
      expect(failed.consentConflicts, 1);
      expect(failed.allSynced, isFalse);
      expect(await repository.pendingCount(), 1);
      uploader.onConsent = null;
      expect((await repository.syncPending()).allSynced, isTrue);
      expect(uploader.screenings, hasLength(1));
      expect(uploader.consents, hasLength(2));
    },
  );

  test(
    'account change during upload leaves old rows unacknowledged and stops drain',
    () async {
      await seed();
      await seed(id: 'second', consentId: 'second-consent');
      uploader.onScreening = (_) async {
        activeOwner = 'worker-b';
      };
      final result = await sync().syncPending();
      expect(result.accountChanged, isTrue);
      expect(result.uploaded, 0);
      expect(await a.getUnsyncedCount(), 2);
      expect(uploader.screenings, hasLength(1));
      expect(uploader.consents, isEmpty);
      expect((await sync(b).syncPending()).allSynced, isTrue);
      activeOwner = 'worker-a';
      uploader.onScreening = null;
      expect((await sync().syncPending()).allSynced, isTrue);
    },
  );

  test('disposed sync notifier ignores a late upload completion', () async {
    await seed();
    final entered = Completer<void>();
    final release = Completer<void>();
    uploader.onScreening = (_) async {
      entered.complete();
      await release.future;
    };
    final notifier = SyncNotifier(sync());
    final pending = notifier.syncNow();
    await entered.future;
    notifier.dispose();
    release.complete();
    expect((await pending).allSynced, isTrue);
  });

  test(
    'account change during consent leaves only that owner’s consent queued',
    () async {
      await seed();
      uploader.onConsent = (_) async {
        activeOwner = 'worker-b';
      };
      final result = await sync().syncPending();
      expect(result.accountChanged, isTrue);
      expect(result.remaining, 0);
      expect(result.consentRemaining, 1);
      expect(result.consentUploaded, 0);
      expect(await b.getUnsyncedConsentLogs(), isEmpty);
      activeOwner = 'worker-a';
      uploader.onConsent = null;
      expect((await sync().syncPending()).allSynced, isTrue);
      expect(uploader.screenings, hasLength(1));
      expect(uploader.consents, hasLength(2));
    },
  );

  test(
    'storage failure clears syncing and single-flight state for later retry',
    () async {
      final sessions = RecoveringSessionRepository(
        helper: helper,
        ownerId: 'worker-a',
      );
      final notifier = SyncNotifier(sync(sessions));
      addTearDown(notifier.dispose);
      final states = <SyncState>[];
      notifier.addListener(states.add);
      await expectLater(notifier.syncNow(), throwsStateError);
      expect(states.last.isSyncing, isFalse);
      sessions.unavailable = false;
      await seed();
      expect((await notifier.syncNow()).allSynced, isTrue);
      expect(states.last.isSyncing, isFalse);
    },
  );
}
