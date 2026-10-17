/// Spec S3: "Paste CSV" reads the app's own "Copy as CSV" text back. Only that
/// format is accepted; other logbooks' layouts are not guessed.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/core/logbook/logbook_csv.dart';
import 'package:pilot_enroute/core/logbook/logbook_entry.dart';

final full = LogbookEntry(
  date: DateTime(2026, 10, 3),
  aircraftType: 'C172',
  tailNumber: 'N35AB',
  categoryClass: 'ASEL',
  tailwheel: true,
  from: 'KPAO',
  to: 'KSQL',
  route: 'KPAO SJC KSQL',
  totalTime: 1.6,
  picTime: 1.6,
  dualReceived: 0.5,
  crossCountry: 1.2,
  night: 0.4,
  actualInstrument: 0.3,
  simulatedInstrument: 0.2,
  dayTakeoffs: 2,
  dayLandings: 2,
  dayFullStopLandings: 1,
  nightTakeoffs: 1,
  nightLandings: 1,
  approaches: 2,
  holding: true,
  tracking: true,
  flightReview: true,
  conditions: 'IFR',
  nightFlight: true,
  remarks: 'Gusty, "fun", 3 laps\nthen home',
);

final plain = LogbookEntry(
  date: DateTime(2026, 9, 12),
  aircraftType: 'PA28',
  tailNumber: 'N55PA',
  categoryClass: 'ASEL',
  from: 'KSQL',
  to: 'KSQL',
  totalTime: 1.0,
  dayTakeoffs: 3,
  dayLandings: 3,
);

