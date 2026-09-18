import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_config.dart';

enum AppUserRole { parent, careWorker, admin }

class AppAuthState {
  const AppAuthState({
    this.configured = false,
    this.loading = false,
    this.user,
    this.role,
    this.displayName,
    this.error,
  });

  final bool configured;
  final bool loading;
  final User? user;
  final AppUserRole? role;
  final String? displayName;
  final String? error;

  bool get signedIn => user != null && role != null;
  bool get canSyncScreenings =>
      role == AppUserRole.careWorker || role == AppUserRole.admin;

  AppAuthState copyWith({
    bool? loading,
    User? user,
    AppUserRole? role,
    String? displayName,
    String? error,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AppAuthState(
      configured: configured,
      loading: loading ?? this.loading,
      user: clearUser ? null : user ?? this.user,
      role: clearUser ? null : role ?? this.role,
      displayName: clearUser ? null : displayName ?? this.displayName,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class AppAuthNotifier extends StateNotifier<AppAuthState> {
  AppAuthNotifier(this._client)
    : super(AppAuthState(configured: _client != null)) {
    if (_client == null) return;
    _subscription = _client.auth.onAuthStateChange.listen(
      (event) => _loadProfile(event.session?.user),
    );
    unawaited(_loadProfile(_client.auth.currentUser));
  }

  final SupabaseClient? _client;
  StreamSubscription<AuthState>? _subscription;

  Future<void> signIn({
    required String email,
    required String password,
    required AppUserRole expectedRole,
  }) async {
    final client = _requireClient();
    if (client == null) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final response = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      await _loadProfile(response.user);
      if (state.role != expectedRole && state.role != AppUserRole.admin) {
        await client.auth.signOut();
        state = state.copyWith(
          loading: false,
          clearUser: true,
          error: 'This account does not have the selected role.',
        );
        return;
      }
      state = state.copyWith(loading: false);
    } on AuthException catch (error) {
      state = state.copyWith(loading: false, error: error.message);
    }
  }

  Future<void> signUpParent({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final client = _requireClient();
    if (client == null) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final response = await client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'display_name': displayName.trim()},
      );
      if (response.session == null) {
        state = state.copyWith(
          loading: false,
          error: 'Check your email to confirm your account, then sign in.',
        );
        return;
      }
      await _loadProfile(response.user);
      state = state.copyWith(loading: false);
    } on AuthException catch (error) {
      state = state.copyWith(loading: false, error: error.message);
    }
  }

  Future<void> signOut() async {
    final client = _client;
    if (client == null) return;
    await client.auth.signOut();
    state = state.copyWith(clearUser: true, clearError: true);
  }

  SupabaseClient? _requireClient() {
    if (_client != null) return _client;
    state = state.copyWith(error: 'Supabase is not configured for this build.');
    return null;
  }

  Future<void> _loadProfile(User? user) async {
    final client = _client;
    if (client == null || user == null) {
      state = state.copyWith(clearUser: true, loading: false);
      return;
    }
    state = state.copyWith(loading: true, clearError: true);
    try {
      final profile = await client
          .from('profiles')
          .select('role, display_name')
          .eq('id', user.id)
          .maybeSingle();
      final role = switch (profile?['role']) {
        'parent' => AppUserRole.parent,
        'clinician' => AppUserRole.careWorker,
        'admin' => AppUserRole.admin,
        _ => null,
      };
      state = state.copyWith(
        loading: false,
        user: user,
        role: role,
        displayName: profile?['display_name'] as String?,
        error: role == null
            ? 'This account has no EarlyEcho access role.'
            : null,
      );
    } catch (_) {
      state = state.copyWith(
        loading: false,
        clearUser: true,
        error: 'Could not load your EarlyEcho access role.',
      );
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final appAuthProvider = StateNotifierProvider<AppAuthNotifier, AppAuthState>((
  ref,
) {
  SupabaseClient? client;
  if (SupabaseConfig.isConfigured) {
    try {
      client = Supabase.instance.client;
    } catch (_) {}
  }
  return AppAuthNotifier(client);
});
