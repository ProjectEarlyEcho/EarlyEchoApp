import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../presentation/providers/locale_provider.dart';
import '../presentation/screens/child_profile/child_profile_screen.dart';
import '../presentation/screens/consent/consent_screen.dart';
import '../presentation/screens/developmental_goals/developmental_goals_screen.dart';
import '../presentation/screens/elicitation/elicitation_screen.dart';
import '../presentation/screens/history/result_history_screen.dart';
import '../presentation/screens/history/session_detail_screen.dart';
import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/language/language_selection_screen.dart';
import '../presentation/screens/auth/login_screen.dart';
import '../presentation/screens/care/care_portal_screen.dart';
import '../presentation/screens/care/child_picker_screen.dart';
import '../presentation/screens/processing/processing_screen.dart';
import '../presentation/screens/questionnaire/questionnaire_screen.dart';
import '../presentation/screens/referral/referral_screen.dart';
import '../presentation/screens/result/result_screen.dart';
import '../presentation/screens/settings/settings_screen.dart';

/// Route table for the app shell — one entry per screen.
///
/// Ordered to match the seven-step screening flow (home → child profile →
/// questionnaire → consent → elicitation → processing → result → referral),
/// followed by the two utility destinations (history, settings). Kept as a
/// standalone list so tests can spin up routers at any initial location.
final appRoutes = <GoRoute>[
  GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
  GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
  GoRoute(
    path: '/care/children',
    builder: (context, state) => const ChildPickerScreen(),
  ),
  GoRoute(path: '/care', builder: (context, state) => const CarePortalScreen()),
  GoRoute(
    path: '/care/conversations/:conversationId',
    builder: (context, state) => CareMessageThreadScreen(
      conversationId: state.pathParameters['conversationId']!,
    ),
  ),
  GoRoute(
    path: '/child-profile',
    builder: (context, state) => const ChildProfileScreen(),
  ),
  GoRoute(
    path: '/developmental-goals',
    builder: (context, state) => const DevelopmentalGoalsScreen(),
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
    path: '/history/:id',
    builder: (context, state) => SessionDetailScreen(
      session: state.extra! as dynamic,
    ),
  ),
  GoRoute(
    path: '/settings',
    builder: (context, state) => const SettingsScreen(),
  ),
];

/// App-wide router for [EarlyEchoApp].
///
/// Until the worker has picked a language, every navigation is redirected
/// to `/language`; the picker persists the choice and the router rebuilds
/// when [appLocaleProvider] changes.
final appRouterProvider = Provider<GoRouter>((ref) {
  final locale = ref.watch(appLocaleProvider);
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      if (locale != null) return null;
      return state.matchedLocation == '/language' ? null : '/language';
    },
    routes: [
      GoRoute(
        path: '/language',
        builder: (context, state) => const LanguageSelectionScreen(),
      ),
      ...appRoutes,
    ],
  );
});
