import 'package:go_router/go_router.dart';

import '../presentation/screens/child_profile/child_profile_screen.dart';
import '../presentation/screens/consent/consent_screen.dart';
import '../presentation/screens/elicitation/elicitation_screen.dart';
import '../presentation/screens/history/result_history_screen.dart';
import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/processing/processing_screen.dart';
import '../presentation/screens/questionnaire/questionnaire_screen.dart';
import '../presentation/screens/referral/referral_screen.dart';
import '../presentation/screens/result/result_screen.dart';
import '../presentation/screens/settings/settings_screen.dart';

/// Route table for the app shell — one entry per placeholder screen.
///
/// Ordered to match the seven-step screening flow (home → child profile →
/// questionnaire → consent → elicitation → processing → result → referral),
/// followed by the two utility destinations (history, settings). Kept as a
/// standalone list so tests can spin up routers at any initial location.
final appRoutes = <GoRoute>[
  GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
  GoRoute(
    path: '/child-profile',
    builder: (context, state) => const ChildProfileScreen(),
  ),
  GoRoute(
    path: '/questionnaire',
    builder: (context, state) => const QuestionnaireScreen(),
  ),
  GoRoute(path: '/consent', builder: (context, state) => const ConsentScreen()),
  GoRoute(
    path: '/elicitation',
    builder: (context, state) => const ElicitationScreen(),
  ),
  GoRoute(
    path: '/processing',
    builder: (context, state) => const ProcessingScreen(),
  ),
  GoRoute(path: '/result', builder: (context, state) => const ResultScreen()),
  GoRoute(
    path: '/referral',
    builder: (context, state) => const ReferralScreen(),
  ),
  GoRoute(
    path: '/history',
    builder: (context, state) => const ResultHistoryScreen(),
  ),
  GoRoute(
    path: '/settings',
    builder: (context, state) => const SettingsScreen(),
  ),
];

/// App-wide router used by [EarlyEchoApp].
final goRouter = GoRouter(initialLocation: '/', routes: appRoutes);
