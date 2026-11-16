import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:earlyecho/data/local/database_helper.dart';
import 'package:earlyecho/data/repositories/session_repository.dart';
import 'package:earlyecho/data/repositories/sync_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'session_repository_test.dart' show buildSession;
import 'support/supabase_http_fixture.dart';

void main() {
  const screeningId = '30000000-0000-0000-0000-000000000001';
  const consentId = '40000000-0000-0000-0000-000000000001';
  late DatabaseHelper helper;
  late SessionRepository sessions;
  late SupabaseHttpFixture http;
  late SyncRepository sync;
  late Future<void> Function(HttpRequest) handler;
  final requests = <Map<String, dynamic>>[];

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    requests.clear();
    helper = DatabaseHelper(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    sessions = SessionRepository(helper: helper, ownerId: ownerA);
    http = await SupabaseHttpFixture.start((request) async {
      final body =
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>;
      requests.add({'path': request.uri.path, 'body': body});
      expect(request.method, 'POST');
      expect(
        request.headers.value('authorization'),
        'Bearer ${SupabaseHttpFixture.tokenFor(ownerA)}',
      );
      await handler(request);
    });
    await http.signIn(ownerA);
    sync = SyncRepository(
      sessions: sessions,
      uploader: SupabaseScreeningUploader(http.client),
      currentOwnerId: () => http.client.auth.currentUser?.id,
    );
    await sessions.logConsent(
      ConsentLog(
        id: consentId,
        sessionId: null,
        anganwadiId: 'AW-001',
        consentedAt: DateTime.utc(2026),
      ),
    );
    await sessions.saveSession(
      buildSession(id: screeningId),
      consentLogId: consentId,
    );
  });
  tearDown(() async {
    await http.close();
    await helper.close();
  });

  test(
    'SQLite queue sends exact RPC contracts and retries only failed consent',
    () async {
      var failConsent = true;
      handler = (request) async {
        if (request.uri.path.endsWith('/sync_consent_log') && failConsent) {
          // A denied consent is not an acknowledged screening failure.
          await SupabaseHttpFixture.respond(request, {
            'code': '42501',
            'message': 'consent rejected',
          }, status: 403);
        } else {
          await SupabaseHttpFixture.respond(
            request,
            failConsent ? 'inserted' : 'replayed',
          );
        }
      };
      final first = await sync.syncPending();
      expect(first.uploaded, 1);
      expect(first.consentFailed, 1);
      expect(first.allSynced, isFalse);
      expect(requests.first['path'], '/rest/v1/rpc/sync_screening');
      final screening = (requests.first['body'] as Map)['p_screening'] as Map;
      expect(screening['created_by'], ownerA);
      expect(screening['id'], screeningId);
      expect(screening.keys, isNot(contains('child_name')));
      expect(screening.keys, isNot(contains('worker_name')));
      expect(screening.keys, isNot(contains('decision_trace')));
      final consent = (requests[1]['body'] as Map)['p_consent'] as Map;
      expect(consent['created_by'], ownerA);
      expect(consent['session_id'], screeningId);
      failConsent = false;
      expect((await sync.syncPending()).allSynced, isTrue);
      expect(requests, hasLength(3));
      expect(requests[2], requests[1]);
    },
  );

  test(
    'PostgREST PT409 is an explicit retained conflict, not success',
    () async {
      handler = (request) => SupabaseHttpFixture.respond(request, {
        'code': 'PT409',
        'message': 'Conflicting screening record',
      }, status: 409);
      final result = await sync.syncPending();
      expect(result.conflicts, 1);
      expect(result.failed, 1);
      expect(result.totalRemaining, 2);
      expect(requests, hasLength(1));
      expect(
        (await sessions.getSessionById(screeningId))!.syncedToCloud,
        isFalse,
      );
    },
  );

  test(
    'an unrecognized successful HTTP response cannot acknowledge SQLite',
    () async {
      handler = (request) => SupabaseHttpFixture.respond(request, {'ok': true});
      expect((await sync.syncPending()).failed, 1);
      expect(await sessions.getUnsyncedCount(), 1);
      expect(requests, hasLength(1));
    },
  );

  test('another signed-in owner cannot send an old owner payload', () async {
    await http.signIn(ownerB);
    final snapshot = (await sessions.getSessionById(screeningId))!;
    await expectLater(
      SupabaseScreeningUploader(http.client).upload(snapshot),
      throwsStateError,
    );
    expect((await sync.syncPending()).offline, isTrue);
    expect(requests, isEmpty);
  });

  test(
    'account change while HTTP is in flight cannot acknowledge the old queue',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      handler = (request) async {
        entered.complete();
        await release.future;
        await SupabaseHttpFixture.respond(request, 'inserted');
      };
      final result = sync.syncPending();
      await entered.future;
      await http.signIn(ownerB);
      release.complete();
      expect((await result).accountChanged, isTrue);
      expect(await sessions.getUnsyncedCount(), 1);
      expect(requests, hasLength(1));
    },
  );

  test(
    'a response deadline releases sync and a late commit is replayed safely',
    () async {
      final release = Completer<void>();
      final responded = Completer<void>();
      handler = (request) async {
        if (requests.length == 1) {
          await release.future;
          await SupabaseHttpFixture.respond(request, 'inserted');
          responded.complete();
        } else {
          await SupabaseHttpFixture.respond(request, 'replayed');
        }
      };
      sync = SyncRepository(
        sessions: sessions,
        uploader: SupabaseScreeningUploader(
          http.client,
          requestTimeout: const Duration(milliseconds: 200),
        ),
        currentOwnerId: () => http.client.auth.currentUser?.id,
      );
      final timedOut = await sync.syncPending();
      expect(timedOut.failed, 1);
      expect(timedOut.totalRemaining, 2);
      release.complete();
      await responded.future;
      expect(await sessions.getUnsyncedCount(), 1);
      expect((await sync.syncPending()).allSynced, isTrue);
      expect(requests, hasLength(3));
      expect(requests[0], requests[1]);
    },
  );
}
