/// Every age and every "Z" time the app shows is UTC instant arithmetic, never
/// wall-clock arithmetic, whatever zone the device is in.
///
/// Background (2026-10-14, iPhone 17 Pro Max / iOS 27.0 simulator, relaunch 5):
/// the Go Card read "The latest METAR is 6 h 25 min old". The check history
/// saved on that simulator shows the answer AWC gave for that one request was
/// `METAR KPAO 141747Z …` (obsTime 1792000020) at 2026-10-14T17:12:41 PDT,
/// i.e. 00:12:41Z on the 15th — genuinely 6 h 25 min old. Every other launch
/// got `142347Z`. These tests pin the arithmetic so a real zone bug can never
/// hide behind that one.
///
/// "now" is always injected. Wall-clock values are built from a UTC instant
/// with `.toLocal()`, so each test is correct in any zone; run this file with
/// `TZ=UTC`, `TZ=America/Los_Angeles`, `TZ=Asia/Kolkata` (UTC+5:30) and
/// `TZ=Pacific/Auckland` to exercise the device-zone cases for real.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/core/legality/legality_engine.dart';
import 'package:pilot_enroute/core/legality/pilot_profile.dart';
import 'package:pilot_enroute/core/logbook/logbook_entry.dart';
import 'package:pilot_enroute/core/minimums/go_check.dart';
import 'package:pilot_enroute/core/minimums/personal_minimums.dart';
import 'package:pilot_enroute/core/weather/awc_models.dart';
import 'package:pilot_enroute/services/flight_plan_service.dart';

import '../support/awc_fixtures.dart';

/// An AWC METAR object with only the fields that matter here. [obsTime] is
/// Unix seconds, as AWC sends it.
MetarObservation metarAt(int obsTime, String raw) =>
    MetarObservation.fromJson({
      'icaoId': 'KPAO',
      'obsTime': obsTime,
      'rawOb': raw,
      'wdir': 340,
      'wspd': 10,
      'visib': '10+',
      'clouds': [
        {'cover': 'CLR', 'base': null}
      ],
      'fltCat': 'VFR',
    });

// Recorded from https://aviationweather.gov/api/data/metar?ids=KPAO&format=json&hours=12
// on 2026-10-15T03:53Z.
final kpao141747 =
    metarAt(1792000020, 'METAR KPAO 141747Z 00000KT 10SM SKC 18/06 A3015');
final kpao142247 =
    metarAt(1792018020, 'METAR KPAO 142247Z 33009KT 10SM SKC 23/14 A3007');
final kpao142347 =
    metarAt(1792021620, 'METAR KPAO 142347Z 34010KT 10SM SKC 23/13 A3007');

/// The relaunch-5 check time, from the saved history row (created_at
/// 2026-10-14T17:12:41.964327 local, PDT = UTC-7).
final relaunch5Utc = DateTime.utc(2026, 10, 15, 0, 12, 41, 964);

GoResult goCard(MetarObservation m, DateTime now) {
  final legal = const LegalityEngine().evaluate(
    entries: [
      LogbookEntry(
        date: DateTime(2026, 10, 1),
        aircraftType: 'C172',
        tailNumber: 'N1',
        from: 'KPAO',
        to: 'KPAO',
        totalTime: 1,
        categoryClass: 'ASEL',
        dayTakeoffs: 3,
        dayLandings: 3,
      ),
    ],
    profile: PilotProfile(
      medicalKind: MedicalKind.third,
      medicalExamDate: DateTime(2026, 1, 10),
      age40OrOlderAtExam: false,
      flightReviewDate: DateTime(2026, 1, 10),
      homeCategoryClass: 'ASEL',
    ),
    flight: PlannedFlight(date: DateTime(2026, 10, 14), categoryClass: 'ASEL'),
  );
  return evaluateGo(
    legal: legal,
    weather: WeatherSnapshot(
      station: 'KPAO',
      metarStatus: FetchStatus.ok,
      tafStatus: FetchStatus.noData,
      airportStatus: FetchStatus.noData,
      metar: m,
      fetchedAt: now,
    ),
    minimums: const PersonalMinimums(
      day: MinimumsSet(
        ceilingFt: 2000,
        visibilitySm: 5,
        maxWindKt: 20,
        maxGustKt: 25,
      ),
    ),
    departureLocal: now.toLocal(),
    now: now,
  );
}

