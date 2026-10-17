/// On-device sunrise/sunset (spec S2) against US Naval Observatory times.
///
/// Reference values from the USNO "Complete Sun and Moon Data for One Day"
/// API (https://aa.usno.navy.mil/api/rstt/oneday?date=<d>&coords=<lat>,<lon>&tz=0),
/// captured 2026-10-17T09:12Z (KPAO, PABR, YSSY) and 2026-10-17T09:15Z
/// (KACK). USNO rounds to the minute, so each check allows 2 minutes.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/core/minimums/solar.dart';

void expectNear(DateTime? actual, DateTime expected) {
  expect(actual, isNotNull);
  final diff = actual!.difference(expected).inSeconds.abs();
  expect(diff, lessThanOrEqualTo(120),
      reason: 'got ${actual.toIso8601String()}, USNO '
          '${expected.toIso8601String()}');
}

void main() {
  group('sunTimes vs USNO', () {
    test('KPAO (37.4611, -122.115), 21 Jun 2026: sunset falls on the next '
        'UTC date', () {
      final s = sunTimes(date: DateTime(2026, 6, 21), lat: 37.4611, lon: -122.115);
      expectNear(s.sunriseUtc, DateTime.utc(2026, 6, 21, 12, 48));
      expectNear(s.sunsetUtc, DateTime.utc(2026, 6, 22, 3, 33));
    });

    test('KPAO, 21 Dec 2026', () {
      final s = sunTimes(date: DateTime(2026, 12, 21), lat: 37.4611, lon: -122.115);
      expectNear(s.sunriseUtc, DateTime.utc(2026, 12, 21, 15, 19));
      expectNear(s.sunsetUtc, DateTime.utc(2026, 12, 22, 0, 54));
    });

    test('YSSY (-33.9461, 151.1772), 21 Jun 2026: sunrise falls on the '
        'previous UTC date', () {
      final s =
          sunTimes(date: DateTime(2026, 6, 21), lat: -33.9461, lon: 151.1772);
      expectNear(s.sunriseUtc, DateTime.utc(2026, 6, 20, 21, 0));
      expectNear(s.sunsetUtc, DateTime.utc(2026, 6, 21, 6, 54));
    });

    test('PABR Utqiagvik (71.2906, -156.7886), 21 Jun 2026: USNO says '
        '"continuously above the horizon"', () {
      final s =
          sunTimes(date: DateTime(2026, 6, 21), lat: 71.2906, lon: -156.7886);
      expect(s.alwaysUp, isTrue);
      expect(s.sunriseUtc, isNull);
      expect(s.sunsetUtc, isNull);
    });

    test('PABR, 21 Dec 2026: the sun does not rise', () {
      final s =
          sunTimes(date: DateTime(2026, 12, 21), lat: 71.2906, lon: -156.7886);
      expect(s.alwaysDown, isTrue);
    });
  });

  group('61.57(b) night window', () {
    test('KACK (41.2533, -70.0605), 14 Oct 2026: 1 h after the 22:01Z sunset '
        'to 1 h before the 10:52Z sunrise on the 15th', () {
      final w = nightCurrencyWindow(
          date: DateTime(2026, 10, 14), lat: 41.2533, lon: -70.0605);
      expect(w.problem, isNull);
      expectNear(w.startUtc, DateTime.utc(2026, 10, 14, 23, 1));
      expectNear(w.endUtc, DateTime.utc(2026, 10, 15, 9, 52));
    });

    test('above 66° latitude no window is shown (the series drifts there; '
        'PABR polar day included)', () {
      final w = nightCurrencyWindow(
          date: DateTime(2026, 6, 21), lat: 71.2906, lon: -156.7886);
      expect(w.startUtc, isNull);
      expect(w.problem, startsWith('Not worked out above 66° latitude'));
      final svalbard = nightCurrencyWindow(
          date: DateTime(2026, 4, 15), lat: 78.2461, lon: 15.4656);
      expect(svalbard.problem, startsWith('Not worked out'));
    });

    test('under 2 h of darkness there is no 61.57(b) night, never an '
        'inverted window', () {
      // 65.25°N at the June solstice: the sun is down about 1.6 h
      // (00:26Z to 02:01Z), so sunset + 1 h is after sunrise - 1 h.
      final w = nightCurrencyWindow(
          date: DateTime(2026, 6, 21), lat: 65.25, lon: -18.0);
      expect(w.startUtc, isNull);
      expect(w.problem, contains('less than 2 hours'));
    });

    test('an early-morning departure is inside the previous evening\'s '
        'window', () {
      final early = nightWindowForDeparture(
          departure: DateTime.utc(2026, 10, 15, 5), lat: 41.2533, lon: -70.0605);
      expect(early.date, DateTime(2026, 10, 14));
      expectNear(early.startUtc, DateTime.utc(2026, 10, 14, 23, 1));
      final midday = nightWindowForDeparture(
          departure: DateTime.utc(2026, 10, 15, 12), lat: 41.2533, lon: -70.0605);
      expect(midday.date, DateTime(2026, 10, 15));
    });

    test('the line is worded with Zulu times, "about", and the rule', () {
      final line = nightWindowLine(
        station: 'KACK',
        window: NightWindow(
            date: DateTime(2026, 10, 14),
            startUtc: DateTime.utc(2026, 10, 14, 23, 1),
            endUtc: DateTime.utc(2026, 10, 15, 9, 52)),
      );
      expect(
          line,
          'Night for passenger currency (61.57(b)) at KACK, evening of 14 Oct: '
          'about 23:01Z to 09:52Z. That is 1 h after sunset to 1 h before '
          'sunrise.');
    });

    test('a problem replaces the times', () {
      final line = nightWindowLine(
          station: 'PABR',
          window: const NightWindow(problem: 'Not worked out above 66°.'));
      expect(line,
          'Night for passenger currency (61.57(b)) at PABR: Not worked out '
          'above 66°.');
    });

    test('with a local formatter each time also shows the device clock', () {
      final line = nightWindowLine(
        station: 'KACK',
        window: NightWindow(
            date: DateTime(2026, 10, 14),
            startUtc: DateTime.utc(2026, 10, 14, 23, 1),
            endUtc: DateTime.utc(2026, 10, 15, 9, 52)),
        local: (_) => '19:01',
      );
      expect(line, contains('23:01Z (19:01 your time)'));
    });
  });
}
