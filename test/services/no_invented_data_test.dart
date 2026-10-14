/// Real users only ever see real data.
///
/// A fresh install has no flights, no history and no minimums, and every
/// screen says so instead of filling the gap. (The traffic, tail lookup,
/// NOTAM, debrief, notification-feed and BLS checks that used to be here went
/// with those features.)
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/core/legality/legality_engine.dart';
import 'package:pilot_enroute/core/legality/pilot_profile.dart';
import 'package:pilot_enroute/core/minimums/personal_minimums.dart';
import 'package:pilot_enroute/core/reminders/reminder_plan.dart';
import 'package:pilot_enroute/data/logbook_store.dart';
import 'package:pilot_enroute/services/logbook_service.dart';
import 'package:pilot_enroute/services/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('logbook', () {
    test('a fresh logbook is empty, not sample flights', () async {
      final s = LogbookService(store: MemoryLogbookStore());
      await s.init();
      expect(s.entries, isEmpty);
      expect(s.totals.totalTime, 0);
      expect(s.totals.totalFlights, 0);
      expect(s.checks, isEmpty);
    });

    test('the PDF of an empty logbook says it is empty', () async {
      final s = LogbookService(store: MemoryLogbookStore());
      final bytes = await s.buildLogbookPdf();
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });

  group('settings', () {
    test('fresh prefs: no airport, no profile, no minimums', () async {
      final s = await SettingsStore.load();
      expect(s.onboardingDone, isFalse);
      expect(s.homeAirport, isEmpty);
      expect(s.profile.medicalKind, MedicalKind.none);
      expect(s.profile.homeCategoryClass, isEmpty);
      expect(s.minimums.isEmpty, isTrue);
    });

    test('a corrupt saved profile falls back to empty, not to a sample',
        () async {
      SharedPreferences.setMockInitialValues({
        SettingsStore.kProfile: '{not json',
        SettingsStore.kMinimums: '[]',
      });
      final s = await SettingsStore.load();
      expect(s.profile.name, isEmpty);
      expect(s.minimums.isEmpty, isTrue);
    });

    test('minimums survive a save and reload exactly as typed', () async {
      final s = await SettingsStore.load();
      await s.setMinimums(const PersonalMinimums(
          day: MinimumsSet(ceilingFt: 1500, visibilitySm: 3.5)));
      final again = await SettingsStore.load();
      expect(again.minimums.day.ceilingFt, 1500);
      expect(again.minimums.day.visibilitySm, 3.5);
      expect(again.minimums.day.maxWindKt, isNull);
      expect(again.minimums.night.isEmpty, isTrue);
    });
  });

  group('legality with nothing on record', () {
    test('nothing is assumed current', () {
      final rep = const LegalityEngine().evaluate(
        entries: const [],
        profile: PilotProfile.empty,
        flight: PlannedFlight(
            date: DateTime(2026, 10, 14),
            categoryClass: 'ASEL',
            passengers: true,
            night: true,
            ifr: true),
      );
      expect(rep.legal, isFalse);
      for (final r in rep.rules) {
        expect(r.state, isNot(RuleState.valid), reason: r.title);
        expect(r.validThrough, isNull, reason: r.title);
      }
    });

    test('no dates on record means no reminders', () {
      expect(
          lapseItemsFrom(
              entries: const [],
              profile: PilotProfile.empty,
              now: DateTime(2026, 10, 14)),
          isEmpty);
    });
  });
}
