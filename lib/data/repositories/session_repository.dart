import 'package:sqflite/sqflite.dart';

import '../local/database_helper.dart';
import '../models/session_model.dart';

/// A timestamped parental-consent confirmation tied to a screening session.
///
/// Written when the worker taps "माता-पिता ने सहमति दी" on the consent screen;
/// replayed to the cloud `consent_logs` audit table during sync.
///
/// Consent is confirmed before the session row exists, so [sessionId] starts
/// null and is backfilled via [SessionRepository.attachConsentLogToSession]
/// once the screening completes and the session is persisted.
class ConsentLog {
  const ConsentLog({
    required this.id,
    required this.sessionId,
    required this.consentedAt,
    this.anganwadiId,
    this.workerName,
    this.synced = false,
  });

  final String id;

  /// Null until the screening session row is created and linked.
  final String? sessionId;
  final String? anganwadiId;
  final String? workerName;
  final DateTime consentedAt;
  final bool synced;

  Map<String, dynamic> toMap() => {
    'id': id,
    'session_id': sessionId,
    'anganwadi_id': anganwadiId,
    'worker_name': workerName,
    'consented_at': consentedAt.toIso8601String(),
    'synced': synced ? 1 : 0,
  };

  factory ConsentLog.fromMap(Map<String, dynamic> map) => ConsentLog(
    id: map['id'] as String,
    sessionId: map['session_id'] as String?,
    anganwadiId: map['anganwadi_id'] as String?,
    workerName: map['worker_name'] as String?,
    consentedAt: DateTime.parse(map['consented_at'] as String),
    synced: (map['synced'] as num) == 1,
  );

  /// Row shape for the Supabase `consent_logs` audit table.
  Map<String, dynamic> toJson() => {
    'id': id,
    'session_id': sessionId,
    'anganwadi_id': anganwadiId,
    'worker_name': workerName,
    'consented_at': consentedAt.toIso8601String(),
  };
}

/// CRUD access to the local `sessions` and `consent_logs` tables.
///
/// The repository talks to [DatabaseHelper]; tests inject a helper backed by
/// an in-memory `sqflite_common_ffi` database.
class SessionRepository {
  SessionRepository({DatabaseHelper? helper})
    : _helper = helper ?? DatabaseHelper.instance;

  final DatabaseHelper _helper;

  /// Inserts or replaces a screening session.
  Future<void> saveSession(SessionModel session) async {
    final db = await _helper.database;
    await db.insert(
      DatabaseHelper.tableSessions,
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<SessionModel?> getSessionById(String id) async {
    final db = await _helper.database;
    final maps = await db.query(
      DatabaseHelper.tableSessions,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return SessionModel.fromMap(maps.first);
  }

  /// All stored sessions, newest first.
  Future<List<SessionModel>> getAllSessions() async {
    final db = await _helper.database;
    final maps = await db.query(
      DatabaseHelper.tableSessions,
      orderBy: 'session_date DESC',
    );
    return maps.map(SessionModel.fromMap).toList();
  }

  /// Sessions still waiting to be uploaded, oldest first so the queue
  /// drains in recording order.
  Future<List<SessionModel>> getUnsyncedSessions() async {
    final db = await _helper.database;
    final maps = await db.query(
      DatabaseHelper.tableSessions,
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'session_date ASC',
    );
    return maps.map(SessionModel.fromMap).toList();
  }

  Future<int> getUnsyncedCount() async {
    final db = await _helper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM ${DatabaseHelper.tableSessions} WHERE synced = 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Flips the `synced` flag after a successful cloud upload.
  Future<void> markSynced(String sessionId) async {
    final db = await _helper.database;
    await db.update(
      DatabaseHelper.tableSessions,
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> deleteSession(String sessionId) async {
    final db = await _helper.database;
    await db.delete(
      DatabaseHelper.tableSessions,
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  /// Records a parental-consent confirmation for the audit trail.
  Future<void> logConsent(ConsentLog log) async {
    final db = await _helper.database;
    await db.insert(
      DatabaseHelper.tableConsentLogs,
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Backfills `session_id` on a consent log written before its session row
  /// existed, once the screening completes and the session is persisted.
  Future<void> attachConsentLogToSession(
    String consentLogId,
    String sessionId,
  ) async {
    final db = await _helper.database;
    await db.update(
      DatabaseHelper.tableConsentLogs,
      {'session_id': sessionId},
      where: 'id = ?',
      whereArgs: [consentLogId],
    );
  }

  Future<List<ConsentLog>> getConsentLogsForSession(String sessionId) async {
    final db = await _helper.database;
    final maps = await db.query(
      DatabaseHelper.tableConsentLogs,
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'consented_at ASC',
    );
    return maps.map(ConsentLog.fromMap).toList();
  }
}
