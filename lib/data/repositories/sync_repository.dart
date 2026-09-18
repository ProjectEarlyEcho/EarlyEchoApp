import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/session_model.dart';
import 'session_repository.dart';

/// Port for pushing one screening row to the cloud backend.
///
/// Implementations must throw on failure so the caller keeps the local row
/// queued for the next retry. Tests substitute a fake; production uses
/// [SupabaseScreeningUploader].
abstract class ScreeningUploader {
  Future<void> upload(SessionModel session);
}

/// Port for uploading the consent audit records linked to screening sessions.
abstract class ConsentLogUploader {
  Future<void> uploadConsentLog(ConsentLog log);
}

/// Uploads a session to the Supabase `screenings` table.
///
/// Only numeric biomarker columns are sent (see [SessionModel.toJson]) —
/// never audio and never the child's name.
class SupabaseScreeningUploader
    implements ScreeningUploader, ConsentLogUploader {
  const SupabaseScreeningUploader(this._client);

  final SupabaseClient _client;

  static const String table = 'screenings';
  static const String consentTable = 'consent_logs';

  @override
  Future<void> upload(SessionModel session) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Sign in as a care worker before syncing screenings.');
    }
    final profile = await _client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();
    final role = profile?['role'] as String?;
    if (role != 'clinician' && role != 'admin') {
      throw StateError('Only care workers can sync screening records.');
    }
    await _client.from(table).upsert(session.toJson());
  }

  @override
  Future<void> uploadConsentLog(ConsentLog log) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Sign in as a care worker before syncing consent logs.');
    }
    await _client.from(consentTable).upsert(log.toJson());
  }
}

/// Outcome of a [SyncRepository.syncPending] pass.
class SyncResult {
  const SyncResult({
    required this.attempted,
    required this.uploaded,
    required this.failed,
    required this.remaining,
    this.offline = false,
  });

  /// Sessions pulled from the pending queue this pass.
  final int attempted;

  /// Sessions successfully written to the cloud table.
  final int uploaded;

  /// Sessions whose upload threw; they stay queued for the next retry.
  final int failed;

  /// Unsynced rows left after the pass (failures plus anything not attempted).
  final int remaining;

  /// True when no uploader was configured (e.g. Supabase not initialized),
  /// so nothing could be attempted.
  final bool offline;

  bool get allSynced => failed == 0 && remaining == 0;
}

/// Drains the local pending-upload queue into the cloud `screenings` table.
///
/// Each session is uploaded independently: a successful row is marked
/// `synced = 1` immediately, while a failed row keeps `synced = 0` so it is
/// retried on the next pass (e.g. when connectivity returns). No connectivity
/// gate is applied here — callers invoke [syncPending] when online.
class SyncRepository {
  SyncRepository({
    ScreeningUploader? uploader,
    ConsentLogUploader? consentUploader,
    SessionRepository? sessions,
  }) : _uploader = uploader ?? _defaultUploader(),
       _consentUploader =
           consentUploader ??
           (uploader is ConsentLogUploader
               ? uploader as ConsentLogUploader
               : _defaultConsentUploader()),
       _sessions = sessions ?? SessionRepository();

  final ScreeningUploader? _uploader;
  final ConsentLogUploader? _consentUploader;
  final SessionRepository _sessions;

  /// Uses the initialized global Supabase client, or null when Supabase has
  /// not been initialized yet (no project credentials are configured).
  static ScreeningUploader? _defaultUploader() {
    try {
      return SupabaseScreeningUploader(Supabase.instance.client);
    } catch (_) {
      return null;
    }
  }

  static ConsentLogUploader? _defaultConsentUploader() {
    try {
      return SupabaseScreeningUploader(Supabase.instance.client);
    } catch (_) {
      return null;
    }
  }

  /// Number of sessions waiting in the upload queue.
  Future<int> pendingCount() => _sessions.getUnsyncedCount();

  /// Attempts to upload every unsynced session once.
  ///
  /// Returns a [SyncResult] summarizing the pass. Never throws for
  /// per-session upload failures — those sessions simply remain queued.
  Future<SyncResult> syncPending() async {
    final pending = await _sessions.getUnsyncedSessions();
    final uploader = _uploader;
    if (uploader == null) {
      return SyncResult(
        attempted: 0,
        uploaded: 0,
        failed: 0,
        remaining: pending.length,
        offline: true,
      );
    }

    var uploaded = 0;
    var failed = 0;
    for (final session in pending) {
      try {
        await uploader.upload(session);
        await _sessions.markSynced(session.id);
        uploaded++;
      } catch (_) {
        failed++;
      }
    }

    final consentUploader = _consentUploader;
    if (consentUploader != null) {
      for (final log in await _sessions.getUnsyncedConsentLogs()) {
        try {
          await consentUploader.uploadConsentLog(log);
          await _sessions.markConsentLogSynced(log.id);
        } catch (_) {
          // Keep the local consent audit record queued for the next pass.
        }
      }
    }

    return SyncResult(
      attempted: pending.length,
      uploaded: uploaded,
      failed: failed,
      remaining: await _sessions.getUnsyncedCount(),
    );
  }
}
