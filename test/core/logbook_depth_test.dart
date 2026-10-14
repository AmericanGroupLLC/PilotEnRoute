/// Logbook search, filters, month groups, window totals, CSV and the entry
/// form's field rules.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/core/logbook/entry_validation.dart';
import 'package:pilot_enroute/core/logbook/logbook_csv.dart';
import 'package:pilot_enroute/core/logbook/logbook_entry.dart';
import 'package:pilot_enroute/core/logbook/logbook_query.dart';

LogbookEntry f(
  DateTime d, {
  String from = 'KPAO',
  String to = 'KSQL',
  String tail = 'N123AB',
  String type = 'C172',
  String cc = 'ASEL',
  double total = 1.0,
  double night = 0,
  int approaches = 0,
  bool flightReview = false,
  bool ipc = false,
  String remarks = '',
  String route = '',
  String conditions = 'VFR',
}) =>
    LogbookEntry(
      date: d,
      aircraftType: type,
      tailNumber: tail,
      from: from,
      to: to,
      route: route,
      totalTime: total,
      categoryClass: cc,
      night: night,
      approaches: approaches,
      flightReview: flightReview,
      ipc: ipc,
      remarks: remarks,
      conditions: conditions,
    );

void main() {
  final book = [
    f(DateTime(2026, 10, 12), remarks: 'Pattern work, 3 full stops'),
    f(DateTime(2026, 10, 2), from: 'KSQL', to: 'KHAF', tail: 'N55PA', type: 'PA28'),
    f(DateTime(2026, 9, 20), cc: 'AMEL', type: 'PA44', tail: 'N44SE', night: 1.2),
    f(DateTime(2026, 8, 5), approaches: 3, conditions: 'IFR', route: 'SUNOL V334 OAK'),
    f(DateTime(2026, 3, 1), flightReview: true, remarks: 'BFR with Sam'),
    f(DateTime(2025, 12, 30), ipc: true, from: 'KSJC', to: 'KSJC'),
  ];

  group('search', () {
    List<String> hits(String q) =>
        filterEntries(book, LogbookQuery(text: q)).map((e) => e.tailNumber + e.date.month.toString()).toList();

    test('by airport, either end', () {
      expect(filterEntries(book, const LogbookQuery(text: 'khaf')), hasLength(1));
      expect(filterEntries(book, const LogbookQuery(text: 'KSQL')), hasLength(5));
    });
    test('by tail number', () {
      expect(hits('n55pa'), ['N55PA10']);
    });
    test('by aircraft type', () {
      expect(filterEntries(book, const LogbookQuery(text: 'PA44')).single.tailNumber,
          'N44SE');
    });
    test('by remarks, case-insensitive', () {
      expect(filterEntries(book, const LogbookQuery(text: 'bfr')).single.flightReview,
          isTrue);
    });
    test('by route', () {
      expect(filterEntries(book, const LogbookQuery(text: 'v334')), hasLength(1));
    });
    test('every word must match', () {
      expect(filterEntries(book, const LogbookQuery(text: 'KSQL PA28')), hasLength(1));
      expect(filterEntries(book, const LogbookQuery(text: 'KSQL PA44 KHAF')), isEmpty);
    });
    test('results are newest first', () {
      final r = filterEntries(book, LogbookQuery.all);
      expect(r.first.date, DateTime(2026, 10, 12));
      expect(r.last.date, DateTime(2025, 12, 30));
    });
  });

  group('filters', () {
    test('date range is inclusive at both ends', () {
      final r = filterEntries(
          book,
          LogbookQuery(
              from: DateTime(2026, 9, 20), to: DateTime(2026, 10, 2, 23)));
      expect(r.map((e) => e.date.day), [2, 20]);
    });
    test('category/class', () {
      expect(filterEntries(book, const LogbookQuery(categoryClass: 'AMEL')),
          hasLength(1));
    });
    test('night', () {
      expect(filterEntries(book, const LogbookQuery(night: true)).single.tailNumber,
          'N44SE');
    });
    test('IFR', () {
      expect(filterEntries(book, const LogbookQuery(ifr: true)), hasLength(1));
    });
    test('flight review and IPC flags', () {
      expect(filterEntries(book, const LogbookQuery(flightReview: true)), hasLength(1));
      expect(filterEntries(book, const LogbookQuery(ipc: true)).single.from, 'KSJC');
    });
    test('filters combine with search', () {
      expect(
          filterEntries(book,
              const LogbookQuery(text: 'KPAO', categoryClass: 'ASEL', ipc: true)),
          isEmpty);
    });
    test('filter count ignores the search text', () {
      expect(const LogbookQuery(text: 'x', night: true, ipc: true).filterCount, 2);
      expect(LogbookQuery.all.isActive, isFalse);
    });
  });

  group('month groups', () {
    test('newest month first, entries kept in order, hours summed', () {
      final g = groupByMonth(filterEntries(book, LogbookQuery.all));
      expect(g.map((m) => '${m.month.year}-${m.month.month}'),
          ['2026-10', '2026-9', '2026-8', '2026-3', '2025-12']);
      expect(g.first.entries, hasLength(2));
      expect(g.first.hours, 2.0);
    });
    test('an empty list has no groups', () {
      expect(groupByMonth(const []), isEmpty);
    });
  });

  group('window totals', () {
    final now = DateTime(2026, 10, 14, 18);
    final entries = [
      f(DateTime(2026, 10, 14), total: 1.0), // today
      f(DateTime(2026, 9, 15), total: 2.0), // 29 days ago
      f(DateTime(2026, 9, 14), total: 4.0), // 30 days ago
      f(DateTime(2026, 7, 17), total: 8.0), // 89 days ago
      f(DateTime(2026, 7, 16), total: 16.0), // 90 days ago
      f(DateTime(2025, 10, 15), total: 32.0), // 364 days ago
      f(DateTime(2025, 10, 14), total: 64.0), // 365 days ago
    ];
    test('30 days = today and the 29 before it', () {
      expect(totalsWithin(entries, now: now, days: 30).totalTime, 3.0);
    });
    test('90 days', () {
      expect(totalsWithin(entries, now: now, days: 90).totalTime, 15.0);
    });
    test('365 days', () {
      expect(totalsWithin(entries, now: now, days: 365).totalTime, 63.0);
    });
    test('all time', () {
      final t = totalsWithin(entries, now: now);
      expect(t.totalTime, 127.0);
      expect(t.totalFlights, 7);
    });
    test('a future-dated entry is not in any window', () {
      expect(
          totalsWithin([f(DateTime(2026, 10, 20))], now: now, days: 30)
              .totalFlights,
          0);
    });
  });

  group('CSV (RFC 4180)', () {
    test('plain fields are not quoted', () {
      expect(csvField('KPAO'), 'KPAO');
    });
    test('a comma is quoted', () {
      expect(csvField('Pattern, full stops'), '"Pattern, full stops"');
    });
    test('a double quote is doubled and quoted', () {
      expect(csvField('Called "tower"'), '"Called ""tower"""');
    });
    test('newlines are quoted', () {
      expect(csvField('line1\nline2'), '"line1\nline2"');
      expect(csvField('a\r\nb'), '"a\r\nb"');
    });
    test('header has one column per logbook field', () {
      expect(csvHeader, hasLength(32));
      expect(csvRow(book.first), hasLength(csvHeader.length));
    });
    test('records end in CRLF, oldest first, header first', () {
      final csv = logbookToCsv(book);
      final lines = csv.split('\r\n');
      expect(lines.first, startsWith('Date,Aircraft type,Tail number'));
      expect(lines[1], startsWith('2025-12-30,'));
      expect(csv.endsWith('\r\n'), isTrue);
      expect(lines.where((l) => l.isNotEmpty), hasLength(book.length + 1));
    });
    test('remarks with comma, quote and newline survive', () {
      final csv = logbookToCsv([
        f(DateTime(2026, 1, 1), remarks: 'Gusty, "fun"\nwent around'),
      ]);
      expect(csv, contains('"Gusty, ""fun""\nwent around"'));
    });
    test('hours are written with one decimal and flags as Y', () {
      final row = csvRow(f(DateTime(2026, 1, 1), total: 1.25, ipc: true));
      expect(row[8], '1.3');
      expect(row[csvHeader.indexOf('IPC')], 'Y');
      expect(row[csvHeader.indexOf('Flight review')], '');
    });
    test('an empty logbook is just the header', () {
      expect(logbookToCsv(const []).split('\r\n').where((l) => l.isNotEmpty),
          hasLength(1));
    });
  });

  group('entry form fields', () {
    test('empty hours mean 0, not an error', () {
      expect(parseHours('').value, 0);
      expect(parseHours('   ').ok, isTrue);
    });
    test('"0.0" is a real zero', () {
      expect(parseHours('0.0').value, 0);
    });
    test('a comma decimal is accepted', () {
      expect(parseHours('1,5').value, 1.5);
    });
    test('text and negatives are refused', () {
      expect(parseHours('abc').ok, isFalse);
      expect(parseHours('-1').ok, isFalse);
      expect(parseHours('25').ok, isFalse);
    });
    test('landings must be whole numbers', () {
      expect(parseCount('3').value, 3);
      expect(parseCount('').value, 0);
      expect(parseCount('2.5').ok, isFalse);
      expect(parseCount('-1').ok, isFalse);
    });
    test('total must be at least every sub-time', () {
      final errs = crossCheck(f(DateTime(2026, 1, 1), total: 1.0)
          .copyWith(picTime: 1.2, night: 0.5));
      expect(errs['pic'], 'PIC cannot exceed total time');
      expect(errs.containsKey('night'), isFalse);
    });
    test('actual plus simulated instrument cannot exceed total', () {
      final errs = crossCheck(f(DateTime(2026, 1, 1), total: 1.0)
          .copyWith(actualInstrument: 0.6, simulatedInstrument: 0.6));
      expect(errs['sim'], contains('Instrument time'));
    });
    test('full stops cannot exceed day landings', () {
      final errs = crossCheck(f(DateTime(2026, 1, 1))
          .copyWith(dayLandings: 1, dayFullStopLandings: 2));
      expect(errs['dayFullStop'], isNotNull);
    });
    test('total time, type and class are required', () {
      final errs = crossCheck(
          f(DateTime(2026, 1, 1), total: 0, type: '', cc: ''));
      expect(errs.keys, containsAll(['total', 'type', 'categoryClass']));
    });
    test('a sound entry has no errors', () {
      expect(
          crossCheck(f(DateTime(2026, 1, 1), total: 1.5)
              .copyWith(picTime: 1.5, night: 0.4, dayLandings: 2, dayFullStopLandings: 2)),
          isEmpty);
    });
  });

  group('entry model', () {
    test('every field survives a map round-trip', () {
      final e = f(DateTime(2026, 5, 6, 14, 30), route: 'V334')
          .copyWith(
            id: 7,
            tailwheel: true,
            picTime: 1,
            sicTime: 0.1,
            dualReceived: 0.2,
            soloTime: 0.3,
            cfiGiven: 0.4,
            crossCountry: 0.5,
            night: 0.6,
            actualInstrument: 0.7,
            simulatedInstrument: 0.2,
            dayTakeoffs: 2,
            dayLandings: 3,
            dayFullStopLandings: 1,
            nightTakeoffs: 4,
            nightLandings: 5,
            approaches: 6,
            holding: true,
            tracking: true,
            flightReview: true,
            ipc: true,
            practicalTest: true,
            nightFlight: true,
            conditions: 'IFR',
            remarks: 'r',
          );
      final back = LogbookEntry.fromMap(e.toMap());
      expect(back.toMap(), e.toMap());
    });
    test('a v1 row (no new columns, VMC) decodes with honest defaults', () {
      final e = LogbookEntry.fromMap({
        'id': 1,
        'date': '2026-01-02T00:00:00.000',
        'aircraft_type': 'C152',
        'tail_number': 'N1',
        'from_airport': 'KPAO',
        'to_airport': 'KPAO',
        'total_time': 1, // sqflite can hand back an int
        'day_landings': 4,
        'conditions': 'VMC',
      });
      expect(e.totalTime, 1.0);
      expect(e.categoryClass, '');
      expect(e.conditions, 'VFR');
      expect(e.holding, isFalse);
    });
    test('night and IFR flags are derived from what was logged', () {
      expect(f(DateTime(2026, 1, 1), night: 0.1).isNight, isTrue);
      expect(f(DateTime(2026, 1, 1)).copyWith(nightLandings: 1).isNight, isTrue);
      expect(f(DateTime(2026, 1, 1)).copyWith(nightFlight: true).isNight, isTrue);
      expect(f(DateTime(2026, 1, 1)).isNight, isFalse);
      expect(f(DateTime(2026, 1, 1), approaches: 1).isIfr, isTrue);
      expect(f(DateTime(2026, 1, 1), conditions: 'IFR').isIfr, isTrue);
      expect(f(DateTime(2026, 1, 1)).isIfr, isFalse);
    });
  });
}
