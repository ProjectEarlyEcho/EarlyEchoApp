import 'package:earlyecho/core/theme.dart';
import 'package:earlyecho/data/local/database_helper.dart';
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

/// `just_audio` needs a platform channel widget tests do not have, so the
/// screen always talks to this fake through [consentAudioPlayerProvider].
class FakeConsentAudioPlayer implements ConsentAudioPlayer {
  var playCount = 0;
  var shouldFail = false;

  @override
  Future<void> play() async {
    playCount++;
    if (shouldFail) throw StateError('playback unavailable');
  }

  @override
  Future<void> stop() async {}
}

void main() {
  late DatabaseHelper helper;
  late SessionRepository repository;
  late FakeConsentAudioPlayer audio;

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
    audio = FakeConsentAudioPlayer();
  });

  tearDown(() => helper.close());

  Widget buildApp() {
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
    return ProviderScope(
      overrides: [
        consentAudioPlayerProvider.overrideWithValue(audio),
        sessionRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp.router(
        theme: EarlyEchoTheme.lightTheme,
        routerConfig: router,
      ),
    );
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

  FilledButton confirmButton(WidgetTester tester) =>
      tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'माता-पिता ने सहमति दी'),
      );

  testWidgets('renders the Hindi consent step with the gate closed', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('सहमति'), findsOneWidget);
    expect(find.text('अभिभावक की सहमति'), findsOneWidget);
    expect(find.text('सहमति का ऑडियो सुनाएँ'), findsOneWidget);
    expect(confirmButton(tester).onPressed, isNull);
  });

  testWidgets('navigation stays blocked until consent is confirmed', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // The confirm affordance is disabled — tapping it cannot advance.
    await tester.tap(find.text('माता-पिता ने सहमति दी'));
    await tester.pumpAndSettle();
    expect(find.byType(ElicitationScreen), findsNothing);
    expect(find.byType(ConsentScreen), findsOneWidget);
    expect(audio.playCount, 0);

    // After the consent audio plays once, confirm unlocks and advances.
    await tester.tap(find.text('सहमति का ऑडियो सुनाएँ'));
    await tester.pumpAndSettle();
    expect(audio.playCount, 1);
    expect(confirmButton(tester).onPressed, isNotNull);

    await tester.tap(find.text('माता-पिता ने सहमति दी'));
    await tester.pumpAndSettle();
    expect(find.byType(ElicitationScreen), findsOneWidget);
  });

  testWidgets('confirming records consentedAt and the log id on the session', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('सहमति का ऑडियो सुनाएँ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('माता-पिता ने सहमति दी'));
    await tester.pumpAndSettle();

    final session = containerOf(tester).read(sessionProvider);
    expect(session.consentedAt, isNotNull);
    expect(session.consentLogId, isNotNull);
  });

  testWidgets('a playback failure shows a Hindi fallback and keeps the gate', (
    tester,
  ) async {
    audio.shouldFail = true;
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('सहमति का ऑडियो सुनाएँ'));
    await tester.pumpAndSettle();

    expect(find.textContaining('ऑडियो नहीं चल पाया'), findsOneWidget);
    expect(confirmButton(tester).onPressed, isNull);
  });
}
