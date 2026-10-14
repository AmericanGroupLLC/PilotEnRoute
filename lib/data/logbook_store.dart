/// Where logbook entries and Go checks live: SQLite on the device, or memory
/// (web and widget tests). Nothing is ever sent anywhere.
library;

import 'package:sqflite/sqflite.dart';

import '../core/logbook/logbook_entry.dart';
import '../core/minimums/go_record.dart';

abstract class LogbookStore {
  Future<List<LogbookEntry>> allEntries();
  Future<int> insertEntry(LogbookEntry e);
  Future<void> updateEntry(LogbookEntry e);
  Future<void> deleteEntry(int id);
  Future<List<GoCheckRecord>> allChecks();
  Future<int> insertCheck(GoCheckRecord r);
  Future<void> deleteCheck(int id);
}

class MemoryLogbookStore implements LogbookStore {
  MemoryLogbookStore([List<LogbookEntry> seed = const []]) {
    for (final e in seed) {
      _entries.add(e.copyWith(id: _nextEntry++));
    }
  }

  final List<LogbookEntry> _entries = [];
  final List<GoCheckRecord> _checks = [];
  int _nextEntry = 1;
  int _nextCheck = 1;

  @override
  Future<List<LogbookEntry>> allEntries() async =>
      [..._entries]..sort((a, b) => b.date.compareTo(a.date));

  @override
  Future<int> insertEntry(LogbookEntry e) async {
    final id = _nextEntry++;
    _entries.add(e.copyWith(id: id));
    return id;
  }

  @override
  Future<void> updateEntry(LogbookEntry e) async {
    final i = _entries.indexWhere((x) => x.id == e.id);
    if (i >= 0) _entries[i] = e;
  }

  @override
  Future<void> deleteEntry(int id) async =>
      _entries.removeWhere((e) => e.id == id);

  @override
  Future<List<GoCheckRecord>> allChecks() async =>
      [..._checks]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<int> insertCheck(GoCheckRecord r) async {
    final id = _nextCheck++;
    _checks.add(r.withId(id));
    return id;
  }

  @override
  Future<void> deleteCheck(int id) async =>
      _checks.removeWhere((r) => r.id == id);
}

/// Current schema version. v1 was the 22-column table the app shipped with
/// until October 2026; v2 adds what the legality engine and the entry form
/// need, plus the Go check history.
const int logbookSchemaVersion = 2;

const String _v1Table = '''
  CREATE TABLE logbook_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date TEXT NOT NULL,
    aircraft_type TEXT,
    tail_number TEXT,
    from_airport TEXT,
    to_airport TEXT,
    total_time REAL DEFAULT 0,
    pic_time REAL DEFAULT 0,
    sic_time REAL DEFAULT 0,
    dual_received REAL DEFAULT 0,
    cfi_given REAL DEFAULT 0,
    cross_country REAL DEFAULT 0,
    night REAL DEFAULT 0,
    actual_instrument REAL DEFAULT 0,
    simulated_instrument REAL DEFAULT 0,
    day_takeoffs INTEGER DEFAULT 0,
    day_landings INTEGER DEFAULT 0,
    night_takeoffs INTEGER DEFAULT 0,
    night_landings INTEGER DEFAULT 0,
    approaches INTEGER DEFAULT 0,
    remarks TEXT DEFAULT '',
    conditions TEXT DEFAULT 'VMC'
  )
''';

/// Columns added in v2, with their defaults. Existing rows get the default,
/// so nothing is invented: an old row has no category/class until the pilot
/// edits it.
const List<String> v2Columns = [
  "category_class TEXT DEFAULT ''",
  'tailwheel INTEGER DEFAULT 0',
  "route TEXT DEFAULT ''",
  'solo_time REAL DEFAULT 0',
  'day_full_stop_landings INTEGER DEFAULT 0',
  'holding INTEGER DEFAULT 0',
  'tracking INTEGER DEFAULT 0',
  'flight_review INTEGER DEFAULT 0',
  'ipc INTEGER DEFAULT 0',
  'practical_test INTEGER DEFAULT 0',
  'night_flight INTEGER DEFAULT 0',
];

const String _goChecksTable = '''
  CREATE TABLE go_checks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at TEXT NOT NULL,
    departure TEXT,
    destination TEXT,
    planned_at TEXT NOT NULL,
    passengers INTEGER DEFAULT 0,
    night INTEGER DEFAULT 0,
    ifr INTEGER DEFAULT 0,
    category_class TEXT DEFAULT '',
    verdict TEXT,
    headline TEXT,
    metar_raw TEXT DEFAULT '',
    taf_raw TEXT DEFAULT '',
    detail TEXT DEFAULT ''
  )
''';

/// The original v1 schema, kept so the migration can be tested against a
/// real v1 database.
Future<void> createV1Schema(Database db) => db.execute(_v1Table);

Future<void> _migrateV1toV2(DatabaseExecutor db) async {
  for (final col in v2Columns) {
    await db.execute('ALTER TABLE logbook_entries ADD COLUMN $col');
  }
  await db.execute(_goChecksTable);
}

/// Opens (creating or upgrading) the logbook database at [path].
Future<Database> openLogbookDatabase(DatabaseFactory factory, String path) {
  return factory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: logbookSchemaVersion,
      onCreate: (db, version) async {
        await db.execute(_v1Table);
        await _migrateV1toV2(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _migrateV1toV2(db);
      },
    ),
  );
}

class SqfliteLogbookStore implements LogbookStore {
  SqfliteLogbookStore(this.db);
  final Database db;

  @override
  Future<List<LogbookEntry>> allEntries() async {
    final rows = await db.query('logbook_entries', orderBy: 'date DESC');
    return rows.map(LogbookEntry.fromMap).toList();
  }

  @override
  Future<int> insertEntry(LogbookEntry e) {
    final m = e.toMap()..remove('id');
    return db.insert('logbook_entries', m);
  }

  @override
  Future<void> updateEntry(LogbookEntry e) async {
    final m = e.toMap()..remove('id');
    await db.update('logbook_entries', m, where: 'id = ?', whereArgs: [e.id]);
  }

  @override
  Future<void> deleteEntry(int id) async {
    await db.delete('logbook_entries', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<GoCheckRecord>> allChecks() async {
    final rows = await db.query('go_checks', orderBy: 'created_at DESC');
    return rows.map(GoCheckRecord.fromMap).toList();
  }

  @override
  Future<int> insertCheck(GoCheckRecord r) {
    final m = r.toMap()..remove('id');
    return db.insert('go_checks', m);
  }

  @override
  Future<void> deleteCheck(int id) async {
    await db.delete('go_checks', where: 'id = ?', whereArgs: [id]);
  }
}
