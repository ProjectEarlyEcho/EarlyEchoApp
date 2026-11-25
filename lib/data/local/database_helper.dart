import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Owns the on-device SQLite database for EarlyEcho.
///
/// Two tables are maintained:
/// - `sessions`: one row per completed screening, matching the columns in the
///   domain spec so rows can be replayed to the cloud `screenings` table.
/// - `consent_logs`: timestamped parental-consent audit entries, one per
///   consent confirmation made on the consent screen.
///
/// Version history:
/// - v1: initial `sessions` + `consent_logs` schema.
/// - v2: `consent_logs.session_id` becomes nullable — consent is confirmed
///   before the session row exists, so the link is backfilled later.
/// - v3: owner partitions or cloud-child links in independently shipped builds.
/// - v4: both owner partitions and cloud-child links. Records without a recorded
///   owner are retained in quarantine; existing ownership is preserved.
///
/// The default [instance] opens `earlyecho.db` in the app documents area.
/// Tests can inject a different [DatabaseFactory] (e.g. `databaseFactoryFfi`)
/// and path via the named constructor.
class DatabaseHelper {
  DatabaseHelper({DatabaseFactory? factory, String? databasePath})
    : _factory = factory,
      _databasePath = databasePath;

  /// Shared helper used by the app. Lazily opens the database on first use.
  static final DatabaseHelper instance = DatabaseHelper();

  static const String databaseName = 'earlyecho.db';
  static const int databaseVersion = 4;
  static const String legacyOwnerId = 'legacy-unassigned';

  static const String tableSessions = 'sessions';
  static const String tableConsentLogs = 'consent_logs';

  final DatabaseFactory? _factory;
  final String? _databasePath;

  Database? _database;
  Future<Database>? _opening;

  Future<Database> get database async {
    if (_database != null) return _database!;
    try {
      return _database = await (_opening ??= _open());
    } finally {
      _opening = null;
    }
  }

  Future<Database> _open() async {
    final factory = _factory ?? databaseFactory;
    final path =
        _databasePath ?? join(await factory.getDatabasesPath(), databaseName);

    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: databaseVersion,
        onConfigure: _onConfigure,
        onCreate: onCreate,
        onUpgrade: onUpgrade,
      ),
    );
  }

  /// Enables foreign-key enforcement (off by default in SQLite) so
  /// `consent_logs.session_id` stays consistent with `sessions`.
  static Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Latest schema: the screening `sessions` table plus the
  /// `consent_logs` audit table.
  static Future<void> onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableSessions (
        id TEXT PRIMARY KEY,
        owner_id TEXT,
        anganwadi_id TEXT NOT NULL,
        state_code TEXT NOT NULL,
        worker_name TEXT,
        child_name TEXT,
        cloud_child_id TEXT,
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
      CREATE TABLE $tableConsentLogs (
        id TEXT PRIMARY KEY,
        owner_id TEXT,
        session_id TEXT REFERENCES $tableSessions(id) ON DELETE CASCADE,
        anganwadi_id TEXT,
        worker_name TEXT,
        consented_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await _createOwnerIndexes(db);
  }

  static Future<void> _createOwnerIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS sessions_owner_queue ON sessions(owner_id, synced, session_date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS consent_owner_queue ON consent_logs(owner_id, synced, session_id)',
    );
  }

  /// Schema migrations, gated on [oldVersion].
  static Future<void> onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      // Consent is confirmed before the session row exists, so v2 makes
      // `session_id` nullable for the later backfill. SQLite cannot relax a
      // NOT NULL column in place — rebuild the table instead: create the new
      // shape, copy the rows across, drop the old table, then rename.
      await db.execute('''
        CREATE TABLE consent_logs_new (
          id TEXT PRIMARY KEY,
          session_id TEXT REFERENCES $tableSessions(id) ON DELETE CASCADE,
          anganwadi_id TEXT,
          worker_name TEXT,
          consented_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute('''
        INSERT INTO consent_logs_new (
          id, session_id, anganwadi_id, worker_name, consented_at, synced
        )
        SELECT id, session_id, anganwadi_id, worker_name, consented_at, synced
        FROM $tableConsentLogs
      ''');
      await db.execute('DROP TABLE $tableConsentLogs');
      await db.execute(
        'ALTER TABLE consent_logs_new RENAME TO $tableConsentLogs',
      );
    }
    if (oldVersion < 4) {
      // Both v3 schemas exist in released branches. Inspect the shape instead
      // of guessing from the version or assigning legacy records to a login.
      for (final table in [tableSessions, tableConsentLogs]) {
        final columns = await db.rawQuery('PRAGMA table_info($table)');
        if (!columns.any((column) => column['name'] == 'owner_id')) {
          await db.execute('ALTER TABLE $table ADD COLUMN owner_id TEXT');
          await db.update(table, {'owner_id': legacyOwnerId});
        }
      }
      await _createOwnerIndexes(db);
      final columns = await db.rawQuery('PRAGMA table_info($tableSessions)');
      if (!columns.any((column) => column['name'] == 'cloud_child_id')) {
        await db.execute(
          'ALTER TABLE $tableSessions ADD COLUMN cloud_child_id TEXT',
        );
      }
    }
  }

  /// Closes the handle so tests or teardown can reopen a clean database.
  Future<void> close() async {
    await _opening;
    await _database?.close();
    _database = null;
  }
}
