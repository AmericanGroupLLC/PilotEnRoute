/// The basic flight sim: the selected aircraft drives the physics, every
/// offered scenario is implemented, and the controls move the right way.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/screens/simulation_screen.dart';

FlightSimGame _run(String aircraft, String scenario,
    {double seconds = 60, void Function(FlightSimGame)? before}) {
  final g = FlightSimGame(aircraft: aircraft, scenario: scenario);
  before?.call(g);
  for (var t = 0.0; t < seconds; t += 0.1) {
    g.step(0.1);
  }
  return g;
}

void main() {
  test('every offered aircraft has performance data', () {
    for (final a in kSimAircraft.keys) {
      expect(FlightSimGame(aircraft: a, scenario: 'Normal Cruise').performance,
          same(kSimAircraft[a]));
    }
  });

  test('cruise speed depends on the aircraft', () {
    final cessna = _run('Cessna 172', 'Normal Cruise');
    final jet = _run('Boeing 737', 'Normal Cruise');
    expect(cessna.airspeedKt, closeTo(124, 10));
    expect(jet.airspeedKt, closeTo(453, 30));
    expect(jet.altitudeFt, greaterThan(cessna.altitudeFt));
  });

  test('scenarios with no implementation are not offered', () {
    expect(kSimScenarios, isNot(contains('Emergency: Electrical Failure')));
    expect(kSimScenarios, isNot(contains('Cross-Country Navigation')));
  });

  test('the drone gets the FPV scenario; aeroplanes do not', () {
    expect(simScenariosFor('DJI Phantom (Drone)'), contains('Drone FPV Flight'));
    expect(simScenariosFor('Cessna 172'), isNot(contains('Drone FPV Flight')));
    expect(simScenariosFor('Cessna 172'), contains('Emergency: Engine Failure'));
  });

  test('engine failure descends whatever the throttle says', () {
    final g = _run('Cessna 172', 'Emergency: Engine Failure', seconds: 30,
        before: (g) {
      for (var i = 0; i < 10; i++) {
        g.increaseThrottle();
      }
    });
    expect(g.verticalSpeedFpm, lessThan(0));
    expect(g.altitudeFt, lessThan(8000));
  });

  test('UP pitches the nose up and climbs', () {
    final g = FlightSimGame(aircraft: 'Cessna 172', scenario: 'Normal Cruise');
    final start = g.altitudeFt;
    g.pitchUp();
    g.pitchUp();
    for (var i = 0; i < 100; i++) {
      g.step(0.1);
    }
    expect(g.pitchDeg, greaterThan(0));
    expect(g.altitudeFt, greaterThan(start));
  });

  test('climb never exceeds the aircraft ceiling', () {
    final g = FlightSimGame(aircraft: 'DJI Phantom (Drone)',
        scenario: 'Normal Cruise');
    g.pitchUp();
    g.pitchUp();
    g.pitchUp();
    for (var i = 0; i < 3000; i++) {
      g.step(0.1);
    }
    expect(g.altitudeFt, lessThanOrEqualTo(400));
  });
}
