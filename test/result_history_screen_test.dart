import 'package:earlyecho/core/theme.dart';
import 'package:earlyecho/data/local/database_helper.dart';
import 'package:earlyecho/data/repositories/session_repository.dart';
import 'package:earlyecho/presentation/providers/sync_provider.dart';
import 'package:earlyecho/presentation/screens/history/result_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets('result history screen renders an empty persisted history', (
    tester,
  ) async {
    final helper = DatabaseHelper(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: inMemoryDatabasePath,
    );
    addTearDown(helper.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionRepositoryProvider.overrideWithValue(
            SessionRepository(helper: helper),
          ),
        ],
        child: MaterialApp(
          theme: EarlyEchoTheme.lightTheme,
          home: const ResultHistoryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('पुरानी जाँचें'), findsOneWidget);
    expect(find.textContaining('जोखिम श्रेणी'), findsOneWidget);
    expect(find.textContaining('ऑडियो नहीं'), findsOneWidget);
  });
}
