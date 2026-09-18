import 'dart:io';

import 'package:earlyecho/core/routes.dart';
import 'package:earlyecho/core/theme.dart';
import 'package:earlyecho/data/models/child_profile.dart';
import 'package:earlyecho/domain/milestone_engine.dart';
import 'package:earlyecho/presentation/providers/session_provider.dart';
import 'package:earlyecho/presentation/screens/consent/consent_screen.dart';
import 'package:earlyecho/presentation/screens/questionnaire/questionnaire_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  /// Hermetic loader: parses the real bundled JSON straight from disk.
  Future<List<MilestoneQuestion>> testLoader() async {
    return MilestoneEngine.parseQuestions(
      File('assets/data/milestones_hi.json').readAsStringSync(),
    );
  }

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        milestoneQuestionsLoaderProvider.overrideWithValue(testLoader),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Widget buildApp(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: EarlyEchoTheme.lightTheme,
        routerConfig: GoRouter(
          initialLocation: '/questionnaire',
          routes: appRoutes,
        ),
      ),
    );
  }

  const profile30 = ChildProfile(
    childAgeMonths: 30,
    anganwadiId: 'IN-MP-042',
    stateCode: 'Madhya Pradesh',
    districtCode: 'Indore',
    workerName: 'सीमा',
  );

  testWidgets('questions load from the bundled asset and render', (
    tester,
  ) async {
    final container = makeContainer();
    await tester.pumpWidget(buildApp(container));
    await tester.pumpAndSettle();

    expect(find.text('0/16 उत्तर दिए गए'), findsOneWidget);
    expect(
      find.text('क्या बच्चा किसी चीज़ को पकड़कर खड़ा होता है?'),
      findsOneWidget,
    );
    expect(find.text('हाँ'), findsWidgets);
    expect(find.text('नहीं'), findsWidgets);
    expect(find.text('छोड़ें'), findsOneWidget);
    expect(find.text('सहमति की ओर बढ़ें'), findsOneWidget);
  });

  testWidgets('questions are filtered to the enrolled child age', (
    tester,
  ) async {
    final container = makeContainer();
    container.read(sessionProvider.notifier).setChildProfile(profile30);
    await tester.pumpWidget(buildApp(container));
    await tester.pumpAndSettle();

    // Age 30 matches 8 of the 16 milestones; out-of-window items are hidden.
    expect(find.text('0/8 उत्तर दिए गए'), findsOneWidget);
    expect(
      find.text('क्या बच्चा किसी चीज़ को पकड़कर खड़ा होता है?'),
      findsNothing,
    );
    expect(
      find.textContaining('बिना सहारे के कुछ कदम चलता है'),
      findsOneWidget,
    );
  });

  testWidgets('हाँ/नहीं taps record answers on the session', (tester) async {
    // Tall surface so multiple question cards are tappable at once.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = makeContainer();
    container.read(sessionProvider.notifier).setChildProfile(profile30);
    await tester.pumpWidget(buildApp(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('हाँ').first);
    await tester.pumpAndSettle();

    final state = container.read(sessionProvider);
    expect(state.milestoneAnswers.length, 1);
    expect(state.milestoneAnswers['q_walks_alone'], isTrue);
    expect(find.text('1/8 उत्तर दिए गए'), findsOneWidget);

    await tester.tap(find.text('नहीं').at(1));
    await tester.pumpAndSettle();
    expect(container.read(sessionProvider).milestoneAnswers.length, 2);
  });

  testWidgets('finishing stores a summary and navigates to consent', (
    tester,
  ) async {
    final container = makeContainer();
    container.read(sessionProvider.notifier).setChildProfile(profile30);
    await tester.pumpWidget(buildApp(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('हाँ').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('सहमति की ओर बढ़ें'));
    await tester.pumpAndSettle();

    expect(find.byType(ConsentScreen), findsOneWidget);
    final summary = container.read(sessionProvider).milestoneSummary;
    expect(summary, isNotNull);
    expect(summary!.totalApplicable, 8);
    expect(summary.answeredYes, 1);
    expect(summary.status, MilestoneStatus.normal);
  });

  testWidgets('छोड़ें skips the questionnaire and still reaches consent', (
    tester,
  ) async {
    final container = makeContainer();
    await tester.pumpWidget(buildApp(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('छोड़ें'));
    await tester.pumpAndSettle();

    expect(find.byType(ConsentScreen), findsOneWidget);
    final state = container.read(sessionProvider);
    expect(state.questionnaireSkipped, isTrue);
    expect(state.milestoneSummary, isNull);
  });
}
