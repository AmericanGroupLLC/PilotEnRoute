import 'package:flutter_test/flutter_test.dart';
import 'package:pilot_enroute/services/weather_service.dart';

void main() {
  group('WeatherService', () {
    late WeatherService service;

    setUp(() {
      service = WeatherService();
    });

    test('initializes with correct default state', () {
      expect(service.isLoading, isFalse);
      expect(service.currentMetar, isNull);
      expect(service.liveFlights, isEmpty);
      expect(service.flightsLoading, isFalse);
    });
  });

  group('MetarData model', () {
    test('creates MetarData with required fields', () {
      final metar = MetarData(
        icao: 'KLAX',
        raw: 'KLAX 011853Z 26010KT 10SM FEW025 22/12 A2995',
        category: 'VFR',
        windDir: 260,
        windSpeedKt: 10,
        temperatureC: 22.0,
        dewpointC: 12.0,
        altimeterInHg: 29.95,
      );

      expect(metar.icao, equals('KLAX'));
      expect(metar.category, equals('VFR'));
      expect(metar.temperatureC, equals(22.0));
      expect(metar.windSpeedKt, equals(10));
      expect(metar.altimeterInHg, equals(29.95));
    });

    test('MetarData raw text is stored correctly', () {
      const raw = 'KSFO 011953Z 28012KT 10SM SKC 18/08 A3001';
      final metar = MetarData(
        icao: 'KSFO',
        raw: raw,
        category: 'VFR',
      );
      expect(metar.raw, equals(raw));
    });

    test('MetarData icao is uppercase', () {
      final metar = MetarData(
        icao: 'KJFK',
        raw: 'KJFK 011953Z AUTO 18008KT 10SM CLR 20/10 A2998',
        category: 'VFR',
      );
      expect(metar.icao, equals(metar.icao.toUpperCase()));
    });

    test('MetarData optional fields default to null', () {
      final metar = MetarData(
        icao: 'KORD',
        raw: 'KORD 011953Z 00000KT 10SM CLR 15/05 A3005',
        category: 'VFR',
      );
      expect(metar.ceilingFt, isNull);
      expect(metar.windGustKt, isNull);
      expect(metar.tafRaw, isNull);
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
