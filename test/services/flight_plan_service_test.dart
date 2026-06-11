import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/services/flight_plan_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('FlightPlan model', () {
    test('creates FlightPlan with required fields', () {
      final plan = FlightPlan(
        id: 'fp-001',
        name: 'KLAX to KSFO',
        departure: 'KLAX',
        destination: 'KSFO',
        createdAt: DateTime(2026, 1, 1),
      );
      expect(plan.id, equals('fp-001'));
      expect(plan.departure, equals('KLAX'));
      expect(plan.destination, equals('KSFO'));
      expect(plan.name, equals('KLAX to KSFO'));
    });

    test('FlightPlan has correct defaults', () {
      final plan = FlightPlan(
        id: 'fp-002',
        name: 'Test Flight',
        departure: 'KORD',
        destination: 'KJFK',
        createdAt: DateTime.now(),
      );
      expect(plan.aircraftType, equals('C172'));
      expect(plan.flightRules, equals('VFR'));
      expect(plan.cruiseAltitude, equals(3500));
      expect(plan.cruiseSpeed, equals(120));
      expect(plan.waypoints, isEmpty);
      expect(plan.remarks, isEmpty);
    });

    test('toJson produces correct keys', () {
      final plan = FlightPlan(
        id: 'fp-003',
        name: 'KSFO to KLAS',
        departure: 'KSFO',
        destination: 'KLAS',
        aircraftType: 'PA28',
        flightRules: 'IFR',
        cruiseAltitude: 8000,
        createdAt: DateTime(2026, 6, 1),
      );
      final json = plan.toJson();
      expect(json['id'], equals('fp-003'));
      expect(json['departure'], equals('KSFO'));
      expect(json['destination'], equals('KLAS'));
      expect(json['aircraftType'], equals('PA28'));
      expect(json['flightRules'], equals('IFR'));
      expect(json['cruiseAltitude'], equals(8000));
    });

    test('fromJson round-trips correctly', () {
      final original = FlightPlan(
        id: 'fp-004',
        name: 'KBOS to KPVD',
        departure: 'KBOS',
        destination: 'KPVD',
        aircraftType: 'C172',
        cruiseAltitude: 3000,
        createdAt: DateTime(2026, 3, 15),
      );
      final json = original.toJson();
      final restored = FlightPlan.fromJson(json);
      expect(restored.id, equals(original.id));
      expect(restored.departure, equals(original.departure));
      expect(restored.destination, equals(original.destination));
      expect(restored.cruiseAltitude, equals(original.cruiseAltitude));
    });

    test('FlightPlan supports IFR flight rules', () {
      final plan = FlightPlan(
        id: 'fp-005',
        name: 'IFR Flight',
        departure: 'KSEA',
        destination: 'KPDX',
        flightRules: 'IFR',
        cruiseAltitude: 6000,
        createdAt: DateTime.now(),
      );
      expect(plan.flightRules, equals('IFR'));
      expect(plan.cruiseAltitude, equals(6000));
    });
  });

  group('FlightPlanService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('initializes with empty plans list', () {
      final service = FlightPlanService();
      expect(service.plans, isEmpty);
    });
  });
}
