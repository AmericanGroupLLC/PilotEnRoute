/// Logbook aggregation, currency from the logbook, and export.
///
/// These exercise the in-memory store (web and widget tests); the database
/// path is covered by test/data/logbook_migration_test.dart. Currency used to
/// come from three getters on the service (isPassengerCurrent and friends);
/// those are gone and the same scenarios now go through the legality engine,
/// which applies the regulation correctly (takeoffs and landings, night
/// landings counting toward 61.57(a), holding and tracking for IFR).
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/core/legality/legality_engine.dart';
import 'package:pilot_enroute/core/legality/pilot_profile.dart';
import 'package:pilot_enroute/data/logbook_store.dart';
import 'package:pilot_enroute/services/logbook_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

LogbookEntry entry({
  required int daysAgo,
  double totalTime = 1.0,
  double picTime = 0,
  double sicTime = 0,
  double dualReceived = 0,
  double cfiGiven = 0,
  double crossCountry = 0,
  double night = 0,
  double actualInstrument = 0,
  double simulatedInstrument = 0,
  int dayTakeoffs = 0,
  int dayLandings = 0,
  int nightTakeoffs = 0,
  int nightLandings = 0,
  int approaches = 0,
  bool holding = false,
  bool tracking = false,
  String conditions = 'VFR',
}) {
  return LogbookEntry(
    date: DateTime.now().subtract(Duration(days: daysAgo)),
    aircraftType: 'C172',
    tailNumber: 'N12345',
    from: 'KPAO',
    to: 'KSQL',
    totalTime: totalTime,
    picTime: picTime,
    sicTime: sicTime,
    dualReceived: dualReceived,
    cfiGiven: cfiGiven,
    crossCountry: crossCountry,
    night: night,
    actualInstrument: actualInstrument,
    simulatedInstrument: simulatedInstrument,
    dayTakeoffs: dayTakeoffs,
    dayLandings: dayLandings,
    nightTakeoffs: nightTakeoffs,
    nightLandings: nightLandings,
    approaches: approaches,
    holding: holding,
    tracking: tracking,
    categoryClass: 'ASEL',
    conditions: conditions,
  );
}

