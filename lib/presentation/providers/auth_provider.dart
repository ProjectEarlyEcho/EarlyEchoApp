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
  int _profileRequest = 0;
  int _authOperation = 0;
  String? _loadingProfileFor;
  Future<void>? _loadingProfile;

  Future<void> signIn({
    required String email,
    required String password,
    required AppUserRole expectedRole,
  }) async {
    final client = _requireClient();
    if (client == null) return;
    final operation = ++_authOperation;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final response = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (!mounted ||
          operation != _authOperation ||
          client.auth.currentUser?.id != response.user?.id) {
        return;
      }
      await _loadProfile(response.user);
      if (!mounted ||
          operation != _authOperation ||
          client.auth.currentUser?.id != response.user?.id) {
        return;
      }
      if (state.error != null) return;
      if (state.role != expectedRole && state.role != AppUserRole.admin) {
        await client.auth.signOut();
        if (!mounted || operation != _authOperation) return;
        state = state.copyWith(
          loading: false,
          clearUser: true,
          error: 'This account does not have the selected role.',
        );
        return;
      }
      state = state.copyWith(loading: false);
    } on AuthException catch (error) {
      if (!mounted || operation != _authOperation) return;
      state = state.copyWith(loading: false, error: error.message);
    } catch (_) {
      if (!mounted || operation != _authOperation) return;
      state = state.copyWith(
        loading: false,
        error: 'Could not sign in. Please try again.',
      );
    }
  }

  Future<void> signUpParent({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final client = _requireClient();
    if (client == null) return;
    final operation = ++_authOperation;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final response = await client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'display_name': displayName.trim()},
      );
      if (!mounted || operation != _authOperation) return;
      if (response.session == null) {
        state = state.copyWith(
          loading: false,
          error: 'Check your email to confirm your account, then sign in.',
        );
        return;
      }
      await _loadProfile(response.user);
      if (!mounted || operation != _authOperation) return;
      state = state.copyWith(loading: false);
    } on AuthException catch (error) {
      if (!mounted || operation != _authOperation) return;
      state = state.copyWith(loading: false, error: error.message);
    } catch (_) {
      if (!mounted || operation != _authOperation) return;
      state = state.copyWith(
        loading: false,
        error: 'Could not create your account. Please try again.',
      );
    }
  }

  Future<void> signOut() async {
    final client = _client;
    if (client == null) return;
    _authOperation++;
    _profileRequest++;
    _loadingProfileFor = null;
    _loadingProfile = null;
    state = state.copyWith(clearUser: true, clearError: true, loading: false);
    await client.auth.signOut();
  }

  SupabaseClient? _requireClient() {
    if (_client != null) return _client;
    state = state.copyWith(error: 'Supabase is not configured for this build.');
    return null;
  }

  Future<void> _loadProfile(User? user) {
    if (!mounted) return Future.value();
    // Auth events and the sign-in response can request the same profile at
    // once. Await one shared result before validating the selected role.
    if (user != null &&
        _loadingProfileFor == user.id &&
        _loadingProfile != null) {
      return _loadingProfile!;
    }
    _loadingProfileFor = user?.id;
    late final Future<void> pending;
    pending = _readProfile(user).whenComplete(() {
      if (identical(_loadingProfile, pending)) {
        _loadingProfile = null;
        _loadingProfileFor = null;
      }
    });
    return _loadingProfile = pending;
  }

  Future<void> _readProfile(User? user) async {
    if (!mounted) return;
    final request = ++_profileRequest;
    final client = _client;
    if (client == null || user == null) {
      state = state.copyWith(clearUser: true, loading: false);
      return;
    }
    // Publish the new identity immediately; never retain another account's
    // role or owner-scoped providers while its profile request is in flight.
    state = AppAuthState(configured: true, loading: true, user: user);
    try {
      final profile = await client
          .from('profiles')
          .select('role, display_name')
          .eq('id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 30));
      if (!mounted ||
          request != _profileRequest ||
          client.auth.currentUser?.id != user.id) {
        return;
      }
      final role = switch (profile?['role']) {
        'parent' => AppUserRole.parent,
        'clinician' => AppUserRole.careWorker,
        'admin' => AppUserRole.admin,
        _ => null,
      };
      state = AppAuthState(
        configured: true,
        loading: false,
        user: user,
        role: role,
        displayName: profile?['display_name'] as String?,
        error: role == null
            ? 'This account has no EarlyEcho access role.'
            : null,
      );
    } catch (_) {
      if (!mounted ||
          request != _profileRequest ||
          client.auth.currentUser?.id != user.id) {
        return;
      }
      state = AppAuthState(
        configured: true,
        user: user,
        error: 'Could not load your EarlyEcho access role.',
      );
    }
  }

  @override
  void dispose() {
    _profileRequest++;
    _authOperation++;
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
