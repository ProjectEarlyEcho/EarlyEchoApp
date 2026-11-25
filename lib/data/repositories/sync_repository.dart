import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/session_model.dart';
import 'session_repository.dart';
import 'sync_conflict.dart';

/// Upload ports acknowledge only accepted inserts or identical replays.
abstract class ScreeningUploader {
  Future<void> upload(SessionModel session);
}

abstract class ConsentLogUploader {
  Future<void> uploadConsentLog(ConsentLog log);
}

/// The server atomically compares immutable records on replay. A table upsert
/// would silently overwrite a conflicting result and is deliberately avoided.
/// Linked-child screenings also populate the shared care history atomically.
class SupabaseScreeningUploader
    implements ScreeningUploader, ConsentLogUploader {
  const SupabaseScreeningUploader(
    this._client, {
    this.requestTimeout = const Duration(seconds: 30),
  });

  final SupabaseClient _client;
  final Duration requestTimeout;

  @override
  Future<void> upload(SessionModel session) => _upload(
    session.cloudChildId == null ? 'sync_screening' : 'sync_child_screening',
    'screening',
    session.id,
    session.ownerId,
    {
      'p_screening': session.toJson(),
      if (session.cloudChildId != null)
        'p_dashboard': session.toDashboardJson(),
    },
  );

  @override
  Future<void> uploadConsentLog(ConsentLog log) => _upload(
    'sync_consent_log',
    'consent',
    log.id,
    log.ownerId,
    {'p_consent': log.toJson()},
  );

  Future<void> _upload(
    String rpc,
    String type,
    String id,
    String? ownerId,
    Map<String, dynamic> parameters,
  ) async {
    if (ownerId == null || _client.auth.currentUser?.id != ownerId) {
      throw StateError('Sign in to the record owner account before syncing.');
    }
    try {
      // A timed-out request may still commit remotely; its stable identity
      // makes the next attempt a safe replay instead of a second record.
      final result = await _client
          .rpc(rpc, params: parameters)
          .timeout(requestTimeout);
      if (_client.auth.currentUser?.id != ownerId) {
        throw StateError('The account changed during sync.');
      }
      if (result != 'inserted' && result != 'replayed') {
        throw StateError('The server did not acknowledge the record.');
      }
    } on PostgrestException catch (error) {
      if (error.code == 'PT409') throw SyncConflictException(type, id);
      rethrow;
    }
  }
}

class SyncResult {
  const SyncResult({
    required this.attempted,
    required this.uploaded,
    required this.failed,
    required this.remaining,
    this.conflicts = 0,
    this.consentAttempted = 0,
    this.consentUploaded = 0,
    this.consentFailed = 0,
    this.consentRemaining = 0,
    this.consentConflicts = 0,
    this.offline = false,
    this.accountChanged = false,
  });

  final int attempted;
  final int uploaded;
  final int failed;
  final int remaining;

  /// Conflicts are also counted in [failed]; their rows remain queued.
  final int conflicts;
  final int consentAttempted;
  final int consentUploaded;
  final int consentFailed;
  final int consentRemaining;
  final int consentConflicts;
  final bool offline;
  final bool accountChanged;

  int get totalRemaining => remaining + consentRemaining;
  bool get allSynced =>
      !offline &&
      !accountChanged &&
      failed == 0 &&
      consentFailed == 0 &&
      totalRemaining == 0;
}

/// Owner-bound, single-flight queue draining. SQLite acknowledgements follow
/// remote acceptance so a crash or lost response is safely replayed next time.
/// Multiple repository instances/devices remain safe through server uniqueness.
class SyncRepository {
  SyncRepository({
    ScreeningUploader? uploader,
    ConsentLogUploader? consentUploader,
    SessionRepository? sessions,
    String? Function()? currentOwnerId,
  }) : _uploader = uploader ?? _defaultUploader(),
       _consentUploader =
           consentUploader ??
           (uploader is ConsentLogUploader
               ? uploader as ConsentLogUploader
               : _defaultUploader()),
       _sessions = sessions ?? SessionRepository(),
       _currentOwnerId = currentOwnerId ?? authenticatedOwnerId;

  final ScreeningUploader? _uploader;
  final ConsentLogUploader? _consentUploader;
  final SessionRepository _sessions;
  final String? Function() _currentOwnerId;
  Future<SyncResult>? _inFlight;
  bool _rescanRequested = false;
  bool _disposed = false;

  bool get _ownerActive =>
      !_disposed &&
      _sessions.ownerId != null &&
      _currentOwnerId() == _sessions.ownerId;

  /// End this account epoch. An accepted late response stays queued for replay;
  /// signing back into the same owner must use a new repository instance.
  void dispose() {
    _disposed = true;
    _rescanRequested = false;
  }

