/// Navigation arithmetic for the flight planner.
///
/// A quietly wrong aviation number is the worst failure this app can produce,
/// so every expected value below is an independently computed great-circle
/// reference (haversine, R = 3440.065 NM) rather than a value read back out of
/// the implementation.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/services/flight_plan_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Waypoint wp(String id, double lat, double lon) =>
    Waypoint(identifier: id, name: id, lat: lat, lon: lon, type: 'airport');

void main() {
  final service = FlightPlanService();

  group('great-circle distance', () {
    test('one degree of longitude on the equator is 60.04 NM', () {
      // The sanity check every navigation formula must pass: a degree of arc
      // is a nautical mile times 60 (60.04 with the mean-Earth radius used).
      expect(service.calculateDistance(0, 0, 0, 1), closeTo(60.0405, 0.001));
    });

    test('one degree of latitude is the same 60.04 NM', () {
      expect(service.calculateDistance(0, 0, 1, 0), closeTo(60.0405, 0.001));
    });

    test('KLAX to KJFK is 2145.9 NM', () {
      expect(
        service.calculateDistance(33.9425, -118.4081, 40.6398, -73.7789),
        closeTo(2145.899, 0.01),
      );
    });

    test('KSFO to KLAX is 293.3 NM', () {
      expect(
        service.calculateDistance(37.6188, -122.3750, 33.9425, -118.4081),
        closeTo(293.287, 0.01),
      );
    });

    test('KPAO to KMRY is 54.1 NM', () {
      expect(
        service.calculateDistance(37.4611, -122.1150, 36.5870, -121.8429),
        closeTo(54.078, 0.01),
      );
    });

    test('distance is symmetric', () {
      final out = service.calculateDistance(41.9786, -87.9048, 40.6398, -73.7789);
      final back = service.calculateDistance(40.6398, -73.7789, 41.9786, -87.9048);
      expect(out, closeTo(back, 1e-9));
      expect(out, closeTo(641.380, 0.01));
    });

    test('a point to itself is zero, not NaN', () {
      // sqrt of a tiny negative from floating-point error would give NaN here.
      final d = service.calculateDistance(37.4611, -122.1150, 37.4611, -122.1150);
      expect(d.isNaN, isFalse);
      expect(d, closeTo(0, 1e-9));
    });

    test('a route crossing the antimeridian is short, not most of the way '
        'round the world', () {
      // Anchorage-ish to Tokyo-ish: dLon of -176 must not be read as +184.
      final d = service.calculateDistance(61.17, -150.00, 35.55, 139.78);
      expect(d, lessThan(3600),
          reason: 'crossing 180° must not be treated as the long way round');
    });
  });

  group('initial true course', () {
    test('due east is 090 and due north is 000', () {
      expect(service.calculateBearing(0, 0, 0, 1), closeTo(90, 1e-9));
      expect(service.calculateBearing(0, 0, 1, 0), closeTo(0, 1e-9));
    });

    test('due west normalises to 270, never to -90', () {
      // A negative bearing displayed on a heading bug is the failure this
      // catches.
      final b = service.calculateBearing(0, 0, 0, -1);
      expect(b, closeTo(270, 1e-9));
      expect(b, inInclusiveRange(0, 360));
    });

    test('KLAX to KJFK departs on 066 true', () {
      expect(
        service.calculateBearing(33.9425, -118.4081, 40.6398, -73.7789),
        closeTo(65.8705, 0.001),
      );
    });

    test('KSFO to KLAX departs on 138 true', () {
      expect(
        service.calculateBearing(37.6188, -122.3750, 33.9425, -118.4081),
        closeTo(137.6246, 0.001),
      );
    });

    test('the reciprocal of a long leg is not simply course + 180', () {
      // Great-circle convergence: KLAX→KSFO is 319.9, not 137.6 + 180 = 317.6.
      // A test that asserted the flat-earth reciprocal would hide a real bug.
      final out = service.calculateBearing(37.6188, -122.3750, 33.9425, -118.4081);
      final back = service.calculateBearing(33.9425, -118.4081, 37.6188, -122.3750);
      expect(back, closeTo(319.9458, 0.001));
      expect((back - (out + 180) % 360).abs(), greaterThan(1.0));
    });

    test('every bearing is inside 0-360', () {
      for (final lon in [-179.0, -90.0, -1.0, 0.0, 1.0, 90.0, 179.0]) {
        final b = service.calculateBearing(10, 0, -10, lon);
        expect(b, inInclusiveRange(0, 360), reason: 'lon $lon');
      }
    });
  });

  group('flight time', () {
    test('60 NM at 120 kt is half an hour', () {
      expect(service.estimateFlightTime(60, 120), closeTo(0.5, 1e-12));
    });

    test('zero ground speed returns 0 rather than infinity', () {
      // Dividing by an unset speed field would otherwise render "∞" to a pilot.
      expect(service.estimateFlightTime(100, 0), equals(0));
      expect(service.estimateFlightTime(100, -10), equals(0));
    });
  });

  group('navigation log', () {
    test('a two-leg route accumulates distance, time and fuel', () {
      final legs = service.computeNavLog(
        [wp('A', 0, 0), wp('B', 0, 1), wp('C', 0, 2)],
        groundSpeedKts: 120,
        fuelBurnGph: 10,
      );

      expect(legs, hasLength(2));
      const legNm = 60.0404607; // one degree of longitude on the equator
      expect(legs[0].distanceNm, closeTo(legNm, 1e-5));
      expect(legs[0].trueCourse, closeTo(90, 1e-6));
      expect(legs[0].timeHr, closeTo(legNm / 120, 1e-7));
      expect(legs[0].fuelGal, closeTo(legNm / 120 * 10, 1e-6));

      // Cumulative columns are what a pilot reads down the nav log.
      expect(legs[1].cumulativeDistanceNm, closeTo(2 * legNm, 1e-5));
      expect(legs[1].cumulativeTimeHr, closeTo(2 * legNm / 120, 1e-7));
      expect(legs[1].from, equals('B'));
      expect(legs[1].to, equals('C'));
    });

    test('fewer than two points produces no legs', () {
      expect(service.computeNavLog([]), isEmpty);
      expect(service.computeNavLog([wp('A', 0, 0)]), isEmpty);
    });

    test('leg time formats as hours and minutes', () {
      final legs = service.computeNavLog(
        [wp('A', 0, 0), wp('B', 0, 3)],
        groundSpeedKts: 100,
      );
      // 180.12 NM at 100 kt = 1.80 hr = 108 min = 1h 48m.
      expect(legs.single.timeHms, equals('1h 48m'));
    });

    test('a sub-hour leg omits the hours field', () {
      final legs = service.computeNavLog(
        [wp('A', 0, 0), wp('B', 0, 0.5)],
        groundSpeedKts: 120,
      );
      expect(legs.single.timeHms, equals('15m'));
    });
  });

  group('FAA flight plan string', () {
    test('carries the fields a briefer reads back', () {
      final plan = FlightPlan(
        id: 'p1',
        name: 'Test',
        departure: 'KPAO',
        destination: 'KMRY',
        alternate: 'KSNS',
        aircraftType: 'C172',
        tailNumber: 'N12345',
        cruiseAltitude: 4500,
        cruiseSpeed: 110,
        flightRules: 'VFR',
        etd: DateTime.utc(2026, 5, 1, 9, 5),
        estimatedTime: 1.5,
        route: 'KPAO V25 KMRY',
        remarks: 'Flight following',
        createdAt: DateTime.utc(2026, 5, 1),
      );

      final s = service.generateFaaFlightPlanString(plan);

      expect(s, contains('TYPE: VFR'));
      expect(s, contains('AIRCRAFT: C172 / N12345'));
      expect(s, contains('DEPARTURE: KPAO'));
      expect(s, contains('DESTINATION: KMRY'));
      expect(s, contains('ALTERNATE: KSNS'));
      expect(s, contains('CRUISE ALT: 4500 ft MSL'));
      // ETD is zulu HHMM and ETE is HHMM: 1.5 hr must be 0130, not "1.5".
      expect(s, contains('ETD: 0905Z'));
      expect(s, contains('ETE: 0130'));
      expect(s, contains('ROUTE: KPAO V25 KMRY'));
    });

    test('a missing alternate reads NONE rather than null', () {
      final plan = FlightPlan(
        id: 'p2',
        name: 'Test',
        departure: 'KPAO',
        destination: 'KSQL',
        createdAt: DateTime.utc(2026, 5, 1),
      );
      final s = service.generateFaaFlightPlanString(plan);
      expect(s, contains('ALTERNATE: NONE'));
      expect(s, isNot(contains('null')));
    });

    test('with no explicit route the waypoint idents are used', () {
      final plan = FlightPlan(
        id: 'p3',
        name: 'Test',
        departure: 'KPAO',
        destination: 'KMRY',
        waypoints: [wp('KPAO', 37.46, -122.11), wp('KMRY', 36.58, -121.84)],
        createdAt: DateTime.utc(2026, 5, 1),
      );
      expect(
        service.generateFaaFlightPlanString(plan),
        contains('ROUTE: KPAO KMRY'),
      );
    });
  });

  group('plan persistence', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    FlightPlan makePlan(String id, DateTime created) => FlightPlan(
          id: id,
          name: id,
          departure: 'KPAO',
          destination: 'KSQL',
          waypoints: [wp('KPAO', 37.46, -122.11)],
          createdAt: created,
        );

    test('a saved plan survives a restart', () async {
      final a = FlightPlanService();
      await a.savePlan(makePlan('p1', DateTime.utc(2026, 1, 2)));

      // A brand-new service is what the next launch gets.
      final b = FlightPlanService();
      await b.loadPlans();

      expect(b.plans, hasLength(1));
      expect(b.plans.single.id, equals('p1'));
      expect(b.plans.single.waypoints.single.identifier, equals('KPAO'));
    });

    test('plans come back newest first', () async {
      final a = FlightPlanService();
      await a.savePlan(makePlan('old', DateTime.utc(2026, 1, 1)));
      await a.savePlan(makePlan('new', DateTime.utc(2026, 3, 1)));

      final b = FlightPlanService();
      await b.loadPlans();
      expect(b.plans.map((p) => p.id), equals(['new', 'old']));
    });

    test('saving the same id updates rather than duplicates', () async {
      final s = FlightPlanService();
      await s.savePlan(makePlan('p1', DateTime.utc(2026, 1, 1)));
      await s.savePlan(FlightPlan(
        id: 'p1',
        name: 'renamed',
        departure: 'KSJC',
        destination: 'KSQL',
        createdAt: DateTime.utc(2026, 1, 1),
      ));
      expect(s.plans, hasLength(1));
      expect(s.plans.single.name, equals('renamed'));
    });

    test('a deleted plan stays deleted after a restart', () async {
      final a = FlightPlanService();
      await a.savePlan(makePlan('p1', DateTime.utc(2026, 1, 1)));
      await a.deletePlan('p1');

      final b = FlightPlanService();
      await b.loadPlans();
      expect(b.plans, isEmpty);
    });

    test('corrupt stored data does not throw', () async {
      SharedPreferences.setMockInitialValues({
        'flight_plans': ['{not json at all'],
      });
      final s = FlightPlanService();
      await s.loadPlans();
      // Current behaviour: the whole store is replaced by the demo plans.
      // Asserted so a change of policy is a deliberate decision, not a silent
      // one — losing a pilot's saved plans to one bad row is a real risk.
      expect(s.isLoading, isFalse);
      expect(s.plans, isNotEmpty);
    });

    test('a plan with an unparseable created date does not take the app down',
        () async {
      SharedPreferences.setMockInitialValues({
        'flight_plans': [
          jsonEncode({'id': 'x', 'name': 'x', 'createdAt': 'never'}),
        ],
      });
      final s = FlightPlanService();
      await s.loadPlans();
      expect(s.isLoading, isFalse);
    });
  });
}
