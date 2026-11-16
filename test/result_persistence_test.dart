import 'package:earlyecho/core/l10n/app_strings.dart';
import 'package:earlyecho/core/theme.dart';
import 'package:earlyecho/data/local/database_helper.dart';
import 'package:earlyecho/data/models/biomarker_result.dart';
import 'package:earlyecho/data/models/child_profile.dart';
import 'package:earlyecho/data/models/session_features.dart';
import 'package:earlyecho/data/models/session_model.dart';
import 'package:earlyecho/data/repositories/session_repository.dart';
import 'package:earlyecho/presentation/providers/locale_provider.dart';
import 'package:earlyecho/presentation/providers/session_provider.dart';
import 'package:earlyecho/presentation/providers/sync_provider.dart';
import 'package:earlyecho/presentation/screens/result/result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'session_repository_test.dart' show buildSession;

class _ControlledSessionRepository extends SessionRepository {
  _ControlledSessionRepository({required super.helper});

  bool saveUnavailable = false;
  bool queueUnavailable = false;
  final saves = <SessionModel>[];

  @override
  Future<void> saveSession(SessionModel session, {String? consentLogId}) async {
    saves.add(session);
    if (saveUnavailable) throw StateError('Storage unavailable.');
    await super.saveSession(session, consentLogId: consentLogId);
  }

  @override
  Future<List<SessionModel>> getUnsyncedSessions() async {
    if (queueUnavailable) throw StateError('Queue unavailable.');
    return super.getUnsyncedSessions();
  }
}

void main() {
  late DatabaseHelper helper;
  late _ControlledSessionRepository repository;
  late ProviderContainer container;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    helper = DatabaseHelper(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: inMemoryDatabasePath,
    );
    await helper.database;
    repository = _ControlledSessionRepository(helper: helper);
    container = ProviderContainer(
      overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
    );
    container
        .read(sessionProvider.notifier)
        .setChildProfile(
          const ChildProfile(
            childAgeMonths: 30,
            anganwadiId: 'centre',
            stateCode: 'MP',
            districtCode: 'Indore',
          ),
        );
    final time = DateTime.utc(2026, 11, 16);
    await repository.logConsent(
      ConsentLog(id: 'durable-identity', sessionId: null, consentedAt: time),
    );
    container
        .read(sessionProvider.notifier)
        .recordConsent(consentedAt: time, consentLogId: 'durable-identity');
  });
  tearDown(() async {
    container.dispose();
    await helper.close();
  });

  void analyze({bool incomplete = false}) {
    container
        .read(sessionProvider.notifier)
        .recordAnalysisResult(
          features: const SessionFeatures(
            vttlMs: 1450,
            pfvStd: 20,
            cvrRatio: .05,
            childAgeMonths: 30,
          ),
          result: BiomarkerResult(
            riskLevel: RiskLevel.red,
            vttlFlagged: true,
            pfvFlagged: false,
            cvrFlagged: true,
            hindiExplanation: 'Result',
            incomplete: incomplete,
          ),
          rawResponse: const {'audio_source_used': 'UNPROCESSED'},
        );
  }

  Widget screen() => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: EarlyEchoTheme.lightTheme,
      home: const ResultScreen(),
    ),
  );

  String text(String key) =>
      AppStrings.tr(key, container.read(appLocaleProvider));

  testWidgets('local save failure is visible and retry preserves the capture', (
    tester,
  ) async {
    analyze();
    repository.saveUnavailable = true;
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(find.text(text('result_save_error')), findsOneWidget);
    expect(find.text(text('result_saved_local')), findsNothing);
    expect(await repository.getAllSessions(), isEmpty);
    final original = repository.saves.single.toMap();
    repository.saveUnavailable = false;
    await tester.tap(find.text(text('result_retry_save')));
    await tester.pumpAndSettle();
    expect(find.text(text('result_save_error')), findsNothing);
    expect(find.text(text('result_saved_local')), findsOneWidget);
    expect(repository.saves, hasLength(2));
    expect(repository.saves.last.toMap(), original);
    expect((await repository.getAllSessions()).single.id, 'durable-identity');
    expect(
      await repository.getConsentLogsForSession('durable-identity'),
      hasLength(1),
    );
  });

  testWidgets(
    'local immutable conflict is visible and retry cannot overwrite',
    (tester) async {
      await repository.saveSession(buildSession(id: 'durable-identity'));
      final original = (await repository.getAllSessions()).single.toMap();
      analyze();
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(find.text(text('result_save_conflict')), findsOneWidget);
      expect(find.text(text('result_saved_local')), findsNothing);
      await tester.tap(find.text(text('result_retry_save')));
      await tester.pumpAndSettle();
      expect(find.text(text('result_save_conflict')), findsOneWidget);
      expect((await repository.getAllSessions()).single.toMap(), original);
      expect(repository.saves[1].toMap(), repository.saves[2].toMap());
      expect(
        await repository.getConsentLogsForSession('durable-identity'),
        isEmpty,
      );
    },
  );

  testWidgets('queue failure does not misreport a committed local result', (
    tester,
  ) async {
    analyze();
    repository.queueUnavailable = true;
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(find.text(text('result_saved_local')), findsOneWidget);
    expect(find.text(text('result_save_error')), findsNothing);
    expect(find.text(text('result_retry_save')), findsNothing);
    expect(repository.saves, hasLength(1));
    expect((await repository.getAllSessions()).single.syncedToCloud, isFalse);
    expect(
      (await repository.getConsentLogsForSession(
        'durable-identity',
      )).single.synced,
      isFalse,
    );
  });

  testWidgets(
    'result re-entry preserves one durable screening and its consent',
    (tester) async {
      analyze();
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      final first = (await repository.getAllSessions()).single;
      expect(first.id, 'durable-identity');
      expect(first.sessionDate, DateTime.utc(2026, 11, 16));
      await repository.markSynced(first);
      final consent = (await repository.getConsentLogsForSession(
        first.id,
      )).single;
      await repository.markConsentLogSynced(consent);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      final rows = await repository.getAllSessions();
      expect(rows, hasLength(1));
      expect(rows.single.id, first.id);
      expect(rows.single.syncedToCloud, isTrue);
      expect(
        (await repository.getConsentLogsForSession(first.id)).single.synced,
        isTrue,
      );
    },
  );

  testWidgets(
    'incomplete result leaves consent unlinked until completed retry',
    (tester) async {
      analyze(incomplete: true);
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(await repository.getAllSessions(), isEmpty);
      final db = await helper.database;
      expect(
        (await db.query(DatabaseHelper.tableConsentLogs)).single['session_id'],
        isNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      analyze();
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect((await repository.getAllSessions()).single.id, 'durable-identity');
      expect(
        await repository.getConsentLogsForSession('durable-identity'),
        hasLength(1),
      );
    },
  );
}
