import 'package:earlyecho/core/routes.dart';
import 'package:earlyecho/core/theme.dart';
import 'package:earlyecho/data/local/database_helper.dart';
import 'package:earlyecho/data/repositories/session_repository.dart';
import 'package:earlyecho/presentation/providers/sync_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'session_repository_test.dart' show buildSession;

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets('history deep links are resolved against the active owner', (
    tester,
  ) async {
    final helper = DatabaseHelper(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: inMemoryDatabasePath,
    );
    addTearDown(helper.close);
    final owner = StateProvider<String?>((ref) => 'owner-a');
    final repository = SessionRepository(helper: helper, ownerId: 'owner-a');
    await repository.saveSession(buildSession(id: 'private-screening'));
    final container = ProviderContainer(
      overrides: [
        sessionRepositoryProvider.overrideWith(
          (ref) => SessionRepository(helper: helper, ownerId: ref.watch(owner)),
        ),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: '/history/private-screening',
      routes: appRoutes,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: EarlyEchoTheme.lightTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1841 ms'), findsOneWidget);
    for (final otherOwner in ['owner-b', null]) {
      container.read(owner.notifier).state = otherOwner;
      await tester.pumpAndSettle();
      expect(find.text('1841 ms'), findsNothing);
      expect(
        find.text('Screening result is not available for this account.'),
        findsOneWidget,
      );
    }
    container.read(owner.notifier).state = 'owner-a';
    await tester.pumpAndSettle();
    expect(find.text('1841 ms'), findsOneWidget);
    router.go('/history/missing-screening');
    await tester.pumpAndSettle();
    expect(find.text('1841 ms'), findsNothing);
    expect(
      find.text('Screening result is not available for this account.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
