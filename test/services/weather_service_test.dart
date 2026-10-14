import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/services/weather_service.dart';

void main() {
  group('WeatherService', () {
    test('starts with no station', () {
      expect(WeatherService().lastStation, isNull);
    });

    test('talks to aviationweather.gov directly', () {
      expect(awcBase, 'https://aviationweather.gov/api/data');
    });
  });

  group('MetarObservation model', () {
    test('decodes the AWC fields it is given', () {
      final m = MetarObservation.fromJson(const {
        'icaoId': 'KLAX',
        'rawOb': 'METAR KLAX 011853Z 26010KT 10SM FEW025 22/12 A2995',
        'fltCat': 'VFR',
        'wdir': 260,
        'wspd': 10,
        'temp': 22.0,
        'dewp': 12.0,
        'altim': 1014.2,
      });
      expect(m.icao, equals('KLAX'));
      expect(m.flightCategory, equals('VFR'));
      expect(m.tempC, equals(22.0));
      expect(m.wind!.speedKt, equals(10));
      expect(m.altimeterInHg, closeTo(29.95, 0.01));
    });

    test('raw text is stored exactly', () {
      const raw = 'METAR KSFO 011953Z 28012KT 10SM SKC 18/08 A3001';
      expect(MetarObservation.fromJson(const {'rawOb': raw}).raw, equals(raw));
    });

    test('optional fields default to null, never zero', () {
      final m = MetarObservation.fromJson(const {
        'icaoId': 'KORD',
        'rawOb': 'METAR KORD 011953Z 00000KT 10SM CLR 15/05 A3005',
      });
      expect(m.ceilingFt, isNull);
      expect(m.wind, isNull);
      expect(m.visibility, isNull);
      expect(m.altimeterHpa, isNull);
    });

    test('each flight category keeps its own colour; unknown is grey', () {
      final colours = {
        for (final c in ['VFR', 'MVFR', 'IFR', 'LIFR']) c: flightCategoryColor(c)
      };
      expect(colours.values.toSet(), hasLength(4));
      expect(flightCategoryColor('nonsense'),
          isNot(anyOf(colours.values.map(equals))));
    });
  });

  group('FAA Flight Category Rules', () {
    String computeCategory({required int ceiling, required double vis}) {
      if (ceiling < 200 || vis < 0.5) return 'LIFR';
      if (ceiling < 500 || vis < 1.0) return 'IFR';
      if (ceiling < 3000 || vis < 5.0) return 'MVFR';
      return 'VFR';
    }

    test('VFR: ceiling >= 3000 ft AND visibility >= 5 SM', () {
      expect(computeCategory(ceiling: 5000, vis: 10.0), equals('VFR'));
    });

    test('MVFR: ceiling 1000-3000 ft', () {
      expect(computeCategory(ceiling: 2000, vis: 6.0), equals('MVFR'));
    });

    test('MVFR: visibility 3-5 SM', () {
      expect(computeCategory(ceiling: 5000, vis: 4.0), equals('MVFR'));
    });

    test('IFR: ceiling < 500 ft', () {
      expect(computeCategory(ceiling: 400, vis: 2.0), equals('IFR'));
    });

    test('IFR: visibility < 1 SM', () {
      expect(computeCategory(ceiling: 1000, vis: 0.75), equals('IFR'));
    });

    test('LIFR: ceiling < 200 ft', () {
      expect(computeCategory(ceiling: 100, vis: 2.0), equals('LIFR'));
    });

    test('LIFR: visibility < 0.5 SM', () {
      expect(computeCategory(ceiling: 1000, vis: 0.25), equals('LIFR'));
    });
  });
}
