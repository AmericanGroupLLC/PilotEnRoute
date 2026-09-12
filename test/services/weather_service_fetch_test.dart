/// Weather fetching and decoding.
///
/// The existing `weather_service_test.dart` checks the METAR model's fields
/// and a flight-category table that is defined inside that test file; these
/// tests drive the service's real network paths with a stubbed client so a
/// change to the decoding or the error handling actually fails something.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pilot_enroute/services/weather_service.dart';

Future<T> withHttp<T>(
  Future<T> Function() body,
  Future<http.Response> Function(http.Request) handler,
) =>
    http.runWithClient(body, () => MockClient(handler));

void main() {
  group('METAR decoding', () {
    test('a full payload maps onto every field', () {
      final m = MetarData.fromJson({
        'icao': 'KSFO',
        'raw': 'KSFO 011953Z 28012KT 10SM SKC 18/08 A3001',
        'category': 'VFR',
        'ceilingFt': 12000,
        'windDir': 280,
        'windSpeedKt': 12,
        'windGustKt': 20,
        'temperatureC': 18.0,
        'dewpointC': 8.0,
        'altimeterInHg': 30.01,
        'visibilitySm': 10,
        'taf': {'raw': 'TAF KSFO ...'},
      });

      expect(m.icao, equals('KSFO'));
      expect(m.ceilingFt, equals(12000));
      expect(m.windGustKt, equals(20));
      expect(m.altimeterInHg, closeTo(30.01, 1e-9));
      expect(m.visibilitySm, equals(10.0));
      expect(m.tafRaw, equals('TAF KSFO ...'));
    });

    test('visibility survives the "10+" form the feeds emit', () {
      // A raw double.parse on "10+" throws and loses the whole report.
      expect(MetarData.fromJson({'visib': '10+'}).visibilitySm, equals(10.0));
      expect(MetarData.fromJson({'visibility': '6'}).visibilitySm, equals(6.0));
      expect(MetarData.fromJson({'visibilitySm': 2.5}).visibilitySm,
          equals(2.5));
    });

    test('an absent visibility is null rather than zero', () {
      // Zero visibility is a real, alarming value; it must not mean "unknown".
      expect(MetarData.fromJson(const {}).visibilitySm, isNull);
    });

    test('a payload with nothing in it still decodes to a usable object', () {
      final m = MetarData.fromJson(const {});
      expect(m.icao, isEmpty);
      expect(m.raw, isEmpty);
      expect(m.category, equals('VFR'));
      expect(m.ceilingFt, isNull);
    });

    test('each flight category has its own colour and an unknown one is grey',
        () {
      // The colour is the only at-a-glance signal on the weather card, so a
      // duplicate or a wrong mapping is a real hazard.
      final colours = {
        for (final c in ['VFR', 'MVFR', 'IFR', 'LIFR'])
          c: MetarData(icao: 'X', raw: '', category: c).categoryColor,
      };
      expect(colours.values.toSet(), hasLength(4));
      expect(
        MetarData(icao: 'X', raw: '', category: 'nonsense').categoryColor,
        isNot(anyOf(colours.values.map(equals))),
      );
    });
  });

  group('fetchMetar', () {
    test('a good response becomes the current report', () async {
      final s = WeatherService();
      Uri? requested;

      final result = await withHttp(() => s.fetchMetar('ksfo'), (req) async {
        requested = req.url;
        return http.Response(
          jsonEncode({
            'icao': 'KSFO',
            'raw': 'KSFO 011953Z 28012KT 10SM SKC 18/08 A3001',
            'category': 'VFR',
            'taf': {'raw': 'TAF KSFO'},
          }),
          200,
        );
      });

      expect(result, isNotNull);
      expect(s.currentMetar?.icao, equals('KSFO'));
      expect(s.currentMetar?.tafRaw, equals('TAF KSFO'));
      expect(s.isLoading, isFalse);
      expect(s.error, isNull);
      // The station is upper-cased before it reaches the API.
      expect(requested.toString(), contains('icao=KSFO'));
      expect(requested.toString(), contains('taf=1'));
    });

    test('taf=1 is omitted when the TAF is not wanted', () async {
      final s = WeatherService();
      Uri? requested;
      await withHttp(() => s.fetchMetar('KSFO', includeTaf: false), (req) async {
        requested = req.url;
        return http.Response('{}', 200);
      });
      expect(requested.toString(), isNot(contains('taf=1')));
    });

    test('a 404 reports the station, clears loading and returns null',
        () async {
      final s = WeatherService();
      final result = await withHttp(
        () => s.fetchMetar('ZZZZ'),
        (_) async => http.Response('not found', 404),
      );

      expect(result, isNull);
      expect(s.isLoading, isFalse,
          reason: 'a stuck spinner is how this failure reaches the user');
      expect(s.error, contains('ZZZZ'));
    });

    test('an offline fetch reports an error instead of throwing', () async {
      final s = WeatherService();
      final result = await withHttp(
        () => s.fetchMetar('KSFO'),
        (_) => Future.error(Exception('offline')),
      );

      expect(result, isNull);
      expect(s.isLoading, isFalse);
      expect(s.error, isNotNull);
    });

    test('a malformed body is an error, not a half-built report', () async {
      final s = WeatherService();
      final result = await withHttp(
        () => s.fetchMetar('KSFO'),
        (_) async => http.Response('<html>down</html>', 200),
      );

      expect(result, isNull);
      expect(s.currentMetar, isNull);
      expect(s.isLoading, isFalse);
      expect(s.error, isNotNull);
    });
  });

  group('live traffic', () {
    List<dynamic> state(String icao, {double? lat, double? lon}) => [
          icao,
          'CALL$icao ',
          'United States',
          0,
          0,
          lon,
          lat,
          10000.0,
          false,
          420.0,
          90.0,
          0.0,
        ];

    test('a state vector maps onto a flight, trimming the callsign', () {
      final f = LiveFlight.fromStateVector(state('abc123', lat: 37.6, lon: -122.3));
      expect(f.icao24, equals('abc123'));
      expect(f.callsign, equals('CALLabc123'));
      expect(f.latitude, closeTo(37.6, 1e-9));
      expect(f.altitude, equals(10000.0));
      expect(f.onGround, isFalse);
    });

    test('aircraft with no position are dropped', () async {
      // A flight with a null lat/lon would be plotted at 0,0 in the Atlantic.
      final s = WeatherService();
      await withHttp(
        () => s.fetchLiveFlights(),
        (_) async => http.Response(
          jsonEncode({
            'states': [
              state('aaa', lat: 37.6, lon: -122.3),
              state('bbb'),
            ],
          }),
          200,
        ),
      );

      expect(s.liveFlights, hasLength(1));
      expect(s.liveFlights.single.icao24, equals('aaa'));
      expect(s.flightsLoading, isFalse);
    });

    test('short or null rows are skipped rather than throwing', () async {
      final s = WeatherService();
      await withHttp(
        () => s.fetchLiveFlights(),
        (_) async => http.Response(
          jsonEncode({
            'states': [
              null,
              ['too', 'short'],
              state('aaa', lat: 1, lon: 2),
            ],
          }),
          200,
        ),
      );
      expect(s.liveFlights, hasLength(1));
    });

    test('the plotted set is capped at 200 aircraft', () async {
      final s = WeatherService();
      await withHttp(
        () => s.fetchLiveFlights(),
        (_) async => http.Response(
          jsonEncode({
            'states': [
              for (var i = 0; i < 260; i++) state('f$i', lat: 30.0, lon: -100.0),
            ],
          }),
          200,
        ),
      );
      expect(s.liveFlights, hasLength(200));
    });

    test('the bounding box reaches the query string', () async {
      final s = WeatherService();
      Uri? requested;
      await withHttp(
        () => s.fetchLiveFlights(lamin: 30, lomin: -120, lamax: 40, lomax: -110),
        (req) async {
          requested = req.url;
          return http.Response(jsonEncode({'states': []}), 200);
        },
      );
      expect(requested!.query, contains('lamin=30.0'));
      expect(requested!.query, contains('lomax=-110.0'));
    });

    test('a rate limit leaves the previous traffic alone and clears loading',
        () async {
      final s = WeatherService();
      await withHttp(
        () => s.fetchLiveFlights(),
        (_) async => http.Response('', 429),
      );
      expect(s.flightsLoading, isFalse);
      expect(s.error, contains('Rate limit'));
    });

    test('an offline traffic fetch fails silently, as designed', () async {
      final s = WeatherService();
      await withHttp(
        () => s.fetchLiveFlights(),
        (_) => Future.error(Exception('offline')),
      );
      expect(s.liveFlights, isEmpty);
      expect(s.flightsLoading, isFalse);
    });
  });

  group('advisory products', () {
    test('PIREPs are capped at ten and decoded', () async {
      final s = WeatherService();
      final out = await withHttp(
        () => s.fetchPireps(icao: 'KSFO'),
        (_) async => http.Response(
          jsonEncode([for (var i = 0; i < 25; i++) {'raw': 'PIREP $i'}]),
          200,
        ),
      );
      expect(out, hasLength(10));
      expect(out.first['raw'], equals('PIREP 0'));
    });

    test('a non-list PIREP payload yields an empty list, not a crash',
        () async {
      final s = WeatherService();
      final out = await withHttp(
        () => s.fetchPireps(),
        (_) async => http.Response(jsonEncode({'error': 'nope'}), 200),
      );
      expect(out, isEmpty);
    });

    test('SIGMETs and AIRMETs return empty when the service is down',
        () async {
      final s = WeatherService();
      await withHttp(() async {
        expect(await s.fetchSigmets(), isEmpty);
        expect(await s.fetchAirmets(), isEmpty);
      }, (_) async => http.Response('', 500));
    });

    test('winds aloft falls back to the raw FB text when JSON is unavailable',
        () async {
      final s = WeatherService();
      var call = 0;
      final out = await withHttp(() => s.fetchWindsAloft(region: 'bos'),
          (req) async {
        call++;
        // First attempt asks for JSON and gets nothing usable.
        if (req.url.query.contains('format=json')) {
          return http.Response(jsonEncode([]), 200);
        }
        return http.Response('FBUS31 KWNO 011500', 200);
      });

      expect(call, equals(2), reason: 'the raw fallback must be attempted');
      expect(out, hasLength(1));
      expect(out.single['raw'], equals('FBUS31 KWNO 011500'));
    });
  });
}
