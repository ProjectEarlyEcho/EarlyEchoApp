import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/routes.dart';
import 'core/supabase_config.dart';
import 'core/theme.dart';
import 'presentation/providers/locale_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
  }
  final savedLocale = await AppLocaleNotifier.loadSaved();
  runApp(
    ProviderScope(
      overrides: [
        appLocaleProvider.overrideWith(
          (ref) => savedLocale == null
              ? AppLocaleNotifier.undecided()
              : AppLocaleNotifier(initial: savedLocale),
        ),
      ],
      child: const EarlyEchoApp(),
    ),
  );
}

/// Root of the EarlyEcho app — a routed shell over the screening flow.
///
/// Hindi-first UI for Anganwadi workers with an English option chosen on
/// first launch; theme and navigation live in `lib/core`.
class EarlyEchoApp extends ConsumerWidget {
  const EarlyEchoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(appLocaleProvider);
    return MaterialApp.router(
      title: 'EarlyEcho',
      theme: EarlyEchoTheme.lightTheme,
      darkTheme: EarlyEchoTheme.darkTheme,
      themeMode: ThemeMode.system,
      locale: locale ?? const Locale('hi'),
      supportedLocales: const [Locale('en'), Locale('hi')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
