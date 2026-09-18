import 'dart:io';

import 'package:earlyecho/core/routes.dart';
import 'package:earlyecho/core/theme.dart';
import 'package:earlyecho/domain/milestone_engine.dart';
import 'package:earlyecho/presentation/providers/session_provider.dart';
import 'package:earlyecho/presentation/screens/child_profile/child_profile_screen.dart';
import 'package:earlyecho/presentation/screens/developmental_goals/developmental_goals_screen.dart';
import 'package:earlyecho/presentation/screens/questionnaire/questionnaire_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  /// The form is a lazy ListView — give the tester a tall surface so every
  /// field is built without scrolling.
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Widget buildScreen() {
    return ProviderScope(
      child: MaterialApp(
        theme: EarlyEchoTheme.lightTheme,
        home: const ChildProfileScreen(),
      ),
    );
  }

  Future<void> fillField(WidgetTester tester, String label, String text) {
    return tester.enterText(find.widgetWithText(TextFormField, label), text);
  }

  /// Enters everything except the optional child name, then picks a state.
  Future<void> fillValidForm(WidgetTester tester, {String age = '30'}) async {
    await fillField(tester, 'उम्र (महीनों में)', age);
    await fillField(tester, 'आंगनबाड़ी आईडी', 'IN-MP-042');
    await fillField(tester, 'जिला', 'Indore');
    await fillField(tester, 'कार्यकर्ता का नाम', 'सीमा');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Madhya Pradesh').last);
    await tester.pumpAndSettle();
  }

  testWidgets('renders the enrollment form fields', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('बच्चे का नाम (वैकल्पिक)'), findsOneWidget);
    expect(find.text('उम्र (महीनों में)'), findsOneWidget);
    expect(find.text('आंगनबाड़ी आईडी'), findsOneWidget);
    expect(find.text('राज्य'), findsOneWidget);
    expect(find.text('जिला'), findsOneWidget);
    expect(find.text('कार्यकर्ता का नाम'), findsOneWidget);
    expect(find.text('प्रश्नावली की ओर बढ़ें'), findsOneWidget);
  });

  testWidgets('continue is blocked while required fields are empty', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('प्रश्नावली की ओर बढ़ें'));
    await tester.pumpAndSettle();

    expect(find.text('बच्चे की उम्र दर्ज करें'), findsOneWidget);
    expect(find.text('आंगनबाड़ी आईडी आवश्यक है'), findsOneWidget);
    expect(find.text('राज्य चुनें'), findsOneWidget);
    expect(find.text('जिला दर्ज करें'), findsOneWidget);
    expect(find.text('कार्यकर्ता का नाम दर्ज करें'), findsOneWidget);
  });

  testWidgets('an out-of-range age is rejected by validation', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await fillValidForm(tester, age: '6');
    await tester.tap(find.text('प्रश्नावली की ओर बढ़ें'));
    await tester.pumpAndSettle();

    expect(find.text('उम्र 12–60 महीनों के बीच होनी चाहिए'), findsOneWidget);
    expect(find.byType(QuestionnaireScreen), findsNothing);
  });

  testWidgets('a valid form stores the profile and navigates onward', (
    tester,
  ) async {
    useTallSurface(tester);
    final container = ProviderContainer(
      overrides: [
        milestoneQuestionsLoaderProvider.overrideWithValue(() async {
          return MilestoneEngine.parseQuestions(
            File('assets/data/milestones_hi.json').readAsStringSync(),
          );
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: EarlyEchoTheme.lightTheme,
          routerConfig: GoRouter(
            initialLocation: '/child-profile',
            routes: appRoutes,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await fillField(tester, 'बच्चे का नाम (वैकल्पिक)', 'आरव');
    await fillValidForm(tester);
    await tester.tap(find.text('प्रश्नावली की ओर बढ़ें'));
    await tester.pumpAndSettle();

    expect(find.byType(DevelopmentalGoalsScreen), findsOneWidget);
    await tester.tap(find.text('प्रश्नावली की ओर बढ़ें'));
    await tester.pumpAndSettle();
    expect(find.byType(QuestionnaireScreen), findsOneWidget);

    final profile = container.read(sessionProvider).childProfile;
    expect(profile, isNotNull);
    expect(profile!.childName, 'आरव');
    expect(profile.childAgeMonths, 30);
    expect(profile.isAgeValid, isTrue);
    expect(profile.anganwadiId, 'IN-MP-042');
    expect(profile.stateCode, 'Madhya Pradesh');
    expect(profile.districtCode, 'Indore');
    expect(profile.workerName, 'सीमा');
  });
}