void main() {
  group('parseCsvRecords (RFC 4180)', () {
    test('quoted commas, doubled quotes and line breaks', () {
      final r = parseCsvRecords('a,"b,c","say ""hi""","two\r\nlines"\r\nx,y\r\n');
      expect(r, [
        ['a', 'b,c', 'say "hi"', 'two\r\nlines'],
        ['x', 'y'],
      ]);
    });

    test('LF line ends, no final newline, blank lines skipped, BOM dropped',
        () {
      expect(parseCsvRecords('\uFEFFa,b\n\nc,\n'), [
        ['a', 'b'],
        ['c', ''],
      ]);
      expect(parseCsvRecords('a,b'), [
        ['a', 'b'],
      ]);
    });

    test('an unclosed quote is a format error', () {
      expect(() => parseCsvRecords('a,"b\n'), throwsFormatException);
    });
  });

  group('logbookFromCsv', () {
    test('round trip: every field of every entry comes back', () {
      final csv = logbookToCsv([full, plain]);
      final r = logbookFromCsv(csv);
      expect(r.fatal, isNull);
      expect(r.errors, isEmpty);
      expect(r.entries, hasLength(2));
      // Export sorts oldest first.
      expect(csvRow(r.entries[0]), csvRow(plain));
      expect(csvRow(r.entries[1]), csvRow(full));
      expect(r.entries[1].remarks, 'Gusty, "fun", 3 laps\nthen home');
      expect(r.entries[1].date, DateTime(2026, 10, 3));
    });

    test('flights already in the logbook are skipped, not doubled', () {
      final r = logbookFromCsv(logbookToCsv([full, plain]), existing: [full]);
      expect(r.entries, hasLength(1));
      expect(r.duplicates, 1);
      expect(r.entries.single.tailNumber, 'N55PA');
    });

    test('two identical flights in one export both import into an empty '
        'logbook', () {
      final r = logbookFromCsv(logbookToCsv([plain, plain]));
      expect(r.entries, hasLength(2));
      expect(r.duplicates, 0);
    });

    test('duplicates are matched one per existing copy', () {
      final r = logbookFromCsv(logbookToCsv([plain, plain]),
          existing: [plain]);
      expect(r.entries, hasLength(1));
      expect(r.duplicates, 1);
    });

    test('hours finer than tenths survive the round trip exactly', () {
      final fine = plain.copyWith(
          totalTime: 0.9, actualInstrument: 0.45, simulatedInstrument: 0.45);
      final odd = plain.copyWith(totalTime: 1.25, picTime: 1.25);
      final csv = logbookToCsv([fine, odd]);
      expect(csv, contains(',0.45,0.45,'));
      final r = logbookFromCsv(csv);
      expect(r.errors, isEmpty);
      expect(r.entries.map((e) => e.totalTime), containsAll([0.9, 1.25]));
      expect(r.entries.firstWhere((e) => e.totalTime == 0.9).actualInstrument,
          0.45);
    });

    test('tenths are still written as "1.0", not "1"', () {
      expect(csvRow(plain)[8], '1.0');
    });

    test('a row with missing fields is refused, not filled with zeros', () {
      final lines = logbookToCsv([plain]).split('\r\n');
      final short = lines[1].split(',').take(9).join(',');
      final r = logbookFromCsv('${lines[0]}\r\n$short\r\n');
      expect(r.entries, isEmpty);
      expect(r.errors.single.message,
          'Expected ${csvHeader.length} fields, found 9');
    });

    test('error lines are physical lines, after a multi-line remark', () {
      final multi = plain.copyWith(remarks: 'one\ntwo\nthree');
      final lines = logbookToCsv([multi]);
      final bad = logbookToCsv([plain]).split('\r\n')[1]
          .replaceFirst('2026-09-12', 'not-a-date');
      final r = logbookFromCsv('$lines$bad\r\n');
      expect(r.entries, hasLength(1));
      // Header line 1, the remark spans lines 2-4, the bad row is line 5.
      expect(r.errors.single.line, 5);
    });

    test('columns may come in any order', () {
      final records = parseCsvRecords(logbookToCsv([plain]));
      final order = [for (var i = records[0].length - 1; i >= 0; i--) i];
      final reversed = [
        for (final rec in records) [for (final i in order) rec[i]].join(','),
      ].join('\r\n');
      final r = logbookFromCsv(reversed);
      expect(r.errors, isEmpty);
      expect(csvRow(r.entries.single), csvRow(plain));
    });

    test('another logbook\'s layout is refused, naming missing columns', () {
      final r = logbookFromCsv('Date,Aircraft ID,Total Time\n2026-10-01,N1,1.0\n');
      expect(r.entries, isEmpty);
      expect(r.fatal, startsWith('This is not a PilotEnRoute logbook CSV.'));
      expect(r.fatal, contains('Aircraft type'));
    });

    test('empty clipboard and broken quoting have their own messages', () {
      expect(logbookFromCsv('').fatal, 'The clipboard is empty.');
      expect(logbookFromCsv('"Date').fatal, startsWith('Not readable as CSV'));
    });

    test('bad rows are reported by line and skipped; good rows still read',
        () {
      final lines = logbookToCsv([plain]).split('\r\n');
      final header = lines[0];
      final good = lines[1];
      String with_(int col, String value) {
        final f = parseCsvRecords(good).single..[col] = value;
        return f.map(csvField).join(',');
      }

      final text = [
        header,
        good,
        with_(0, '2026-02-30'), // no such date
        with_(8, 'abc'), // Total
        with_(10, '5.0'), // SIC > total
        with_(18, '1.5'), // Day takeoffs
        with_(29, 'SVFR'), // Flight rules
        with_(4, 'maybe'), // Tailwheel
      ].join('\r\n');
      final r = logbookFromCsv(text);
      expect(r.entries, hasLength(1));
      expect(r.errors.map((e) => e.line), [3, 4, 5, 6, 7, 8]);
      expect(r.errors[0].message, 'Date: expected YYYY-MM-DD');
      expect(r.errors[1].message, contains('Total'));
      expect(r.errors[2].message, 'SIC cannot exceed total time');
      expect(r.errors[3].message, 'Day takeoffs: Whole numbers only');
      expect(r.errors[4].message, 'Flight rules: expected VFR or IFR');
      expect(r.errors[5].message, 'Tailwheel: expected Y or empty');
      expect(r.errors[0].toString(), 'Line 3: Date: expected YYYY-MM-DD');
    });

    test('v1 rows exported without a category/class still import', () {
      final old = plain.copyWith(categoryClass: '');
      final r = logbookFromCsv(logbookToCsv([old]));
      expect(r.errors, isEmpty);
      expect(r.entries.single.categoryClass, '');
    });
  });
}
