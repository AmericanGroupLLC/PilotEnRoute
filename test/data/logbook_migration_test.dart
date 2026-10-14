/// The v1 -> v2 logbook migration on a real SQLite database
/// (sqflite_common_ffi), seeded with rows in the exact v1 schema.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/core/logbook/logbook_entry.dart';
import 'package:pilot_enroute/core/minimums/go_check.dart';
import 'package:pilot_enroute/core/minimums/go_record.dart';
import 'package:pilot_enroute/data/logbook_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;
  late Directory dir;
  late String path;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('pilot_logbook_test');
    path = '${dir.path}/pilot_logbook.db';
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  Future<void> seedV1(List<Map<String, Object?>> rows) async {
    final db = await factory.openDatabase(path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) => createV1Schema(db),
        ));
    for (final r in rows) {
      await db.insert('logbook_entries', r);
    }
    await db.close();
  }

  final v1Rows = <Map<String, Object?>>[
    {
      'date': '2026-09-01T00:00:00.000',
      'aircraft_type': 'C172',
      'tail_number': 'N12345',
      'from_airport': 'KPAO',
      'to_airport': 'KSQL',
      'total_time': 1.3,
      'pic_time': 1.3,
      'day_takeoffs': 3,
      'day_landings': 3,
      'night_landings': 0,
      'approaches': 2,
      'remarks': 'Pattern, "gusty", 3 T&G',
      'conditions': 'VMC',
    },
    {
      'date': '2026-09-15T00:00:00.000',
      'aircraft_type': 'PA28',
      'tail_number': 'N55PA',
      'from_airport': 'KSQL',
      'to_airport': 'KHAF',
      'total_time': 0.9,
      'night': 0.9,
      'night_takeoffs': 1,
      'night_landings': 1,
    },
    {
      'date': '2026-10-01T00:00:00.000',
      'aircraft_type': 'C152',
      'tail_number': 'N1',
      'from_airport': 'KHAF',
      'to_airport': 'KPAO',
      'total_time': 0.0,
    },
  ];

  test('every v1 row survives the upgrade with its values', () async {
    await seedV1(v1Rows);
    final db = await openLogbookDatabase(factory, path);
    expect(await db.getVersion(), 2);
    final store = SqfliteLogbookStore(db);
    final rows = await store.allEntries();
    expect(rows, hasLength(3));
    final first = rows.firstWhere((e) => e.tailNumber == 'N12345');
    expect(first.totalTime, 1.3);
    expect(first.picTime, 1.3);
    expect(first.dayLandings, 3);
    expect(first.approaches, 2);
    expect(first.remarks, 'Pattern, "gusty", 3 T&G');
    final night = rows.firstWhere((e) => e.tailNumber == 'N55PA');
    expect(night.night, 0.9);
    expect(night.nightLandings, 1);
    await db.close();
  });

  test('new columns get honest defaults on old rows', () async {
    await seedV1(v1Rows);
    final db = await openLogbookDatabase(factory, path);
    final rows = await SqfliteLogbookStore(db).allEntries();
    for (final e in rows) {
      expect(e.categoryClass, '', reason: 'never guessed as ASEL');
      expect(e.tailwheel, isFalse);
      expect(e.holding, isFalse);
      expect(e.flightReview, isFalse);
      expect(e.conditions, 'VFR');
    }
    final cols = await db.rawQuery('PRAGMA table_info(logbook_entries)');
    final names = cols.map((c) => c['name']).toSet();
    for (final c in v2Columns) {
      expect(names, contains(c.split(' ').first));
    }
    await db.close();
  });

  test('0.0 total time stays 0.0, not null', () async {
    await seedV1(v1Rows);
    final db = await openLogbookDatabase(factory, path);
    final rows = await SqfliteLogbookStore(db).allEntries();
    expect(rows.firstWhere((e) => e.tailNumber == 'N1').totalTime, 0.0);
    await db.close();
  });

  test('the Go check history table exists after the upgrade', () async {
    await seedV1(v1Rows);
    final db = await openLogbookDatabase(factory, path);
    final store = SqfliteLogbookStore(db);
    final id = await store.insertCheck(GoCheckRecord(
      createdAt: DateTime(2026, 10, 14, 13),
      departure: 'KPAO',
      destination: '',
      plannedAt: DateTime(2026, 10, 14, 14),
      passengers: true,
      night: false,
      ifr: false,
      categoryClass: 'ASEL',
      verdict: GoVerdict.inside,
      headline: 'Inside your minimums and legal for this flight',
      metarRaw: 'METAR KPAO ...',
      tafRaw: '',
      detail: 'x',
    ));
    final checks = await store.allChecks();
    expect(checks.single.id, id);
    expect(checks.single.verdict, GoVerdict.inside);
    await store.deleteCheck(id);
    expect(await store.allChecks(), isEmpty);
    await db.close();
  });

  test('a fresh install creates v2 directly and round-trips an entry',
      () async {
    final db = await openLogbookDatabase(factory, path);
    final store = SqfliteLogbookStore(db);
    final e = LogbookEntry(
      date: DateTime(2026, 10, 14),
      aircraftType: 'C172',
      tailNumber: 'N9',
      from: 'KPAO',
      to: 'KPAO',
      totalTime: 1.1,
      categoryClass: 'ASEL',
      tailwheel: true,
      dayLandings: 3,
      dayFullStopLandings: 3,
      holding: true,
      ipc: true,
    );
    final id = await store.insertEntry(e);
    final back = (await store.allEntries()).single;
    expect(back.id, id);
    expect(back.toMap()..remove('id'), e.toMap()..remove('id'));
    await store.updateEntry(back.copyWith(remarks: 'edited'));
    expect((await store.allEntries()).single.remarks, 'edited');
    await store.deleteEntry(id);
    expect(await store.allEntries(), isEmpty);
    await db.close();
  });

  test('re-opening a v2 database changes nothing', () async {
    await seedV1(v1Rows);
    (await openLogbookDatabase(factory, path)).close();
    final db = await openLogbookDatabase(factory, path);
    expect(await SqfliteLogbookStore(db).allEntries(), hasLength(3));
    await db.close();
  });
}
