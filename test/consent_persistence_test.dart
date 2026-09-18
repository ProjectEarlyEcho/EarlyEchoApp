import 'package:earlyecho/core/theme.dart';
import 'package:earlyecho/data/local/database_helper.dart';
import 'package:earlyecho/data/models/child_profile.dart';
import 'package:earlyecho/data/repositories/session_repository.dart';
import 'package:earlyecho/presentation/providers/session_provider.dart';
import 'package:earlyecho/presentation/providers/sync_provider.dart';
import 'package:earlyecho/presentation/screens/consent/consent_screen.dart';
import 'package:earlyecho/presentation/screens/elicitation/elicitation_screen.dart';
import 'package:earlyecho/services/consent_audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'session_repository_test.dart' show buildSession;

class _FakeConsentAudioPlayer implements ConsentAudioPlayer {
  @override
  Future<void> play() async {}

  @override
  Future<void> stop() async {}
}

void main() {
  late DatabaseHelper helper;
  late SessionRepository repository;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    helper = DatabaseHelper(
      // The no-isolate factory keeps SQLite futures inside the fake-async
      // zone so they resolve during tester.pump in widget tests.
      factory: databaseFactoryFfiNoIsolate,
      databasePath: inMemoryDatabasePath,
    );
    await helper.database;
    repository = SessionRepository(helper: helper);
  });

  tearDown(() => helper.close());

  test('a consent log persists with a null session link', () async {
    final consentedAt = DateTime.utc(2026, 9, 18, 9, 55);
    await repository.logConsent(
      ConsentLog(
        id: 'c-1',
        sessionId: null,
        anganwadiId: 'IN-MP-042',
        workerName: 'सीमा',
        consentedAt: consentedAt,
      ),
    );

    final db = await helper.database;
    final rows = await db.query(DatabaseHelper.tableConsentLogs);
    expect(rows, hasLength(1));
    expect(rows.single['session_id'], isNull);
    expect(rows.single['anganwadi_id'], 'IN-MP-042');
    expect(rows.single['worker_name'], 'सीमा');
    expect(rows.single['consented_at'], consentedAt.toIso8601String());
    expect(rows.single['synced'], 0);
  });

  test('attachConsentLogToSession backfills the session link', () async {
    await repository.logConsent(
      ConsentLog(
        id: 'c-1',
        sessionId: null,
        consentedAt: DateTime.utc(2026, 9, 18),
      ),
    );
    expect(await repository.getConsentLogsForSession('s-1'), isEmpty);

    await repository.saveSession(buildSession(id: 's-1'));
    await repository.attachConsentLogToSession('c-1', 's-1');

    final logs = await repository.getConsentLogsForSession('s-1');
    expect(logs, hasLength(1));
    expect(logs.single.id, 'c-1');
    expect(logs.single.sessionId, 's-1');
  });

  testWidgets('confirming on the consent screen writes a consent_logs row', (
    tester,
  ) async {
    const profile = ChildProfile(
      childAgeMonths: 30,
      anganwadiId: 'IN-MP-042',
      stateCode: 'Madhya Pradesh',
      districtCode: 'Indore',
      workerName: 'सीमा',
    );

    final router = GoRouter(
      initialLocation: '/consent',
      routes: [
        GoRoute(path: '/consent', builder: (_, _) => const ConsentScreen()),
        GoRoute(
          path: '/elicitation',
          builder: (_, _) => const ElicitationScreen(),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          consentAudioPlayerProvider.overrideWithValue(
            _FakeConsentAudioPlayer(),
          ),
          sessionRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(
          theme: EarlyEchoTheme.lightTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    container.read(sessionProvider.notifier).setChildProfile(profile);

    await tester.tap(find.text('सहमति का ऑडियो सुनाएँ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('माता-पिता ने सहमति दी'));
    await tester.pumpAndSettle();

    final db = await helper.database;
    final rows = await db.query(DatabaseHelper.tableConsentLogs);
    expect(rows, hasLength(1));
    expect(rows.single['session_id'], isNull);
    expect(rows.single['anganwadi_id'], 'IN-MP-042');
    expect(rows.single['worker_name'], 'सीमा');
    expect(DateTime.parse(rows.single['consented_at'] as String), isNotNull);

    final session = container.read(sessionProvider);
    expect(session.consentLogId, rows.single['id']);
  });
}