void main() {
  group('METAR observation time is a UTC instant', () {
    test('obsTime decodes as UTC, matching the DDHHMMZ group', () {
      expect(kpao141747.observedUtc, DateTime.utc(2026, 10, 14, 17, 47));
      expect(kpao141747.observedUtc!.isUtc, isTrue);
      expect(kpao142347.observedUtc, DateTime.utc(2026, 10, 14, 23, 47));
    });
  });

  group('relaunch 5 (2026-10-14 17:12 PDT, KPAO)', () {
    for (final (label, now) in [
      ('now in UTC', relaunch5Utc),
      ('now as a device-local wall clock', relaunch5Utc.toLocal()),
    ]) {
      test('$label: 141747Z is 6 h 25 min old and stale', () {
        expect(kpao141747.ageMinutes(now), 385);
        expect(kpao141747.isStale(now), isTrue);
        final r = goCard(kpao141747, now);
        expect(r.verdict, GoVerdict.incomplete);
        expect(r.metarStale, isTrue);
        expect(r.headline, contains('6 h 25 min old'));
      });

      test('$label: 142247Z would have been 1 h 25 min, not stale', () {
        expect(kpao142247.ageMinutes(now), 85);
        expect(kpao142247.isStale(now), isFalse);
        expect(goCard(kpao142247, now).metarStale, isFalse);
      });

      test('$label: 142347Z (the other launches) is 25 min, inside', () {
        expect(kpao142347.ageMinutes(now), 25);
        final r = goCard(kpao142347, now);
        expect(r.metarStale, isFalse);
        expect(r.verdict, GoVerdict.inside);
      });
    }
  });

  group('age across date boundaries (UTC day differs from local day)', () {
    test('month rollover: 312347Z read at 01 Nov 00:12Z is 25 min', () {
      final m = metarAt(1793490420, 'METAR KPAO 312347Z 34010KT 10SM SKC');
      expect(m.observedUtc, DateTime.utc(2026, 10, 31, 23, 47));
      final now = DateTime.utc(2026, 11, 1, 0, 12);
      expect(m.ageMinutes(now), 25);
      expect(m.ageMinutes(now.toLocal()), 25);
    });

    test('year rollover: 312347Z read at 01 Jan 00:12Z is 25 min', () {
      final m = metarAt(1798760820, 'METAR KPAO 312347Z 34010KT 10SM SKC');
      expect(m.observedUtc, DateTime.utc(2026, 12, 31, 23, 47));
      final now = DateTime.utc(2027, 1, 1, 0, 12);
      expect(m.ageMinutes(now), 25);
      expect(m.ageMinutes(now.toLocal()), 25);
      expect(m.isStale(now.toLocal()), isFalse);
    });

    test('February end: 282356Z read at 01 Mar 00:20Z is 24 min', () {
      final m = metarAt(1772322960, 'METAR KPAO 282356Z 34010KT 10SM SKC');
      expect(m.observedUtc, DateTime.utc(2026, 2, 28, 23, 56));
      expect(m.ageMinutes(DateTime.utc(2026, 3, 1, 0, 20).toLocal()), 24);
    });
  });

  group('age across US DST changes (instants, not wall clocks)', () {
    test('fall back: 01:47 PDT obs, 01:12 PST now is +25 min, not -35', () {
      // 2026-11-01 09:00Z: Pacific clocks go 02:00 PDT -> 01:00 PST.
      final m = metarAt(1793522820, 'METAR KPAO 010847Z 34010KT 10SM SKC');
      final now = DateTime.utc(2026, 11, 1, 9, 12);
      expect(m.ageMinutes(now), 25);
      expect(m.ageMinutes(now.toLocal()), 25);
      expect(m.isStale(now.toLocal()), isFalse);
    });

    test('spring forward: 01:47 PST obs, 03:12 PDT now is 25 min, not 85',
        () {
      // 2026-03-08 10:00Z: Pacific clocks go 02:00 PST -> 03:00 PDT.
      final m = metarAt(1772963220, 'METAR KPAO 080947Z 34010KT 10SM SKC');
      final now = DateTime.utc(2026, 3, 8, 10, 12);
      expect(m.ageMinutes(now), 25);
      expect(m.ageMinutes(now.toLocal()), 25);
      expect(m.isStale(now.toLocal()), isFalse);
    });

    test('the 90-minute threshold is exact in UTC and local', () {
      final obs = kpao142347.observedUtc!;
      for (final now in [obs, obs.toLocal()]) {
        expect(kpao142347.isStale(now.add(const Duration(minutes: 90))),
            isFalse);
        expect(
            kpao142347.isStale(now.add(const Duration(minutes: 91))), isTrue);
      }
    });
  });

  group('TAF times are UTC instants', () {
    test('issueTime and group times decode as UTC', () {
      final t = TafReport.fromJson(first('taf_KSJC'));
      expect(t.issuedUtc, DateTime.utc(2026, 10, 14, 11, 38));
      expect(t.issuedUtc!.isUtc, isTrue);
      expect(t.groups.first.fromUtc.isUtc, isTrue);
      expect(t.groups.first.toUtc.isUtc, isTrue);
    });

    test('groups for a departure are the same from a local or UTC time', () {
      final t = TafReport.fromJson(first('taf_KSJC'));
      final dep = DateTime.utc(2026, 10, 14, 18, 30);
      List<String> labels(DateTime d) => [
            for (final g in t.groupsBetween(
                d.toUtc().subtract(const Duration(hours: 1)),
                d.toUtc().add(const Duration(hours: 1))))
              '${g.label} ${g.fromUtc.toIso8601String()}',
          ];
      expect(labels(dep.toLocal()), labels(dep));
      expect(labels(dep), isNotEmpty);
    });
  });

  group('flight plan ETD is printed in Zulu', () {
    FlightPlan plan(DateTime etd) => FlightPlan(
          id: 'p',
          name: 'T',
          departure: 'KPAO',
          destination: 'KMRY',
          etd: etd,
          createdAt: DateTime.utc(2026, 10, 14),
        );

    test('a local ETD of 17:15 PDT reads 0015Z, from any zone', () {
      final etd = DateTime.utc(2026, 10, 15, 0, 15);
      final service = FlightPlanService();
      expect(service.generateFaaFlightPlanString(plan(etd.toLocal())),
          contains('ETD: 0015Z'));
      expect(service.generateFaaFlightPlanString(plan(etd)),
          contains('ETD: 0015Z'));
    });

    test('an ETD saved locally and read back still reads in Zulu', () {
      final etd = DateTime.utc(2026, 10, 15, 0, 15).toLocal();
      final back = FlightPlan.fromJson(plan(etd).toJson());
      expect(FlightPlanService().generateFaaFlightPlanString(back),
          contains('ETD: 0015Z'));
    });
  });
}
