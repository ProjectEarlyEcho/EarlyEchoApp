import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/session_repository.dart';
import '../../data/repositories/sync_repository.dart';

final savedSessionsProvider = FutureProvider((ref) {
  return ref.watch(sessionRepositoryProvider).getAllSessions();
});

/// User-facing sync status: how many screenings are still queued locally,
/// whether an upload pass is running, and what the last pass produced.
class SyncState {
  const SyncState({
    this.pendingCount = 0,
    this.isSyncing = false,
    this.lastSyncTime,
    this.lastResult,
  });

  final int pendingCount;
  final bool isSyncing;
  final DateTime? lastSyncTime;
  final SyncResult? lastResult;

  SyncState copyWith({
    int? pendingCount,
    bool? isSyncing,
    DateTime? lastSyncTime,
    SyncResult? lastResult,
  }) {
    return SyncState(
      pendingCount: pendingCount ?? this.pendingCount,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      lastResult: lastResult ?? this.lastResult,
    );
  }
}

/// Drives [SyncRepository] and exposes queue state to the UI.
///
/// Call [syncNow] when connectivity is available (e.g. on a connectivity
/// listener or a manual refresh); failed uploads stay queued and are
/// reflected in [SyncState.pendingCount].
class SyncNotifier extends StateNotifier<SyncState> {
  SyncNotifier(this._repository) : super(const SyncState());

  final SyncRepository _repository;

  /// Re-reads the pending-upload count from the local database.
  Future<void> refreshPendingCount() async {
    final count = await _repository.pendingCount();
    state = state.copyWith(pendingCount: count);
  }

  /// Runs one upload pass over the pending queue.
  Future<SyncResult> syncNow() async {
    state = state.copyWith(isSyncing: true);
    final result = await _repository.syncPending();
    state = state.copyWith(
      pendingCount: result.remaining,
      isSyncing: false,
      lastSyncTime: DateTime.now(),
      lastResult: result,
    );
    return result;
  }
}

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(),
);

final syncRepositoryProvider = Provider<SyncRepository>(
  (ref) => SyncRepository(sessions: ref.watch(sessionRepositoryProvider)),
);

final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>(
  (ref) => SyncNotifier(ref.watch(syncRepositoryProvider)),
);
