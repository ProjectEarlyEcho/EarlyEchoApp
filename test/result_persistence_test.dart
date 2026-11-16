import 'package:earlyecho/core/theme.dart';
import 'package:earlyecho/data/local/database_helper.dart';
import 'package:earlyecho/data/models/biomarker_result.dart';
import 'package:earlyecho/data/models/child_profile.dart';
import 'package:earlyecho/data/models/session_features.dart';
import 'package:earlyecho/data/repositories/session_repository.dart';
import 'package:earlyecho/presentation/providers/session_provider.dart';
import 'package:earlyecho/presentation/providers/sync_provider.dart';
import 'package:earlyecho/presentation/screens/result/result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late DatabaseHelper helper;
  late SessionRepository repository;
  late ProviderContainer container;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    helper = DatabaseHelper(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: inMemoryDatabasePath,
    );
    await helper.database;
    repository = SessionRepository(helper: helper);
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
