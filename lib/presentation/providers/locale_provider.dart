import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's display language.
///
/// `null` means the worker has not chosen yet — the router redirects to the
/// language picker until [select] is called. The choice persists under
/// `app_locale` in SharedPreferences and is restored by [loadSaved] at app
/// start. Hindi is the default when nothing is stored (and in tests, where
/// the picker would otherwise swallow every screen).
class AppLocaleNotifier extends StateNotifier<Locale?> {
  /// Default constructor: Hindi, used by the base provider and by tests.
  AppLocaleNotifier({Locale? initial}) : super(initial ?? const Locale('hi'));

  /// First-run state: no choice yet, so the router shows the picker.
  AppLocaleNotifier.undecided() : super(null);

  static const _prefKey = 'app_locale';

  /// Reads the persisted choice; `null` when the worker has never picked.
  static Future<Locale?> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefKey);
    if (code == null) return null;
    return Locale(code);
  }

  /// Persists and applies [locale] (`en` or `hi`).
  Future<void> select(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, locale.languageCode);
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
