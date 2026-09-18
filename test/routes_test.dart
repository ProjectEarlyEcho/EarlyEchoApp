import 'package:earlyecho/core/routes.dart';
import 'package:earlyecho/core/theme.dart';
import 'package:earlyecho/presentation/screens/child_profile/child_profile_screen.dart';
import 'package:earlyecho/presentation/screens/consent/consent_screen.dart';
import 'package:earlyecho/presentation/screens/elicitation/elicitation_screen.dart';
import 'package:earlyecho/presentation/screens/history/result_history_screen.dart';
import 'package:earlyecho/presentation/screens/home/home_screen.dart';
import 'package:earlyecho/presentation/screens/processing/processing_screen.dart';
import 'package:earlyecho/presentation/screens/questionnaire/questionnaire_screen.dart';
import 'package:earlyecho/presentation/screens/referral/referral_screen.dart';
import 'package:earlyecho/presentation/screens/result/result_screen.dart';
import 'package:earlyecho/presentation/screens/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Widget buildTestApp(String initialLocation) {
    return ProviderScope(
      child: MaterialApp.router(
        theme: EarlyEchoTheme.lightTheme,
        routerConfig: GoRouter(
          initialLocation: initialLocation,
          routes: appRoutes,
        ),
      ),
    );
  }

  final routeCases = <String, Type>{
    '/': HomeScreen,
    '/child-profile': ChildProfileScreen,
    '/questionnaire': QuestionnaireScreen,
    '/consent': ConsentScreen,
    '/elicitation': ElicitationScreen,
    '/processing': ProcessingScreen,
    '/result': ResultScreen,
    '/referral': ReferralScreen,
    '/history': ResultHistoryScreen,
    '/settings': SettingsScreen,
  };

  for (final entry in routeCases.entries) {
    testWidgets('route ${entry.key} builds ${entry.value}', (tester) async {
      await tester.pumpWidget(buildTestApp(entry.key));
      await tester.pumpAndSettle();

      expect(find.byType(entry.value), findsOneWidget);
    });
  }

  testWidgets('tapping next walks the whole screening flow', (tester) async {
    await tester.pumpWidget(buildTestApp('/'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    Future<void> tapNext(String label, Type screen) async {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.byType(screen), findsOneWidget);
    }

    await tapNext('नई स्क्रीनिंग शुरू करें', ChildProfileScreen);
    await tapNext('प्रश्नावली की ओर बढ़ें', QuestionnaireScreen);
    await tapNext('सहमति की ओर बढ़ें', ConsentScreen);
    await tapNext('अभिभावक ने सहमति दी', ElicitationScreen);
    await tapNext('रिकॉर्डिंग शुरू करें', ProcessingScreen);
    await tapNext('परिणाम देखें', ResultScreen);
    await tapNext('रेफरल देखें', ReferralScreen);

    // Referral is the last step — its button returns home.
    await tapNext('होम पर लौटें', HomeScreen);
  });
}
