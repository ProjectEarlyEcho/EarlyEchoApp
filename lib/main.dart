import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routes.dart';
import 'core/theme.dart';

void main() {
  runApp(const ProviderScope(child: EarlyEchoApp()));
}

/// Root of the EarlyEcho app — a routed shell over the placeholder screens.
///
/// Hindi-first UI for Anganwadi workers; theme and navigation live in
/// `lib/core`.
class EarlyEchoApp extends StatelessWidget {
  const EarlyEchoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'EarlyEcho',
      theme: EarlyEchoTheme.lightTheme,
      darkTheme: EarlyEchoTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: goRouter,
    );
  }
}
