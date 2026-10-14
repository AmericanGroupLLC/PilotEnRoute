/// Decoding of recorded real aviationweather.gov answers (captured
/// 2026-10-14T13:03:13Z, see each fixture's header).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/core/weather/awc_models.dart';

import '../support/awc_fixtures.dart';

void main() {
  test('fixtures carry their UTC capture time and request', () {
    for (final name in ['metar_KPAO', 'taf_KSJC', 'airport_KPAO']) {
      final doc = fixtureDoc(name);
      expect(capturedAt(name), DateTime.utc(2026, 10, 14, 13, 3, 13));
      expect(doc['_request'], startsWith('GET https://aviationweather.gov/api/data/'));
    }
  });

  group('METAR', () {
    test('KPAO: calm-ish wind, "10+" visibility, sky clear = no ceiling', () {
      final m = MetarObservation.fromJson(first('metar_KPAO'));
      expect(m.icao, 'KPAO');
      expect(m.raw, 'METAR KPAO 140347Z 28005KT 10SM SKC 16/03 A3010 RMK LAST');
      expect(m.observedUtc, DateTime.utc(2026, 10, 14, 3, 47));
      expect(m.wind!.directionTrue, 280);
      expect(m.wind!.speedKt, 5);
      expect(m.wind!.gustKt, isNull);
      expect(m.visibility!.miles, 10);
      expect(m.visibility!.orMore, isTrue);
      expect(m.visibility!.text, '10+ sm');
      expect(m.ceilingFt, isNull, reason: 'none reported is not zero');
      expect(m.flightCategory, 'VFR');
      expect(m.altimeterHpa, closeTo(1019.4, 1e-9));
      expect(m.altimeterInHg, closeTo(30.10, 0.01));
    });

    test('KDLH: gusts and an overcast ceiling', () {
      final m = MetarObservation.fromJson(first('metar_KDLH'));
      expect(m.wind!.text, '360° 12 G18 kt');
      expect(m.ceilingFt, 1300);
      expect(m.flightCategory, 'MVFR');
    });

    test('KMBG: calm, 1/4 sm, vertical visibility 100 ft', () {
      final m = MetarObservation.fromJson(first('metar_KMBG'));
      expect(m.wind!.calm, isTrue);
      expect(m.wind!.text, 'Calm');
      expect(m.visibility!.miles, 0.25);
      expect(m.visibility!.text, '1/4 sm');
      expect(m.ceilingFt, 100);
    });

    test('KPIA: VRB wind has no direction', () {
      final m = MetarObservation.fromJson(first('metar_KPIA'));
      expect(m.wind!.variable, isTrue);
      expect(m.wind!.directionTrue, isNull);
      expect(m.wind!.text, 'VRB 4 kt');
    });

    test('KACK: a plain number visibility', () {
      final m = MetarObservation.fromJson(first('metar_KACK'));
      expect(m.visibility!.miles, 7);
      expect(m.visibility!.orMore, isFalse);
    });

    test('stale: KPAO\'s last report was 9 h old at capture', () {
      final m = MetarObservation.fromJson(first('metar_KPAO'));
      final at = capturedAt('metar_KPAO');
      expect(m.ageMinutes(at), 556);
      expect(m.isStale(at), isTrue);
    });

    test('stale: 90 minutes is not stale, 91 is', () {
      final m = MetarObservation.fromJson(first('metar_KDLH'));
      final obs = m.observedUtc!;
      expect(m.isStale(obs.add(const Duration(minutes: 90))), isFalse);
      expect(m.isStale(obs.add(const Duration(minutes: 91))), isTrue);
    });

    test('an empty object decodes with nothing invented', () {
      final m = MetarObservation.fromJson(const {});
      expect(m.icao, isEmpty);
      expect(m.wind, isNull);
      expect(m.visibility, isNull);
      expect(m.ceilingFt, isNull);
      expect(m.observedUtc, isNull);
      expect(m.isStale(DateTime.now()), isTrue);
    });
  });

  group('visibility strings', () {
    const cases = <(Object?, double?, bool, bool)>[
      ('10+', 10, true, false),
      ('6+', 6, true, false),
      ('P6SM', 6, true, false),
      ('1/4', 0.25, false, false),
      ('M1/4', 0.25, false, true),
      ('1 1/2', 1.5, false, false),
      (7, 7, false, false),
      (0.25, 0.25, false, false),
      ('', null, false, false),
      (null, null, false, false),
      ('abc', null, false, false),
    ];
    for (final c in cases) {
      test('"${c.$1}" -> ${c.$2}', () {
        final v = Visibility.parse(c.$1);
        if (c.$2 == null) {
          expect(v, isNull);
        } else {
          expect(v!.miles, closeTo(c.$2!, 1e-9));
          expect(v.orMore, c.$3);
          expect(v.orLess, c.$4);
        }
      });
    }
  });

  group('ceiling', () {
    test('the lowest BKN/OVC counts, FEW/SCT never do', () {
      expect(
          ceilingFrom(const [
            CloudLayer('FEW', 800),
            CloudLayer('SCT', 1200),
            CloudLayer('BKN', 2500),
            CloudLayer('OVC', 4000),
          ]),
          2500);
    });
    test('scattered only is no ceiling', () {
      expect(ceilingFrom(const [CloudLayer('SCT', 900)]), isNull);
    });
    test('no layers is no ceiling, not zero', () {
      expect(ceilingFrom(const []), isNull);
    });
    test('an obscured sky uses the vertical visibility', () {
      expect(ceilingFrom(const [CloudLayer('OVX', null)], vertVisFt: 100), 100);
    });
  });

  group('TAF', () {
    test('KSJC: four groups with times, FM changes and "6+"', () {
      final t = TafReport.fromJson(first('taf_KSJC'));
      expect(t.raw, startsWith('TAF KSJC 141138Z 1412/1512'));
      expect(t.groups, hasLength(4));
      expect(t.groups[0].label, 'Base');
      expect(t.groups[0].fromUtc, DateTime.utc(2026, 10, 14, 12));
      expect(t.groups[0].toUtc, DateTime.utc(2026, 10, 14, 19));
      expect(t.groups[1].label, 'FM');
      expect(t.groups[1].wind!.text, '330° 10 kt');
      expect(t.groups[3].wind!.variable, isTrue);
      expect(t.groups[0].visibility!.text, '6+ sm');
    });

    test('KMBG: TEMPO and PROB30 groups, vertical visibility in feet', () {
      final t = TafReport.fromJson(first('taf_KMBG'));
      expect(t.groups[0].ceilingFt, 100,
          reason: 'TAF vertVis is feet (100), unlike the METAR (1)');
      expect(t.groups[1].label, 'TEMPO');
      expect(t.groups[1].isTemporary, isTrue);
      expect(t.groups[1].ceilingFt, 1400);
      final prob = t.groups.firstWhere((g) => g.probability != null);
      expect(prob.label, 'PROB30');
      expect(prob.visibility, isNull, reason: 'AWC sends "" when absent');
    });

    test('groups in force within a window', () {
      final t = TafReport.fromJson(first('taf_KSJC'));
      final g = t.groupsBetween(DateTime.utc(2026, 10, 14, 17, 30),
          DateTime.utc(2026, 10, 14, 19, 30));
      expect(g.map((x) => x.label), ['Base', 'FM']);
      final later = t.groupsBetween(DateTime.utc(2026, 10, 14, 21),
          DateTime.utc(2026, 10, 14, 23));
      expect(later, hasLength(1));
    });

    test('KPAO issues no TAF: the body is an empty list', () {
      expect(fixture('taf_KPAO'), isEmpty);
    });
  });

  group('airport', () {
    test('KPAO: 13/31 with true alignment 142, magdec 15E', () {
      final a = AirportReference.fromJson(first('airport_KPAO'));
      expect(a.icao, 'KPAO');
      expect(a.magneticVariation, '15E');
      expect(a.runwayInfo.single.id, '13/31');
      expect(a.runwayInfo.single.alignmentTrue, 142);
      final ends = a.runwayInfo.single.ends;
      expect(ends.map((e) => e.name), ['13', '31']);
      expect(ends.map((e) => e.headingTrue), [142, 322]);
      // 142 true - 15 E = 127 magnetic: runway 13. Alignment is true.
      expect(142 - 15, inInclusiveRange(125, 135));
    });

    test('runway ends wrap past 360', () {
      const r = RunwayInfo(id: '33/15', alignmentTrue: 315);
      expect(r.ends.map((e) => e.headingTrue), [315, 135]);
    });

    test('helipads and missing alignments give no ends', () {
      expect(const RunwayInfo(id: 'H1', alignmentTrue: 90).ends, isEmpty);
      expect(const RunwayInfo(id: '13/31', alignmentTrue: null).ends, isEmpty);
    });
  });
}