void main() {
  late LogbookService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = LogbookService(store: MemoryLogbookStore());
  });

  RuleState state(RuleId id, {bool night = false, bool ifr = false}) =>
      const LegalityEngine()
          .evaluate(
            entries: service.entries,
            profile: const PilotProfile(
                instrumentRated: true, homeCategoryClass: 'ASEL'),
            flight: PlannedFlight(
              date: DateTime.now(),
              categoryClass: 'ASEL',
              passengers: true,
              night: night,
              ifr: ifr,
            ),
          )
          .rule(id)
          .state;
  bool isPassengerCurrent() => state(RuleId.dayPassengers) == RuleState.valid;
  bool isNightPassengerCurrent() =>
      state(RuleId.nightPassengers, night: true) == RuleState.valid;
  bool isIfrCurrent() => state(RuleId.ifr, ifr: true) == RuleState.valid;

  group('adding entries', () {
    test('an added entry keeps every column, not just the common ones',
        () async {
      // Regression: the in-memory branch of addEntry used to drop SIC, CFI
      // given, instrument time, night takeoffs/landings, approaches and
      // conditions, which silently broke instrument currency.
      await service.addEntry(entry(
        daysAgo: 1,
        totalTime: 2.0,
        picTime: 1.0,
        sicTime: 0.5,
        dualReceived: 0.5,
        cfiGiven: 0.25,
        crossCountry: 1.5,
        night: 0.75,
        actualInstrument: 0.6,
        simulatedInstrument: 0.4,
        dayTakeoffs: 2,
        dayLandings: 2,
        nightTakeoffs: 1,
        nightLandings: 1,
        approaches: 3,
        conditions: 'IMC',
      ));

      final e = service.entries.single;
      expect(e.sicTime, equals(0.5));
      expect(e.cfiGiven, equals(0.25));
      expect(e.actualInstrument, equals(0.6));
      expect(e.simulatedInstrument, equals(0.4));
      expect(e.nightTakeoffs, equals(1));
      expect(e.nightLandings, equals(1));
      expect(e.approaches, equals(3));
      expect(e.conditions, equals('IMC'));
    });

    test('ids stay unique after a delete', () async {
      // Regression: the id used to be entries.length + 1, so after deleting a
      // row the next entry reused a live id and deleteEntry removed two rows.
      await service.addEntry(entry(daysAgo: 3));
      await service.addEntry(entry(daysAgo: 2));
      await service.deleteEntry(service.entries.last.id!);
      await service.addEntry(entry(daysAgo: 1));

      final ids = service.entries.map((e) => e.id).toList();
      expect(ids.toSet(), hasLength(ids.length), reason: 'ids: $ids');
    });

    test('deleting removes exactly one flight', () async {
      await service.addEntry(entry(daysAgo: 3));
      await service.addEntry(entry(daysAgo: 2));
      await service.addEntry(entry(daysAgo: 1));
      await service.deleteEntry(service.entries.first.id!);

      expect(service.entries, hasLength(2));
      expect(service.totals.totalFlights, equals(2));
    });
  });

  group('totals', () {
    test('every column sums across flights', () async {
      await service.addEntry(entry(
        daysAgo: 1,
        totalTime: 1.2,
        picTime: 1.2,
        crossCountry: 1.2,
        dayTakeoffs: 1,
        dayLandings: 1,
      ));
      await service.addEntry(entry(
        daysAgo: 2,
        totalTime: 2.3,
        dualReceived: 2.3,
        actualInstrument: 0.8,
        simulatedInstrument: 0.5,
        nightTakeoffs: 2,
        nightLandings: 2,
        approaches: 4,
      ));

      final t = service.totals;
      expect(t.totalFlights, equals(2));
      expect(t.totalTime, closeTo(3.5, 1e-9));
      expect(t.picTime, closeTo(1.2, 1e-9));
      expect(t.dualReceived, closeTo(2.3, 1e-9));
      expect(t.crossCountry, closeTo(1.2, 1e-9));
      expect(t.actualInstrument, closeTo(0.8, 1e-9));
      expect(t.simulatedInstrument, closeTo(0.5, 1e-9));
      expect(t.dayLandings, equals(1));
      expect(t.nightLandings, equals(2));
      expect(t.approaches, equals(4));
    });

    test('totals fall back when a flight is removed', () async {
      await service.addEntry(entry(daysAgo: 1, totalTime: 5));
      expect(service.totals.totalTime, equals(5));
      await service.deleteEntry(service.entries.first.id!);
      expect(service.totals.totalTime, equals(0));
      expect(service.totals.totalFlights, equals(0));
    });
  });

  group('currency', () {
    test('three takeoffs and landings inside 90 days make a pilot '
        'passenger-current', () async {
      await service.addEntry(entry(daysAgo: 10, dayTakeoffs: 3, dayLandings: 3));
      expect(isPassengerCurrent(), isTrue);
    });

    test('two is not enough', () async {
      await service.addEntry(entry(daysAgo: 10, dayTakeoffs: 2, dayLandings: 2));
      expect(isPassengerCurrent(), isFalse);
    });

    test('landings without takeoffs are not enough (61.57(a) needs both)',
        () async {
      await service.addEntry(entry(daysAgo: 10, dayLandings: 3));
      expect(isPassengerCurrent(), isFalse);
    });

    test('landings older than 90 days do not count', () async {
      await service.addEntry(entry(daysAgo: 100, dayTakeoffs: 5, dayLandings: 5));
      expect(isPassengerCurrent(), isFalse);
    });

    test('landings are summed across flights inside the window', () async {
      await service.addEntry(entry(daysAgo: 80, dayTakeoffs: 1, dayLandings: 1));
      await service.addEntry(entry(daysAgo: 40, dayTakeoffs: 1, dayLandings: 1));
      expect(isPassengerCurrent(), isFalse);
      await service.addEntry(entry(daysAgo: 5, dayTakeoffs: 1, dayLandings: 1));
      expect(isPassengerCurrent(), isTrue);
    });

    test('night currency needs three night takeoffs and full-stop landings, '
        'day landings do not substitute', () async {
      await service.addEntry(entry(daysAgo: 5, dayTakeoffs: 10, dayLandings: 10));
      expect(isNightPassengerCurrent(), isFalse);
      await service.addEntry(
          entry(daysAgo: 5, nightTakeoffs: 3, nightLandings: 3));
      expect(isNightPassengerCurrent(), isTrue);
    });

    test('night landings DO count toward the general passenger check', () async {
      // The old getter counted day landings only, which 61.57(a) does not
      // say: it asks for three takeoffs and three landings, day or night.
      // The spec (M1) corrects this; the old pinning test asserted false.
      await service.addEntry(
          entry(daysAgo: 5, nightTakeoffs: 5, nightLandings: 5));
      expect(isPassengerCurrent(), isTrue);
    });

    test('six approaches plus holding and tracking inside six calendar months '
        'make a pilot IFR current', () async {
      await service.addEntry(entry(daysAgo: 100, approaches: 3));
      expect(isIfrCurrent(), isFalse);
      await service.addEntry(
          entry(daysAgo: 20, approaches: 3, holding: true, tracking: true));
      expect(isIfrCurrent(), isTrue);
    });

    test('six approaches without holding and tracking are not IFR current',
        () async {
      await service.addEntry(entry(daysAgo: 20, approaches: 6));
      expect(isIfrCurrent(), isFalse);
    });

    test('approaches older than six calendar months do not count', () async {
      // 230 days is past the longest possible window (about 213 days).
      await service.addEntry(
          entry(daysAgo: 230, approaches: 10, holding: true, tracking: true));
      expect(isIfrCurrent(), isFalse);
    });

    test('an empty logbook is current in nothing', () {
      expect(isPassengerCurrent(), isFalse);
      expect(isNightPassengerCurrent(), isFalse);
      expect(isIfrCurrent(), isFalse);
    });
  });

  group('entry serialisation', () {
    test('every field survives a map round-trip', () {
      final original = entry(
        daysAgo: 0,
        totalTime: 2.4,
        picTime: 1.1,
        sicTime: 0.3,
        dualReceived: 1.0,
        cfiGiven: 0.2,
        crossCountry: 2.0,
        night: 0.9,
        actualInstrument: 0.7,
        simulatedInstrument: 0.4,
        dayTakeoffs: 3,
        dayLandings: 3,
        nightTakeoffs: 1,
        nightLandings: 1,
        approaches: 2,
        conditions: 'IMC',
      );

      final restored = LogbookEntry.fromMap(original.toMap());

      expect(restored.date.toIso8601String(),
          equals(original.date.toIso8601String()));
      expect(restored.totalTime, equals(original.totalTime));
      expect(restored.sicTime, equals(original.sicTime));
      expect(restored.cfiGiven, equals(original.cfiGiven));
      expect(restored.actualInstrument, equals(original.actualInstrument));
      expect(restored.simulatedInstrument, equals(original.simulatedInstrument));
      expect(restored.nightTakeoffs, equals(original.nightTakeoffs));
      expect(restored.approaches, equals(original.approaches));
      expect(restored.conditions, equals(original.conditions));
    });

    test('a sqflite row with integer hour columns still decodes', () {
      // SQLite happily returns an int for a REAL column that holds a whole
      // number; a direct cast to double would throw and lose the logbook.
      final restored = LogbookEntry.fromMap({
        'id': 7,
        'date': '2026-05-01T00:00:00.000',
        'aircraft_type': 'C172',
        'tail_number': 'N1',
        'from_airport': 'KPAO',
        'to_airport': 'KSQL',
        'total_time': 2,
        'pic_time': 2,
      });
      expect(restored.totalTime, equals(2.0));
      expect(restored.picTime, equals(2.0));
      // An absent or v1 'VMC' value reads as VFR.
      expect(restored.conditions, equals('VFR'));
    });

    test('a row missing its optional columns decodes to zeros', () {
      final restored = LogbookEntry.fromMap({
        'id': 1,
        'date': '2026-05-01T00:00:00.000',
      });
      expect(restored.aircraftType, isEmpty);
      expect(restored.totalTime, equals(0));
      expect(restored.approaches, equals(0));
    });
  });

  group('PDF export', () {
    test('an empty logbook still produces a valid PDF', () async {
      final bytes = await service.buildLogbookPdf();
      expect(bytes.length, greaterThan(500));
      // %PDF- magic: proves a real document, not an empty buffer.
      expect(String.fromCharCodes(bytes.take(5)), equals('%PDF-'));
    });

    test('the export uses no glyph the built-in font cannot draw', () async {
      // Regression: the header used a "•" separator, which Helvetica has no
      // glyph for, so the character silently vanished from every exported
      // logbook. The pdf package reports that on stdout.
      await service.addEntry(entry(daysAgo: 1, totalTime: 1.2));
      final warnings = <String>[];
      await runZoned(
        () => service.buildLogbookPdf(),
        zoneSpecification: ZoneSpecification(
          print: (_, __, ___, line) => warnings.add(line),
        ),
      );
      expect(
        warnings.where((w) => w.contains('Unable to find a font')),
        isEmpty,
        reason: warnings.join('\n'),
      );
    });

    test('the export grows once flights are logged', () async {
      final empty = await service.buildLogbookPdf();
      await service.addEntry(entry(daysAgo: 1, totalTime: 1.2, dayLandings: 1));
      await service.addEntry(entry(daysAgo: 2, totalTime: 2.3, approaches: 2));
      final filled = await service.buildLogbookPdf();

      expect(String.fromCharCodes(filled.take(5)), equals('%PDF-'));
      expect(filled.length, greaterThan(empty.length),
          reason: 'the flights must actually reach the document');
    });
  });
}
