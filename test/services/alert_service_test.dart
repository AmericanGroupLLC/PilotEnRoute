/// Weather alerting: the ceiling/visibility grading a pilot is shown.
///
/// The weather category used to emit a hard-coded "SAMPLE — Deteriorating
/// weather" item regardless of conditions. It now grades a real decoded METAR,
/// so the thresholds and the severity mapping need pinning: an IFR ceiling has
/// to come out as a warning, not as an informational note.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/services/alert_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AlertService> freshService() async {
  SharedPreferences.setMockInitialValues({});
  final service = AlertService();
  await service.init();
  return service;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('flightCategoryFor', () {
    test('a high ceiling in good visibility is VFR', () {
      expect(
        AlertService.flightCategoryFor(ceilingFt: 5000, visibilitySm: 10),
        'VFR',
      );
    });

    test('a 3000 ft ceiling is the top of MVFR, not VFR', () {
      expect(
        AlertService.flightCategoryFor(ceilingFt: 3000, visibilitySm: 10),
        'MVFR',
      );
      expect(
        AlertService.flightCategoryFor(ceilingFt: 3001, visibilitySm: 10),
        'VFR',
      );
    });

    test('five miles visibility is MVFR even with no ceiling', () {
      expect(
        AlertService.flightCategoryFor(visibilitySm: 5),
        'MVFR',
      );
    });

    test('below 1000 ft or below 3 sm is IFR', () {
      expect(
        AlertService.flightCategoryFor(ceilingFt: 800, visibilitySm: 10),
        'IFR',
      );
      expect(
        AlertService.flightCategoryFor(ceilingFt: 5000, visibilitySm: 2),
        'IFR',
      );
    });

    test('below 500 ft or below 1 sm is LIFR', () {
      expect(
        AlertService.flightCategoryFor(ceilingFt: 200, visibilitySm: 10),
        'LIFR',
      );
      expect(
        AlertService.flightCategoryFor(ceilingFt: 5000, visibilitySm: 0.5),
        'LIFR',
      );
    });

    test('the worse of the two drives the category', () {
      // A good ceiling must not rescue a half-mile visibility.
      expect(
        AlertService.flightCategoryFor(ceilingFt: 12000, visibilitySm: 0.25),
        'LIFR',
      );
    });

    test('missing values cannot push the category down', () {
      expect(AlertService.flightCategoryFor(), 'VFR');
      expect(AlertService.flightCategoryFor(ceilingFt: 400), 'LIFR');
      expect(AlertService.flightCategoryFor(visibilitySm: 10), 'VFR');
    });
  });

  group('evaluateWeather', () {
    test('an IFR ceiling is raised as a warning naming the station', () async {
      final service = await freshService();
      final item = await service.evaluateWeather(
        station: 'KJFK',
        ceilingFt: 700,
        visibilitySm: 4,
      );

      expect(item, isNotNull);
      expect(item!.severity, AlertSeverity.warning);
      expect(item.title, 'KJFK IFR');
      expect(item.message, contains('ceiling 700 ft'));
      expect(item.message, contains('visibility 4 sm'));
      expect(service.feed.first.id, item.id);
    });

    test('MVFR is a caution and VFR only an info note', () async {
      final service = await freshService();

      final mvfr = await service.evaluateWeather(
        station: 'KBOS',
        ceilingFt: 2500,
        visibilitySm: 8,
      );
      expect(mvfr!.severity, AlertSeverity.caution);

      final vfr = await service.evaluateWeather(
        station: 'KBOS',
        ceilingFt: 9000,
        visibilitySm: 10,
      );
      expect(vfr!.severity, AlertSeverity.info);
    });

    test('no reported ceiling reads as unlimited rather than as zero',
        () async {
      final service = await freshService();
      final item = await service.evaluateWeather(
        station: 'KSFO',
        visibilitySm: 10,
      );

      expect(item!.title, 'KSFO VFR');
      expect(item.message, contains('ceiling unlimited'));
      expect(item.message, isNot(contains('0 ft')));
    });

    test('a fractional visibility keeps its decimal', () async {
      final service = await freshService();
      final item = await service.evaluateWeather(
        station: 'KLAX',
        ceilingFt: 300,
        visibilitySm: 0.5,
      );

      expect(item!.title, 'KLAX LIFR');
      expect(item.message, contains('visibility 0.5 sm'));
    });

    test('a disabled weather rule raises nothing', () async {
      final service = await freshService();
      final rule = service.ruleFor(AlertCategory.weather)!;
      await service.updateRule(rule.copyWith(enabled: false));

      final item = await service.evaluateWeather(
        station: 'KJFK',
        ceilingFt: 200,
        visibilitySm: 0.5,
      );
      expect(item, isNull);
    });
  });

  group('runChecksNow', () {
    test('with a METAR the weather alert is real, not the sample', () async {
      final service = await freshService();
      await service.runChecksNow(
        metarStation: 'KJFK',
        ceilingFt: 400,
        visibilitySm: 0.75,
      );

      final weather = service.feed
          .where((a) => a.category == AlertCategory.weather)
          .toList();
      expect(weather, hasLength(1));
      expect(weather.single.title, 'KJFK LIFR');
      expect(weather.single.title, isNot(contains('SAMPLE')));
    });

    test('with no inputs it raises nothing invented', () async {
      final service = await freshService();
      final count = await service.runChecksNow();

      // No METAR, runway, endurance or stored dates: nothing is real, so
      // nothing is alerted — and nothing fires a device notification.
      expect(count, 0);
      expect(service.feed, isEmpty);
      expect(
        service.lastNotEvaluated.join('\n'),
        allOf(
          contains('Crosswind — not evaluated'),
          contains('Fuel — not evaluated'),
          contains('Weather — not evaluated'),
          contains('NOTAM — not evaluated: no data source'),
          contains('Terrain — not evaluated: no data source'),
          contains('Traffic — not evaluated: no data source'),
          contains('Airspace — not evaluated: no data source'),
        ),
      );
    });

    test('no alert uses an invented runway, wind, endurance or sample',
        () async {
      final service = await freshService();
      await service.runChecksNow(
        metarStation: 'KJFK',
        ceilingFt: 400,
        visibilitySm: 0.75,
        windDirDeg: 150,
        windSpeedKts: 22,
      );

      final text =
          service.feed.map((a) => '${a.title} ${a.message}').join('\n');
      expect(text, isNot(contains('SAMPLE')));
      expect(text, isNot(contains('RWY 09')));
      expect(text, isNot(contains('Endurance 50m')));
      // Only the METAR-driven weather check had real input.
      expect(
        service.feed.map((a) => a.category).toSet(),
        {AlertCategory.weather},
      );
    });

    test('a supplied wind and runway drive the crosswind check', () async {
      final service = await freshService();
      await service.runChecksNow(
        windDirDeg: 90,
        windSpeedKts: 30,
        runwayHeadingDeg: 90,
        runwayLabel: 'RWY 09',
      );

      final crosswind = service.feed
          .firstWhere((a) => a.category == AlertCategory.crosswind);
      expect(crosswind.title, 'Crosswind 0 kt — RWY 09');
      expect(crosswind.severity, AlertSeverity.info);
    });

    test('a supplied endurance drives the fuel check', () async {
      final service = await freshService();
      await service.runChecksNow(fuelEnduranceMinutes: 120);

      final fuel =
          service.feed.firstWhere((a) => a.category == AlertCategory.fuel);
      expect(fuel.message, startsWith('Endurance 120m'));
    });

    test('stored medical date is evaluated; a missing one is not invented',
        () async {
      final expiry = DateTime.now().add(const Duration(days: 200));
      SharedPreferences.setMockInitialValues({
        'profile_medical_expiry': expiry.toIso8601String(),
      });
      final service = AlertService();
      await service.init();
      await service.runChecksNow();

      final medical = service.feed
          .where((a) => a.category == AlertCategory.medical)
          .toList();
      expect(medical, hasLength(1));
      expect(medical.single.title, 'Medical certificate current');
      expect(
          service.feed.where((a) => a.category == AlertCategory.currency),
          isEmpty);
    });

    test('alerts persisted from invented inputs are dropped on load',
        () async {
      SharedPreferences.setMockInitialValues({
        'alert_feed': jsonEncode([
          AlertItem(
            id: '1',
            category: AlertCategory.notam,
            severity: AlertSeverity.warning,
            title: 'SAMPLE — Runway closure NOTAM',
            message: 'x',
            timestamp: DateTime(2026, 1, 1),
          ).toJson(),
          AlertItem(
            id: '2',
            category: AlertCategory.crosswind,
            severity: AlertSeverity.caution,
            title: 'Crosswind 19 kt — RWY 09',
            message: 'x',
            timestamp: DateTime(2026, 1, 1),
          ).toJson(),
          AlertItem(
            id: '3',
            category: AlertCategory.weather,
            severity: AlertSeverity.warning,
            title: 'KJFK LIFR',
            message: 'ceiling 400 ft.',
            timestamp: DateTime(2026, 1, 1),
          ).toJson(),
        ]),
      });
      final service = AlertService();
      await service.init();
      expect(service.feed.map((a) => a.id), ['3']);
    });
  });
}