  static String? authenticatedOwnerId() {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  static SupabaseScreeningUploader? _defaultUploader() {
    try {
      return SupabaseScreeningUploader(Supabase.instance.client);
    } catch (_) {
      return null;
    }
  }

  Future<int> pendingCount() async =>
      await _sessions.getUnsyncedCount() +
      (await _sessions.getUnsyncedConsentLogs()).length;

  Future<SyncResult> syncPending() {
    final active = _inFlight;
    if (active != null) {
      // Coalesce concurrent requests, but honor work saved after the active
      // pass took its snapshot. All callers await the complete drain.
      if (_ownerActive) _rescanRequested = true;
      return active;
    }
    return _inFlight = _drain().whenComplete(() {
      _inFlight = null;
    });
  }

  Future<SyncResult> _drain() async {
    // Rescans only attempt newly discovered rows. Failures/conflicts wait for a
    // later explicit flight instead of being retried in a busy loop.
    final screeningsAttempted = <String>{};
    final consentsAttempted = <String>{};
    SyncResult? combined;
    do {
      _rescanRequested = false;
      final next = await _syncPending(screeningsAttempted, consentsAttempted);
      combined = SyncResult(
        attempted: (combined?.attempted ?? 0) + next.attempted,
        uploaded: (combined?.uploaded ?? 0) + next.uploaded,
        failed: (combined?.failed ?? 0) + next.failed,
        remaining: next.remaining,
        conflicts: (combined?.conflicts ?? 0) + next.conflicts,
        consentAttempted:
            (combined?.consentAttempted ?? 0) + next.consentAttempted,
        consentUploaded:
            (combined?.consentUploaded ?? 0) + next.consentUploaded,
        consentFailed: (combined?.consentFailed ?? 0) + next.consentFailed,
        consentRemaining: next.consentRemaining,
        consentConflicts:
            (combined?.consentConflicts ?? 0) + next.consentConflicts,
        offline: next.offline,
        accountChanged: next.accountChanged,
      );
    } while (_rescanRequested &&
        _ownerActive &&
        !combined.offline &&
        !combined.accountChanged);
    return combined;
  }

  Future<SyncResult> _syncPending(
    Set<String> screeningsAttempted,
    Set<String> consentsAttempted,
  ) async {
    final pending = await _sessions.getUnsyncedSessions();
    final uploader = _uploader;
    if (uploader == null || !_ownerActive) {
      return SyncResult(
        attempted: 0,
        uploaded: 0,
        failed: 0,
        remaining: pending.length,
        consentRemaining: (await _sessions.getUnsyncedConsentLogs()).length,
        offline: true,
        accountChanged: _disposed,
      );
    }

    var attempted = 0;
    var uploaded = 0;
    var failed = 0;
    var conflicts = 0;
    for (final session in pending) {
      if (!_ownerActive) break;
      if (!screeningsAttempted.add(session.id)) continue;
      attempted++;
      try {
        await uploader.upload(session);
        if (!_ownerActive) break;
        await _sessions.markSynced(session);
        uploaded++;
      } catch (error) {
        failed++;
        if (error is SyncConflictException) conflicts++;
      }
    }

    var consentAttempted = 0;
    var consentUploaded = 0;
    var consentFailed = 0;
    var consentConflicts = 0;
    final consentUploader = _consentUploader;
    if (consentUploader != null && _ownerActive) {
      for (final log in await _sessions.getUnsyncedConsentLogs()) {
        if (!_ownerActive) break;
        // A failed/conflicting screening must never acquire a remote consent
        // link until that exact local screening has been acknowledged.
        final session = await _sessions.getSessionById(log.sessionId!);
        if (session == null || !session.syncedToCloud) continue;
        if (!_ownerActive) break;
        if (!consentsAttempted.add(log.id)) continue;
        consentAttempted++;
        try {
          await consentUploader.uploadConsentLog(log);
          if (!_ownerActive) break;
          await _sessions.markConsentLogSynced(log);
          consentUploaded++;
        } catch (error) {
          consentFailed++;
          if (error is SyncConflictException) consentConflicts++;
        }
      }
    }

    return SyncResult(
      attempted: attempted,
      uploaded: uploaded,
      failed: failed,
      remaining: await _sessions.getUnsyncedCount(),
      conflicts: conflicts,
      consentAttempted: consentAttempted,
      consentUploaded: consentUploaded,
      consentFailed: consentFailed,
      consentConflicts: consentConflicts,
      consentRemaining: (await _sessions.getUnsyncedConsentLogs()).length,
      accountChanged: !_ownerActive,
    );
  }
}
