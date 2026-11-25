import 'dart:async';

import 'package:earlyecho/data/repositories/sync_repository.dart';
import 'package:earlyecho/presentation/providers/auth_provider.dart';
import 'package:earlyecho/presentation/providers/sync_provider.dart';
import 'package:earlyecho/presentation/screens/auth/login_screen.dart';
import 'package:earlyecho/presentation/screens/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TestAuthNotifier extends AppAuthNotifier {
  TestAuthNotifier() : super(null);

  @override
  Future<void> signIn({
    required String email,
    required String password,
    required AppUserRole expectedRole,
  }) async {
    state = AppAuthState(
      configured: true,
      user: User.fromJson({'id': 'worker-a'}),
      role: expectedRole,
    );
  }
}

class PendingSyncRepository extends SyncRepository {
  final pending = Completer<SyncResult>();
  @override
  Future<SyncResult> syncPending() => pending.future;
}

void main() {
  testWidgets('home authentication refresh tolerates queue failures', (
    tester,
  ) async {
    final repository = PendingSyncRepository();
    final auth = TestAuthNotifier();
    final container = ProviderContainer(
      overrides: [
        appAuthProvider.overrideWith((ref) => auth),
        syncRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await auth.signIn(
      email: 'parent@example.test',
      password: 'test-password',
      expectedRole: AppUserRole.parent,
    );
    await tester.pump();
    expect(container.read(syncProvider).isSyncing, isTrue);
    repository.pending.completeError(StateError('Storage unavailable'));
    await tester.pumpAndSettle();
    expect(container.read(syncProvider).isSyncing, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'successful login navigates before sync and tolerates a queue error',
    (tester) async {
      final repository = PendingSyncRepository();
      final container = ProviderContainer(
        overrides: [
          appAuthProvider.overrideWith((ref) => TestAuthNotifier()),
          syncRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('Signed in home')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Care worker'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'worker@example.test',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'test-password');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Signed in home'), findsOneWidget);
      expect(container.read(syncProvider).isSyncing, isTrue);
      repository.pending.completeError(StateError('Storage unavailable'));
      await tester.pump();
      expect(container.read(syncProvider).isSyncing, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
