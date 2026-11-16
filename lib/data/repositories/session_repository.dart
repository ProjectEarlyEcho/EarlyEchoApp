import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:sqflite/sqflite.dart';

import '../local/database_helper.dart';
import '../models/session_model.dart';
import 'sync_conflict.dart';

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
    this.ownerId,
    this.synced = false,
  });

  final String id;
  final String? ownerId;

  /// Null until the screening session row is created and linked.
  final String? sessionId;
  final String? anganwadiId;
  final String? workerName;
  final DateTime consentedAt;
  final bool synced;

  Map<String, dynamic> toMap() => {
    'id': id,
    'owner_id': ownerId,
    'session_id': sessionId,
    'anganwadi_id': anganwadiId,
    'worker_name': workerName,
    'consented_at': consentedAt.toUtc().toIso8601String(),
    'synced': synced ? 1 : 0,
  };

  factory ConsentLog.fromMap(Map<String, dynamic> map) => ConsentLog(
    id: map['id'] as String,
    ownerId: map['owner_id'] as String?,
    sessionId: map['session_id'] as String?,
    anganwadiId: map['anganwadi_id'] as String?,
    workerName: map['worker_name'] as String?,
    consentedAt: DateTime.parse(map['consented_at'] as String),
    synced: (map['synced'] as num) == 1,
  );

  /// Row shape for the Supabase `consent_logs` audit table.
  Map<String, dynamic> toJson() => {
    'id': id,
    'created_by': ownerId,
    'session_id': sessionId,
    'anganwadi_id': anganwadiId,
    'worker_name': workerName,
    'consented_at': consentedAt.toUtc().toIso8601String(),
  };
}

/// An immutable owner-bound view of local screening and consent records.
/// Null ownership is the offline-only partition, never adopted at sign-in.
/// Completed records are append-only: identical saves replay without changing
/// sync state; different content under an existing ID raises a conflict.
class SessionRepository {
  SessionRepository({DatabaseHelper? helper, this.ownerId})
    : _helper = helper ?? DatabaseHelper.instance {
    if (ownerId == DatabaseHelper.legacyOwnerId) {
      throw ArgumentError(
        'Legacy records require explicit ownership recovery.',
      );
    }
  }

  final DatabaseHelper _helper;
  final String? ownerId;
  String get _ownerFilter =>
      ownerId == null ? 'owner_id IS NULL' : 'owner_id = ?';
  List<String> get _ownerArgs => ownerId == null ? [] : [ownerId!];

  /// Saves the result and links its consent atomically, including on replay.
  Future<void> saveSession(SessionModel session, {String? consentLogId}) async {
    final db = await _helper.database;
    await db.transaction((txn) async {
      await _insertImmutable(
        txn,
        DatabaseHelper.tableSessions,
        _owned(session.toMap()),
      );
      if (consentLogId != null) {
        await _attachConsent(txn, consentLogId, session.id);
      }
    });
  }

  Future<SessionModel?> getSessionById(String id) async {
    final db = await _helper.database;
    final maps = await db.query(
      DatabaseHelper.tableSessions,
      where: 'id = ? AND $_ownerFilter',
      whereArgs: [id, ..._ownerArgs],
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
      where: _ownerFilter,
      whereArgs: _ownerArgs,
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
      where: 'synced = 0 AND $_ownerFilter',
      whereArgs: _ownerArgs,
      orderBy: 'session_date ASC',
    );
    return maps.map(SessionModel.fromMap).toList();
  }

