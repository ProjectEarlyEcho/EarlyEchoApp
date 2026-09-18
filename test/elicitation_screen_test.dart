import 'package:earlyecho/core/routes.dart';
import 'package:earlyecho/core/theme.dart';
import 'package:earlyecho/presentation/providers/session_provider.dart';
import 'package:earlyecho/presentation/screens/processing/processing_screen.dart';
import 'package:earlyecho/services/elicitation_audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'pipeline_test_helpers.dart';

/// `just_audio` has no platform channel in widget tests, so the screen
/// talks to this stub through [elicitationAudioPlayerProvider].
class _FakeElicitationAudioPlayer implements ElicitationAudioPlayer {
  final played = <String>[];
  bool failPlayback = false;

  @override
  Future<void> playFor(String protocolKey) async {
    if (failPlayback) throw StateError('playback unavailable');
    played.add(protocolKey);
  }

  @override
  Future<void> stop() async {}
}

void main() {
  late _FakeElicitationAudioPlayer audio;
  late ProviderContainer container;

  Widget buildApp() {
    installMockPipelineChannel();
    audio = _FakeElicitationAudioPlayer();
    container = ProviderContainer(
      overrides: [elicitationAudioPlayerProvider.overrideWithValue(audio)],
    );
    addTearDown(container.dispose);
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: EarlyEchoTheme.lightTheme,
        routerConfig: GoRouter(
          initialLocation: '/elicitation',
          routes: appRoutes,
        ),
      ),
    );
  }

  testWidgets('shows the first protocol card, idle until tapped', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('ध्वनि प्रेरण'), findsOneWidget);
    expect(find.text('प्रोटोकॉल 1/3'), findsOneWidget);
    expect(find.text('रैटल'), findsOneWidget);
    expect(find.text('इस बच्चे को रैटल की आवाज़ सुनाएँ'), findsOneWidget);
    // Explicit countdown: 60 seconds remaining before the worker starts.
    expect(find.text('60'), findsOneWidget);
    expect(find.text('सेकंड शेष'), findsOneWidget);
    expect(find.text('शुरू करने को तैयार'), findsOneWidget);
    expect(find.text('रिकॉर्डिंग शुरू करें'), findsOneWidget);
    expect(audio.played, isEmpty);
  });

  testWidgets('start plays the Hindi instruction and counts down visibly', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('रिकॉर्डिंग शुरू करें'));
    await tester.pump();

    expect(audio.played, ['rattle']);
    expect(find.text('रिकॉर्डिंग चल रही है'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('59'), findsOneWidget);
    expect(find.text('प्रोटोकॉल 1/3'), findsOneWidget);
  });

  testWidgets('audio failure still leaves the visual countdown working', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    audio.failPlayback = true;

    await tester.tap(find.text('रिकॉर्डिंग शुरू करें'));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('59'), findsOneWidget);
    expect(find.text('इस बच्चे को रैटल की आवाज़ सुनाएँ'), findsOneWidget);
  });

  testWidgets('walks all three protocols, then records timings and advances', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Protocol 1 — rattle, 60 s.
    await tester.tap(find.text('रिकॉर्डिंग शुरू करें'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 60));
    expect(find.text('खिलौना छुपाना'), findsOneWidget);
    expect(find.text('यह रहा! यह रहा खिलौना!'), findsOneWidget);
    expect(find.text('प्रोटोकॉल 2/3'), findsOneWidget);
    expect(find.text('80'), findsOneWidget);

    // Protocol 2 — toy hide/reveal, 80 s.
    await tester.tap(find.text('अगली गतिविधि शुरू करें'));
    await tester.pump();
    expect(audio.played, ['rattle', 'toy_hide']);
    await tester.pump(const Duration(seconds: 80));
    expect(find.text('अनुकरण'), findsOneWidget);
    expect(find.text('आ... आ... आ...'), findsOneWidget);
    expect(find.text('प्रोटोकॉल 3/3'), findsOneWidget);

    // Protocol 3 — imitation, 60 s → completes → /processing.
    await tester.tap(find.text('अगली गतिविधि शुरू करें'));
    await tester.pump();
    expect(audio.played, ['rattle', 'toy_hide', 'imitate']);
    await tester.pump(const Duration(seconds: 60));
    await tester.pump();
    // The processing screen shows an indeterminate spinner, so a timed
    // pump series is used instead of pumpAndSettle (which never settles
    // while it animates).
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(ProcessingScreen), findsOneWidget);
    expect(container.read(sessionProvider).protocolTimings, [
      {'protocol': 'rattle', 'start_ms': 0, 'end_ms': 60000},
      {'protocol': 'toy_hide', 'start_ms': 60000, 'end_ms': 140000},
      {'protocol': 'imitate', 'start_ms': 140000, 'end_ms': 200000},
    ]);
  });
}
