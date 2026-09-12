/// Weight & balance arithmetic and persistence.
///
/// Every expected number here is hand-computed from the loading (weight × arm
/// summed to a moment, moment ÷ weight to a CG) rather than taken from the
/// implementation, because a CG that is quietly wrong by an inch is the most
/// dangerous output this app has.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/services/weight_balance_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A deliberately round-numbered aircraft so the algebra is checkable by hand:
/// empty 1000 lb at arm 40 (moment 40 000), max gross 1600.
const _synthetic = AircraftProfile(
  id: 'test_synth',
  name: 'Synthetic Trainer',
  emptyWeight: 1000,
  emptyArm: 40,
  maxGross: 1600,
  stations: [
    WBStation(name: 'Seat', arm: 30),
    WBStation(name: 'Baggage', arm: 100),
    WBStation(name: 'Fuel', arm: 50, isFuel: true, maxGallons: 10),
  ],
  envelope: [
    WBEnvelopePoint(1000, 35, 45),
    WBEnvelopePoint(1600, 38, 45),
  ],
);

void main() {
  late WeightBalanceService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = WeightBalanceService();
  });

  group('moment and CG', () {
    test('empty moment is weight times arm', () {
      expect(_synthetic.emptyMoment, equals(40000));
    });

    test('a normal load computes the hand-checked CG', () {
      // 1000@40 + 200@30 + 100@100 + (10 gal × 6 lb)@50
      //   = 40 000 + 6 000 + 10 000 + 3 000 = 59 000 lb-in over 1360 lb.
      final r = service.compute(_synthetic, {
        'Seat': 200,
        'Baggage': 100,
        'Fuel': 10,
      });

      expect(r.totalWeight, equals(1360));
      expect(r.totalMoment, equals(59000));
      expect(r.cg, closeTo(43.3824, 0.0001));
      expect(r.hasCg, isTrue);
      expect(r.weightOk, isTrue);
      expect(r.cgOk, isTrue);
    });

    test('fuel input is gallons and is converted at 6 lb per gallon', () {
      // The single most damaging unit slip in this screen: treating the fuel
      // field as pounds would put this aircraft 50 lb light.
      expect(kFuelWeightPerGallon, equals(6.0));
      final r = service.compute(_synthetic, {'Fuel': 10});
      expect(r.totalWeight, equals(1060));
      expect(r.totalMoment, equals(40000 + 60 * 50));
    });

    test('a station with no entry contributes nothing', () {
      final r = service.compute(_synthetic, {});
      expect(r.totalWeight, equals(1000));
      expect(r.cg, equals(40));
    });

    test('an aft-loaded aircraft is flagged out of CG but not overweight', () {
      // 300 lb of baggage at arm 100 drags the CG to 50.6 in, past the 45 in
      // aft limit, while the total is still under gross.
      final r = service.compute(_synthetic, {'Seat': 200, 'Baggage': 300, 'Fuel': 10});
      expect(r.totalWeight, equals(1560));
      expect(r.cg, closeTo(50.641, 0.001));
      expect(r.weightOk, isTrue);
      expect(r.cgOk, isFalse);
    });

    test('a nose-heavy aircraft is flagged out of CG', () {
      // 500 lb in the forward seat, nothing aft: CG 36.67 in against a 37.5 in
      // forward limit interpolated at 1500 lb.
      final r = service.compute(_synthetic, {'Seat': 500});
      expect(r.totalWeight, equals(1500));
      expect(r.cg, closeTo(36.6667, 0.0001));
      expect(r.fwdLimit, closeTo(37.5, 1e-9));
      expect(r.cgOk, isFalse);
    });

    test('an overweight aircraft is never reported as in limits', () {
      final r = service.compute(_synthetic, {'Seat': 600, 'Baggage': 100});
      expect(r.totalWeight, equals(1700));
      expect(r.weightOk, isFalse);
      // Even if the CG itself happened to fall inside the envelope, an
      // overweight aeroplane must not show a green "within limits".
      expect(r.cgOk, isFalse);
    });

    test('below the bottom of the envelope is also out of limits', () {
      final light = AircraftProfile(
        id: 'light',
        name: 'light',
        emptyWeight: 800,
        emptyArm: 40,
        maxGross: _synthetic.maxGross,
        stations: _synthetic.stations,
        envelope: _synthetic.envelope,
      );
      final r = service.compute(light, {});
      expect(r.totalWeight, equals(800));
      expect(r.weightOk, isFalse,
          reason: '800 lb is below the 1000 lb bottom of the envelope');
    });

    test('a zero-weight profile reports no CG instead of a NaN', () {
      const zero = AircraftProfile(
        id: 'zero',
        name: 'zero',
        emptyWeight: 0,
        emptyArm: 0,
        maxGross: 1000,
        stations: [],
        envelope: [],
      );
      final r = service.compute(zero, {});
      expect(r.hasCg, isFalse);
      expect(r.cg.isNaN, isTrue);
      expect(r.cgOk, isFalse);
    });
  });

  group('CG envelope interpolation', () {
    test('halfway up the envelope gives the midpoint forward limit', () {
      expect(service.cgLimitsAt(_synthetic, 1300), equals([36.5, 45.0]));
    });

    test('below the first point clamps to the first point', () {
      expect(service.cgLimitsAt(_synthetic, 500), equals([35.0, 45.0]));
    });

    test('above the last point clamps to the last point', () {
      expect(service.cgLimitsAt(_synthetic, 5000), equals([38.0, 45.0]));
    });

    test('an empty envelope imposes no limit rather than rejecting everything',
        () {
      const noEnvelope = AircraftProfile(
        id: 'none',
        name: 'none',
        emptyWeight: 1000,
        emptyArm: 40,
        maxGross: 2000,
        stations: [],
        envelope: [],
      );
      final limits = service.cgLimitsAt(noEnvelope, 1500);
      expect(limits[0], equals(double.negativeInfinity));
      expect(limits[1], equals(double.infinity));
    });
  });

  group('built-in Cessna 172S', () {
    AircraftProfile c172() =>
        service.profiles.firstWhere((p) => p.id == 'builtin_c172s');

    test('a typical trainer load is inside limits', () {
      // 1680@40 + 340@37 + 20@95 + (40 gal × 6)@48 = 93 200 lb-in / 2280 lb.
      final r = service.compute(c172(), {
        'Front seats (pilot + pax)': 340,
        'Baggage area 1': 20,
        'Fuel': 40,
      });
      expect(r.totalWeight, equals(2280));
      expect(r.totalMoment, equals(93200));
      expect(r.cg, closeTo(40.8772, 0.0001));
      expect(r.fwdLimit, closeTo(38.3, 1e-9));
      expect(r.aftLimit, closeTo(47.3, 1e-9));
      expect(r.cgOk, isTrue);
    });

    test('two heavy adults up front with full fuel is forward of the limit',
        () {
      // The classic C172 forward-CG trap: 2498 lb, CG 40.42 in against a
      // 40.48 in interpolated forward limit.
      final r = service.compute(c172(), {
        'Front seats (pilot + pax)': 500,
        'Fuel': 53,
      });
      expect(r.totalWeight, equals(2498));
      expect(r.cg, closeTo(40.4179, 0.0001));
      expect(r.fwdLimit, closeTo(40.48, 1e-9));
      expect(r.weightOk, isTrue);
      expect(r.cgOk, isFalse);
    });

    test('a full cabin with full fuel exceeds max gross', () {
      final r = service.compute(c172(), {
        'Front seats (pilot + pax)': 400,
        'Rear seats': 340,
        'Baggage area 1': 120,
        'Fuel': 53,
      });
      expect(r.totalWeight, equals(2858));
      expect(r.weightOk, isFalse);
    });

    test('the three shipped profiles all declare an ascending envelope', () {
      for (final p in service.profiles) {
        expect(p.envelope, isNotEmpty, reason: p.name);
        expect(p.maxGross, greaterThan(p.emptyWeight), reason: p.name);
        for (var i = 1; i < p.envelope.length; i++) {
          expect(p.envelope[i].weight, greaterThan(p.envelope[i - 1].weight),
              reason: '${p.name}: cgLimitsAt interpolates assuming ascending '
                  'weights');
        }
        for (final pt in p.envelope) {
          expect(pt.aftCG, greaterThan(pt.fwdCG), reason: p.name);
        }
      }
    });
  });

  group('performance estimates', () {
    test('density altitude on a standard day equals pressure altitude', () {
      expect(WeightBalanceService.densityAltitude(0, 15), closeTo(0, 1e-9));
    });

    test('5000 ft PA at 30 C gives 7988 ft density altitude', () {
      // ISA at 5000 ft = 15 - 1.98×5 = 5.1 C; 30 - 5.1 = 24.9; ×120 = 2988.
      expect(
        WeightBalanceService.densityAltitude(5000, 30),
        closeTo(7988, 0.001),
      );
    });

    test('a cold day puts density altitude below field elevation', () {
      expect(WeightBalanceService.densityAltitude(2000, -20),
          lessThan(2000));
    });

    test('takeoff factor is 1.0 at sea level and +10% per 1000 ft', () {
      expect(WeightBalanceService.takeoffFactor(0), equals(1.0));
      expect(WeightBalanceService.takeoffFactor(5000), closeTo(1.5, 1e-9));
    });

    test('a negative density altitude never shortens the predicted roll', () {
      // Optimism here would be a safety issue, so the factor floors at 1.0.
      expect(WeightBalanceService.takeoffFactor(-3000), equals(1.0));
    });
  });

  group('serialisation', () {
    test('a profile round-trips through JSON', () {
      final restored =
          AircraftProfile.fromJson(jsonDecode(jsonEncode(_synthetic.toJson())));

      expect(restored.id, equals(_synthetic.id));
      expect(restored.emptyWeight, equals(1000));
      expect(restored.emptyArm, equals(40));
      expect(restored.maxGross, equals(1600));
      expect(restored.stations, hasLength(3));
      expect(restored.stations[2].isFuel, isTrue);
      expect(restored.stations[2].maxGallons, equals(10));
      expect(restored.envelope, hasLength(2));
      expect(restored.envelope[1].fwdCG, equals(38));

      // The restored profile must compute the same numbers as the original.
      final a = service.compute(_synthetic, {'Seat': 200, 'Fuel': 5});
      final b = service.compute(restored, {'Seat': 200, 'Fuel': 5});
      expect(b.totalWeight, equals(a.totalWeight));
      expect(b.cg, equals(a.cg));
    });

    test('a JSON object missing every field decodes to safe zeros', () {
      final p = AircraftProfile.fromJson(const {});
      expect(p.emptyWeight, equals(0));
      expect(p.stations, isEmpty);
      expect(p.envelope, isEmpty);
      expect(p.name, equals('Custom Aircraft'));
    });
  });

  group('persistence', () {
    test('a custom aircraft survives a restart', () async {
      await service.init();
      await service.addOrUpdateCustom(_synthetic);

      final next = WeightBalanceService();
      await next.init();

      expect(next.profiles.map((p) => p.id), contains('test_synth'));
      final restored =
          next.profiles.firstWhere((p) => p.id == 'test_synth');
      expect(restored.emptyWeight, equals(1000));
    });

    test('the loading for the active aircraft survives a restart', () async {
      await service.init();
      await service.addOrUpdateCustom(_synthetic);
      await service.setActiveProfile('test_synth');
      await service.setStationValue('Seat', 180);
      await service.setStationValue('Fuel', 8);

      final next = WeightBalanceService();
      await next.init();

      expect(next.activeProfile.id, equals('test_synth'));
      expect(next.stationValue('Seat'), equals(180));
      expect(next.stationValue('Fuel'), equals(8));
    });

    test('each aircraft keeps its own loading', () async {
      await service.init();
      await service.addOrUpdateCustom(_synthetic);
      await service.setStationValue('Front seats (pilot + pax)', 400);
      await service.setActiveProfile('test_synth');

      // Switching aircraft must not carry the previous aeroplane's weights
      // across — that would silently compute a CG for the wrong loading.
      expect(service.stationValue('Front seats (pilot + pax)'), equals(0));
    });

    test('deleting the active custom aircraft falls back to a built-in',
        () async {
      await service.init();
      await service.addOrUpdateCustom(_synthetic);
      await service.setActiveProfile('test_synth');
      await service.deleteCustom('test_synth');

      expect(service.activeProfile.isBuiltIn, isTrue);
      expect(service.profiles.map((p) => p.id), isNot(contains('test_synth')));
    });

    test('corrupt stored profiles fall back to the built-ins instead of '
        'crashing the screen', () async {
      SharedPreferences.setMockInitialValues({
        'wb_custom_profiles': '{ this is not json',
        'wb_active_id': 'test_synth',
      });
      final s = WeightBalanceService();
      await s.init();

      expect(s.isLoaded, isTrue);
      expect(s.profiles, hasLength(3));
      expect(s.activeProfile.isBuiltIn, isTrue);
    });

    test('a corrupt loading map does not poison the computation', () async {
      SharedPreferences.setMockInitialValues({
        'wb_active_id': 'builtin_c172s',
        'wb_loading_builtin_c172s': '[1,2,3]',
      });
      final s = WeightBalanceService();
      await s.init();

      expect(s.loading, isEmpty);
      expect(s.compute(s.activeProfile, s.loading).totalWeight, equals(1680));
    });

    test('an unknown active id resolves to the first profile rather than '
        'throwing', () async {
      SharedPreferences.setMockInitialValues({'wb_active_id': 'gone'});
      final s = WeightBalanceService();
      await s.init();
      expect(s.activeProfile.id, equals('builtin_c172s'));
    });
  });
}