  Future<int> getUnsyncedCount() async {
    final db = await _helper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM ${DatabaseHelper.tableSessions} WHERE synced = 0 AND $_ownerFilter',
      _ownerArgs,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Acknowledge exactly the uploaded snapshot, not a newer/recreated row.
  Future<void> markSynced(SessionModel snapshot) =>
      _acknowledge(DatabaseHelper.tableSessions, snapshot.toMap());

  Future<void> deleteSession(String sessionId) async {
    final db = await _helper.database;
    await db.delete(
      DatabaseHelper.tableSessions,
      where: 'id = ? AND $_ownerFilter',
      whereArgs: [sessionId, ..._ownerArgs],
    );
  }

  /// Records a parental-consent confirmation for the audit trail.
  Future<void> logConsent(ConsentLog log) async {
    final db = await _helper.database;
    await db.transaction((txn) async {
      if (log.sessionId != null) await _requireSession(txn, log.sessionId!);
      await _insertImmutable(
        txn,
        DatabaseHelper.tableConsentLogs,
        _owned(log.toMap()),
      );
    });
  }

  /// Backfills `session_id` on a consent log written before its session row
  /// existed, once the screening completes and the session is persisted.
  Future<void> attachConsentLogToSession(
    String consentLogId,
    String sessionId,
  ) async {
    final db = await _helper.database;
    await db.transaction((txn) => _attachConsent(txn, consentLogId, sessionId));
  }

  /// Linked consent queue, including records awaiting their screening upload.
  Future<List<ConsentLog>> getUnsyncedConsentLogs() async {
    final db = await _helper.database;
    final maps = await db.query(
      DatabaseHelper.tableConsentLogs,
      where: 'synced = 0 AND session_id IS NOT NULL AND $_ownerFilter',
      whereArgs: _ownerArgs,
      orderBy: 'consented_at ASC',
    );
    return maps.map(ConsentLog.fromMap).toList();
  }

  /// Marks a consent audit record as uploaded after a successful cloud write.
  Future<void> markConsentLogSynced(ConsentLog snapshot) =>
      _acknowledge(DatabaseHelper.tableConsentLogs, snapshot.toMap());

  Future<List<ConsentLog>> getConsentLogsForSession(String sessionId) async {
    final db = await _helper.database;
    final maps = await db.query(
      DatabaseHelper.tableConsentLogs,
      where: 'session_id = ? AND $_ownerFilter',
      whereArgs: [sessionId, ..._ownerArgs],
      orderBy: 'consented_at ASC',
    );
    return maps.map(ConsentLog.fromMap).toList();
  }

  Map<String, dynamic> _owned(Map<String, dynamic> row) {
    if (row['owner_id'] != null && row['owner_id'] != ownerId) {
      throw StateError('The record belongs to a different account.');
    }
    return {...row, 'owner_id': ownerId, 'synced': 0};
  }

  Future<void> _insertImmutable(
    Transaction txn,
    String table,
    Map<String, dynamic> row,
  ) async {
    final existing = await txn.query(
      table,
      where: 'id = ?',
      whereArgs: [row['id']],
    );
    if (existing.isNotEmpty) {
      if (!_sameRecord(existing.single, row)) {
        throw SyncConflictException(table, row['id'] as String);
      }
      return;
    }
    await txn.insert(table, row);
  }

  Future<void> _requireSession(Transaction txn, String sessionId) async {
    final sessions = await txn.query(
      DatabaseHelper.tableSessions,
      columns: ['id'],
      where: 'id = ? AND $_ownerFilter',
      whereArgs: [sessionId, ..._ownerArgs],
    );
    if (sessions.isEmpty) throw StateError('No screening for this account.');
  }

  Future<void> _attachConsent(
    Transaction txn,
    String consentLogId,
    String sessionId,
  ) async {
    await _requireSession(txn, sessionId);
    final rows = await txn.query(
      DatabaseHelper.tableConsentLogs,
      where: 'id = ? AND $_ownerFilter',
      whereArgs: [consentLogId, ..._ownerArgs],
    );
    if (rows.isEmpty) throw StateError('No consent record for this account.');
    final log = rows.single;
    if (log['session_id'] == sessionId) return;
    if (log['session_id'] != null || log['synced'] == 1) {
      throw SyncConflictException(
        DatabaseHelper.tableConsentLogs,
        consentLogId,
      );
    }
    await txn.update(
      DatabaseHelper.tableConsentLogs,
      {'session_id': sessionId},
      where: 'id = ? AND $_ownerFilter',
      whereArgs: [consentLogId, ..._ownerArgs],
    );
  }

  Future<void> _acknowledge(String table, Map<String, dynamic> snapshot) async {
    if (snapshot['owner_id'] != ownerId) {
      throw StateError('Wrong acknowledgement owner.');
    }
    final db = await _helper.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        table,
        where: 'id = ? AND $_ownerFilter',
        whereArgs: [snapshot['id'], ..._ownerArgs],
      );
      if (rows.isEmpty || !_sameRecord(rows.single, snapshot)) {
        throw SyncConflictException(table, snapshot['id'] as String);
      }
      await txn.update(
        table,
        {'synced': 1},
        where: 'id = ? AND $_ownerFilter',
        whereArgs: [snapshot['id'], ..._ownerArgs],
      );
    });
  }

  static bool _sameRecord(
    Map<String, dynamic> first,
    Map<String, dynamic> second,
  ) {
    Map<String, dynamic> content(Map<String, dynamic> row) {
      final value = {...row}..remove('synced');
      if (value['decision_trace'] is String) {
        value['decision_trace'] = jsonDecode(value['decision_trace'] as String);
      }
      return value;
    }

    return const DeepCollectionEquality().equals(
      content(first),
      content(second),
    );
  }
}
