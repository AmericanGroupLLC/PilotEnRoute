import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/data/logbook_store.dart';
import 'package:pilot_enroute/services/logbook_service.dart';

void main() {
  group('LogbookEntry model', () {
    test('creates entry with all required fields', () {
      final entry = LogbookEntry(
        date: DateTime(2026, 6, 1),
        aircraftType: 'C172',
        tailNumber: 'N12345',
        from: 'KLAX',
        to: 'KSFO',
        totalTime: 1.5,
        picTime: 1.5,
        crossCountry: 1.5,
        dayLandings: 2,
        remarks: 'VFR cross-country',
      );

      expect(entry.from, equals('KLAX'));
      expect(entry.to, equals('KSFO'));
      expect(entry.totalTime, equals(1.5));
      expect(entry.picTime, equals(1.5));
      expect(entry.dayLandings, equals(2));
      expect(entry.aircraftType, equals('C172'));
      expect(entry.tailNumber, equals('N12345'));
    });

    test('entry defaults are correct', () {
      final entry = LogbookEntry(
        date: DateTime.now(),
        aircraftType: 'B737',
        tailNumber: 'N99999',
        from: 'KORD',
        to: 'KJFK',
        totalTime: 2.3,
      );
      expect(entry.picTime, equals(0));
      expect(entry.night, equals(0));
      expect(entry.actualInstrument, equals(0));
      expect(entry.nightLandings, equals(0));
      // New entries default to VFR; the form sets IFR explicitly.
      expect(entry.conditions, equals('VFR'));
      expect(entry.categoryClass, isEmpty,
          reason: 'never assumed; the form requires it');
    });

    test('toMap produces correct keys', () {
      final entry = LogbookEntry(
        date: DateTime(2026, 1, 1),
        aircraftType: 'C172',
        tailNumber: 'N54321',
        from: 'KSFO',
        to: 'KLAS',
        totalTime: 0.8,
      );
      final map = entry.toMap();
      expect(map, containsPair('aircraft_type', 'C172'));
      expect(map, containsPair('from_airport', 'KSFO'));
      expect(map, containsPair('to_airport', 'KLAS'));
      expect(map, containsPair('total_time', 0.8));
    });

    test('fromMap round-trips correctly', () {
      final original = LogbookEntry(
        date: DateTime(2026, 3, 15),
        aircraftType: 'PA28',
        tailNumber: 'N11111',
        from: 'KBOS',
        to: 'KPVD',
        totalTime: 0.5,
        picTime: 0.5,
        dayLandings: 1,
        remarks: 'Pattern work',
      );
      final map = original.toMap();
      map['id'] = null;
      final restored = LogbookEntry.fromMap(map);
      expect(restored.aircraftType, equals(original.aircraftType));
      expect(restored.from, equals(original.from));
      expect(restored.to, equals(original.to));
      expect(restored.totalTime, equals(original.totalTime));
    });

    test('total time is non-negative', () {
      final entry = LogbookEntry(
        date: DateTime.now(),
        aircraftType: 'C172',
        tailNumber: 'N00001',
        from: 'KSEA',
        to: 'KPDX',
        totalTime: 0.7,
      );
      expect(entry.totalTime, greaterThanOrEqualTo(0));
    });
  });

  group('LogbookService', () {
    test('a fresh store opens empty: no sample flights', () async {
      final service = LogbookService(store: MemoryLogbookStore());
      await service.init();
      expect(service.ready, isTrue);
      expect(service.entries, isEmpty);
      expect(service.checks, isEmpty);
      expect(service.lastEntry, isNull);
    });

    test('edit replaces the entry in place', () async {
      final service = LogbookService(store: MemoryLogbookStore());
      final id = await service.addEntry(LogbookEntry(
          date: DateTime(2026, 1, 1),
          aircraftType: 'C172',
          tailNumber: 'N1',
          from: 'KPAO',
          to: 'KPAO',
          totalTime: 1));
      final e = service.entries.single;
      expect(e.id, id);
      await service.updateEntry(e.copyWith(totalTime: 1.4));
      expect(service.entries.single.totalTime, 1.4);
      expect(service.entries, hasLength(1));
    });

    test('a swiped-away entry can be put back (undo)', () async {
      final service = LogbookService(store: MemoryLogbookStore());
      await service.addEntry(LogbookEntry(
          date: DateTime(2026, 1, 1),
          aircraftType: 'C172',
          tailNumber: 'N1',
          from: 'KPAO',
          to: 'KSQL',
          totalTime: 1,
          remarks: 'keep me'));
      final e = service.entries.single;
      await service.deleteEntry(e.id!);
      expect(service.entries, isEmpty);
      await service.restoreEntry(e);
      expect(service.entries.single.remarks, 'keep me');
    });

    test('Copy as CSV covers every entry', () async {
      final service = LogbookService(store: MemoryLogbookStore());
      await service.addEntry(LogbookEntry(
          date: DateTime(2026, 1, 1),
          aircraftType: 'C172',
          tailNumber: 'N1',
          from: 'KPAO',
          to: 'KSQL',
          totalTime: 1));
      expect(service.toCsv().split('\r\n').where((l) => l.isNotEmpty),
          hasLength(2));
    });

    test('initializes with empty entries', () {
      final service = LogbookService();
      expect(service.entries, isEmpty);
    });

    test('totals start at zero', () {
      final service = LogbookService();
      expect(service.totals.totalTime, equals(0.0));
      expect(service.totals.picTime, equals(0.0));
      expect(service.totals.night, equals(0.0));
      expect(service.totals.actualInstrument, equals(0.0));
      expect(service.totals.totalFlights, equals(0));
    });
  });

  group('LogbookTotals model', () {
    test('creates with all fields', () {
      const totals = LogbookTotals(
        totalTime: 250.5,
        picTime: 200.0,
        sicTime: 50.5,
        dualReceived: 45.0,
        cfiGiven: 0.0,
        crossCountry: 120.0,
        night: 15.0,
        actualInstrument: 30.0,
        simulatedInstrument: 10.0,
        dayTakeoffs: 180,
        dayLandings: 180,
        nightTakeoffs: 20,
        nightLandings: 20,
        approaches: 45,
        totalFlights: 200,
      );
      expect(totals.totalTime, equals(250.5));
      expect(totals.totalFlights, equals(200));
      expect(totals.night, equals(15.0));
    });
  });
}
