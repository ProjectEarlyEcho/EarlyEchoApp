import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Owns the on-device SQLite database for EarlyEcho.
///
/// Two tables are created at version 1:
/// - `sessions`: one row per completed screening, matching the columns in the
///   domain spec so rows can be replayed to the cloud `screenings` table.
/// - `consent_logs`: timestamped parental-consent audit entries, one per
///   consent confirmation made on the consent screen.
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
  static const int databaseVersion = 1;

  static const String tableSessions = 'sessions';
  static const String tableConsentLogs = 'consent_logs';

  final DatabaseFactory? _factory;
  final String? _databasePath;

  Database? _database;

  Future<Database> get database async => _database ??= await _open();

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

  /// Version 1 schema: the screening `sessions` table plus the
  /// `consent_logs` audit table.
  static Future<void> onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableSessions (
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
      CREATE TABLE $tableConsentLogs (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL REFERENCES $tableSessions(id) ON DELETE CASCADE,
        anganwadi_id TEXT,
        worker_name TEXT,
        consented_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  /// Future schema migrations land here, gated on [oldVersion].
  static Future<void> onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {}

  /// Closes the handle so tests or teardown can reopen a clean database.
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
