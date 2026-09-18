import 'dart:io';

import 'package:earlyecho/data/local/database_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  Future<List<Map<String, Object?>>> consentLogColumns(Database db) {
    return db.rawQuery('PRAGMA table_info(${DatabaseHelper.tableConsentLogs})');
  }

  test('fresh databases open at v3 with a nullable session link', () async {
    final helper = DatabaseHelper(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    addTearDown(helper.close);
    final db = await helper.database;

    expect(DatabaseHelper.databaseVersion, 3);
    expect(await db.getVersion(), 3);

    final columns = await consentLogColumns(db);
    final sessionCol = columns.firstWhere((c) => c['name'] == 'session_id');
    expect(sessionCol['notnull'], 0);

    // A consent row can be written before its session exists.
    await db.insert(DatabaseHelper.tableConsentLogs, {
      'id': 'c-1',
      'session_id': null,
      'consented_at': DateTime.utc(2026, 9, 18).toIso8601String(),
    });
  });

  test('v1 databases migrate to v3 keeping consent rows intact', () async {
    final path = p.join(
      Directory.systemTemp.path,
      'earlyecho_v1_upgrade_test.db',
    );
    await databaseFactoryFfi.deleteDatabase(path);
    addTearDown(() => databaseFactoryFfi.deleteDatabase(path));

    // Recreate the original v1 schema, where session_id was NOT NULL.
    final v1 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE sessions (
              id TEXT PRIMARY KEY,
              anganwadi_id TEXT NOT NULL,
              state_code TEXT NOT NULL,
              worker_name TEXT,
              child_name TEXT,
              child_age_months INTEGER NOT NULL,
              session_date TEXT NOT NULL,
              risk_level TEXT NOT NULL,
              vttl_ms REAL,
              pfv_std REAL,
              cvr_ratio REAL,
              vttl_flagged INTEGER,
              pfv_flagged INTEGER,
              cvr_flagged INTEGER,
              audio_source TEXT,
              synced INTEGER DEFAULT 0,
              district_code TEXT,
              decision_trace TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE consent_logs (
              id TEXT PRIMARY KEY,
              session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
              anganwadi_id TEXT,
              worker_name TEXT,
              consented_at TEXT NOT NULL,
              synced INTEGER NOT NULL DEFAULT 0
            )
          ''');
        },
      ),
    );
    await v1.insert('sessions', {
      'id': 's-1',
      'anganwadi_id': 'AW-001',
      'state_code': 'BR',
      'child_age_months': 30,
      'session_date': '2026-09-18T10:00:00.000Z',
      'risk_level': 'yellow',
    });
    await v1.insert('consent_logs', {
      'id': 'c-old',
      'session_id': 's-1',
      'anganwadi_id': 'AW-001',
      'consented_at': '2026-09-18T09:55:00.000Z',
    });
    await v1.close();

    // Reopening through the helper runs the v1 -> v3 migration.
    final helper = DatabaseHelper(
      factory: databaseFactoryFfi,
      databasePath: path,
    );
    addTearDown(helper.close);
    final db = await helper.database;

    expect(await db.getVersion(), 3);
    final columns = await consentLogColumns(db);
    final sessionCol = columns.firstWhere((c) => c['name'] == 'session_id');
    expect(sessionCol['notnull'], 0);
    final sessionColumns = await db.rawQuery('PRAGMA table_info(sessions)');
    expect(
      sessionColumns.any((column) => column['name'] == 'cloud_child_id'),
      isTrue,
    );

    // The pre-existing consent row survived the table rebuild.
    final migrated = await db.query(DatabaseHelper.tableConsentLogs);
    expect(migrated, hasLength(1));
    expect(migrated.single['id'], 'c-old');
    expect(migrated.single['session_id'], 's-1');

    // New rows may omit session_id, and the FK still cascades deletes.
    await db.insert(DatabaseHelper.tableConsentLogs, {
      'id': 'c-new',
      'session_id': null,
      'consented_at': '2026-09-18T11:00:00.000Z',
    });
    await db.delete('sessions', where: 'id = ?', whereArgs: ['s-1']);
    final remaining = await db.query(DatabaseHelper.tableConsentLogs);
    expect(remaining, hasLength(1));
    expect(remaining.single['id'], 'c-new');
  });
}
