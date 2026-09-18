import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The persisted English or Hindi app language.
class AppLocaleNotifier extends StateNotifier<Locale?> {
  AppLocaleNotifier({Locale? initial}) : super(initial ?? const Locale('hi'));

  /// First-run state: no choice yet, so the router shows the picker.
  AppLocaleNotifier.undecided() : super(null);

  static const _prefKey = 'app_locale';

  /// Returns the persisted supported locale, or null on first launch.
  static Future<Locale?> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefKey);
    if (code != 'en' && code != 'hi') return null;
    return Locale(code!);
  }

  /// Applies and persists English or Hindi.
  Future<void> select(Locale locale) async {
    final selected = locale.languageCode == 'hi'
        ? const Locale('hi')
        : const Locale('en');
    state = selected;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, selected.languageCode);
  }

  /// Clears the saved choice so the picker shows again (used by the
  /// language row in settings).
  Future<void> reset() async {
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }
}

final appLocaleProvider = StateNotifierProvider<AppLocaleNotifier, Locale?>((
  ref,
) {
  return AppLocaleNotifier();
});
