import 'dart:async';

import 'package:earlyecho/data/models/child_profile.dart';
import 'package:earlyecho/presentation/providers/auth_provider.dart';
import 'package:earlyecho/presentation/providers/session_provider.dart';
import 'package:earlyecho/presentation/providers/sync_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/supabase_http_fixture.dart';

Future<void> waitUntil(
  bool Function() condition, {
  String Function()? diagnostic,
}) async {
  for (var i = 0; i < 200; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail(
    'Expected asynchronous state transition did not complete. ${diagnostic?.call() ?? ''}',
  );
}

void main() {
  const profile = ChildProfile(
    childName: 'Local child',
    childAgeMonths: 30,
    anganwadiId: 'centre-a',
    stateCode: 'MP',
    districtCode: 'Indore',
  );

  test(
    'identity switches immediately and stale profile cannot restore old capture or role',
    () async {
      final first = Completer<void>();
      final second = Completer<void>();
      final releaseA = Completer<void>();
      final releaseB = Completer<void>();
      final http = await SupabaseHttpFixture.start((request) async {
        final id = request.uri.queryParameters['id'];
        if (id == 'eq.$ownerA') {
          if (!first.isCompleted) first.complete();
          await releaseA.future;
          await SupabaseHttpFixture.respond(request, {
            'role': 'admin',
            'display_name': 'A',
          });
        } else {
          if (!second.isCompleted) second.complete();
          await releaseB.future;
          await SupabaseHttpFixture.respond(request, {
            'role': 'parent',
            'display_name': 'B',
          });
        }
      });
      addTearDown(http.close);
      await http.signIn(ownerA);
      final auth = AppAuthNotifier(http.client);
      final container = ProviderContainer(
        overrides: [appAuthProvider.overrideWith((ref) => auth)],
      );
      addTearDown(container.dispose);
      final a = container.read(sessionProvider.notifier);
      a.setChildProfile(profile);
      final oldRepository = container.read(sessionRepositoryProvider);
      final oldSync = container.read(syncProvider.notifier);
      await first.future;
      await http.signIn(ownerB);
      await second.future;
      expect(container.read(appAuthProvider).user?.id, ownerB);
      expect(container.read(appAuthProvider).role, isNull);
      expect(container.read(sessionProvider).childProfile, isNull);
      expect(container.read(sessionProvider).ownerId, ownerB);
      expect(container.read(sessionRepositoryProvider).ownerId, ownerB);
      expect(
        identical(oldRepository, container.read(sessionRepositoryProvider)),
        isFalse,
      );
      expect(
        identical(oldSync, container.read(syncProvider.notifier)),
        isFalse,
      );
      releaseB.complete();
      await waitUntil(() => !container.read(appAuthProvider).loading);
      releaseA.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(container.read(appAuthProvider).role, AppUserRole.parent);
      expect(container.read(appAuthProvider).displayName, 'B');
      expect(container.read(sessionProvider).childProfile, isNull);
    },
  );

  test(
    'same-owner profile refresh retains screening identity; sign-out clears capture',
    () async {
      final http = await SupabaseHttpFixture.start(
        (request) => SupabaseHttpFixture.respond(
          request,
          request.uri.path.endsWith('/logout')
              ? {}
              : {'role': 'clinician', 'display_name': 'A'},
        ),
      );
      addTearDown(http.close);
      await http.signIn(ownerA);
      final auth = AppAuthNotifier(http.client);
      final container = ProviderContainer(
        overrides: [appAuthProvider.overrideWith((ref) => auth)],
      );
      addTearDown(container.dispose);
      final session = container.read(sessionProvider.notifier);
      session.setChildProfile(profile);
      session.recordConsent(
        consentedAt: DateTime.utc(2026),
        consentLogId: 'stable',
      );
      await waitUntil(() => !container.read(appAuthProvider).loading);
      await http.signIn(ownerA);
      await waitUntil(() => !container.read(appAuthProvider).loading);
      expect(
        identical(session, container.read(sessionProvider.notifier)),
        isTrue,
      );
      expect(container.read(sessionProvider).sessionId, 'stable');
      await auth.signOut();
      expect(container.read(sessionProvider).ownerId, isNull);
      expect(container.read(sessionProvider).childProfile, isNull);
      expect(container.read(sessionProvider).sessionId, isNull);
      expect(container.read(sessionRepositoryProvider).ownerId, isNull);
      expect(container.read(appAuthProvider).loading, isFalse);
    },
  );

  test('late profile response is ignored after notifier disposal', () async {
    final pending = Completer<void>();
    final release = Completer<void>();
    final http = await SupabaseHttpFixture.start((request) async {
      if (!pending.isCompleted) pending.complete();
      await release.future;
      await SupabaseHttpFixture.respond(request, {'role': 'clinician'});
    });
    addTearDown(http.close);
    await http.signIn(ownerA);
    final auth = AppAuthNotifier(http.client);
    await pending.future;
    auth.dispose();
    release.complete();
    await Future<void>.delayed(const Duration(milliseconds: 10));
  });

  test(
    'temporary profile failure preserves the authenticated owner and capture',
    () async {
      var failProfile = false;
      final statuses = <int>[];
      final http = await SupabaseHttpFixture.start((request) {
        statuses.add(failProfile ? 500 : 200);
        return SupabaseHttpFixture.respond(
          request,
          failProfile
              ? {'code': 'PGRST000', 'message': 'Unavailable'}
              : {'role': 'clinician'},
          status: failProfile ? 500 : 200,
        );
      });
      addTearDown(http.close);
      await http.signIn(ownerA);
      final auth = AppAuthNotifier(http.client);
      final container = ProviderContainer(
        overrides: [appAuthProvider.overrideWith((ref) => auth)],
      );
      addTearDown(container.dispose);
      final session = container.read(sessionProvider.notifier);
      session.setChildProfile(profile);
      String diagnostic() =>
          'statuses=$statuses loading=${container.read(appAuthProvider).loading} owner=${container.read(appAuthProvider).user?.id} role=${container.read(appAuthProvider).role} error=${container.read(appAuthProvider).error}';
      await waitUntil(
        () => !container.read(appAuthProvider).loading,
        diagnostic: diagnostic,
      );
      failProfile = true;
      await http.signIn(ownerA);
      await waitUntil(
        () => container.read(appAuthProvider).error != null,
        diagnostic: diagnostic,
      );
      expect(container.read(appAuthProvider).loading, isFalse);
      expect(container.read(appAuthProvider).role, isNull);
      expect(container.read(sessionRepositoryProvider).ownerId, ownerA);
      expect(
        identical(session, container.read(sessionProvider.notifier)),
        isTrue,
      );
      expect(container.read(sessionProvider).childProfile, profile);
    },
  );

  test(
    'sign-in and duplicate auth events share the pending profile before role validation',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      var profileRequests = 0;
      var logouts = 0;
      final http = await SupabaseHttpFixture.start((request) async {
        if (request.uri.path.endsWith('/token')) {
          await SupabaseHttpFixture.respond(request, {
            'access_token': SupabaseHttpFixture.tokenFor(ownerA),
            'refresh_token': 'test-refresh',
            'expires_in': 3600,
            'token_type': 'bearer',
            'user': {'id': ownerA},
          });
        } else if (request.uri.path.endsWith('/logout')) {
          logouts++;
          await SupabaseHttpFixture.respond(request, {});
        } else {
          profileRequests++;
          if (!entered.isCompleted) entered.complete();
          await release.future;
          await SupabaseHttpFixture.respond(request, {'role': 'clinician'});
        }
      });
      addTearDown(http.close);
      final auth = AppAuthNotifier(http.client);
      final container = ProviderContainer(
        overrides: [appAuthProvider.overrideWith((ref) => auth)],
      );
      addTearDown(container.dispose);
      container.read(appAuthProvider);
      final signingIn = auth.signIn(
        email: 'worker@example.test',
        password: 'test-only',
        expectedRole: AppUserRole.careWorker,
      );
      await entered.future;
      await http.signIn(ownerA);
      release.complete();
      await signingIn;
      expect(profileRequests, 1);
      expect(logouts, 0);
      expect(container.read(appAuthProvider).signedIn, isTrue);
      expect(container.read(appAuthProvider).role, AppUserRole.careWorker);
      expect(container.read(appAuthProvider).loading, isFalse);
    },
  );

  test(
    'malformed sign-in response clears loading and permits another attempt',
    () async {
      final http = await SupabaseHttpFixture.start(
        (request) => SupabaseHttpFixture.respond(
          request,
          'invalid authentication response',
        ),
      );
      addTearDown(http.close);
      final auth = AppAuthNotifier(http.client);
      final container = ProviderContainer(
        overrides: [appAuthProvider.overrideWith((ref) => auth)],
      );
      addTearDown(container.dispose);
      container.read(appAuthProvider);
      for (var i = 0; i < 2; i++) {
        await auth.signIn(
          email: 'worker@example.test',
          password: 'test-only',
          expectedRole: AppUserRole.careWorker,
        );
        expect(container.read(appAuthProvider).loading, isFalse);
        expect(container.read(appAuthProvider).error, isNotNull);
        expect(container.read(appAuthProvider).signedIn, isFalse);
      }
    },
  );
}
