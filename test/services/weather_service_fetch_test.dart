/// Weather fetching and decoding, straight from aviationweather.gov.
///
/// These drive the service's real network paths with a stubbed client, so a
/// change to the decoding or the error handling actually fails something.
/// (The live-traffic tests that used to be here went with the flight tracker,
/// which is AeroSwift's job.)
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pilot_enroute/services/weather_service.dart';

import '../support/awc_fixtures.dart';

Future<T> withHttp<T>(
  Future<T> Function() body,
  Future<http.Response> Function(http.Request) handler,
) =>
    http.runWithClient(body, () => MockClient(handler));

void main() {
  group('METAR decoding', () {
    test('a full AWC payload maps onto every field', () {
      final m = MetarObservation.fromJson(first('metar_KDLH'));
      expect(m.icao, equals('KDLH'));
      expect(m.ceilingFt, equals(1300));
      expect(m.wind!.gustKt, equals(18));
      expect(m.altimeterHpa, closeTo(1020.7, 1e-9));
      expect(m.visibility!.miles, equals(10.0));
      expect(m.name, 'Duluth Intl Arpt, MN, US');
    });

    test('visibility survives the "10+" form the feed emits', () {
      expect(MetarObservation.fromJson({'visib': '10+'}).visibility!.miles,
          equals(10.0));
      expect(MetarObservation.fromJson({'visib': 6}).visibility!.miles,
          equals(6.0));
      expect(MetarObservation.fromJson({'visib': 2.5}).visibility!.miles,
          equals(2.5));
    });

    test('an absent visibility is null rather than zero', () {
      // Zero visibility is a real, alarming value; it must not mean "unknown".
      expect(MetarObservation.fromJson(const {}).visibility, isNull);
    });

    test('a payload with nothing in it still decodes to a usable object', () {
      final m = MetarObservation.fromJson(const {});
      expect(m.icao, isEmpty);
      expect(m.raw, isEmpty);
      expect(m.flightCategory, isEmpty);
      expect(m.ceilingFt, isNull);
    });
  });

  group('fetchMetar', () {
    test('a good response is decoded; the station is upper-cased', () async {
      Uri? requested;
      final (status, m) = await withHttp(() => WeatherService().fetchMetar('kdlh'),
          (req) async {
        requested = req.url;
        return http.Response(jsonEncode(fixture('metar_KDLH')), 200);
      });
      expect(status, FetchStatus.ok);
      expect(m!.icao, 'KDLH');
      expect(requested!.host, 'aviationweather.gov');
      expect(requested!.path, '/api/data/metar');
      expect(requested!.queryParameters, {'ids': 'KDLH', 'format': 'json'});
    });

    test('204 (no such station) is "no data", not an error', () async {
      final (status, m) = await withHttp(() => WeatherService().fetchMetar('KZZZ'),
          (_) async => http.Response('', 204));
      expect(status, FetchStatus.noData);
      expect(m, isNull);
    });

    test('an empty list is "no data"', () async {
      final (status, _) = await withHttp(() => WeatherService().fetchMetar('KZZZ'),
          (_) async => http.Response('[]', 200));
      expect(status, FetchStatus.noData);
    });

    test('an offline fetch reports offline instead of throwing', () async {
      final (status, m) = await withHttp(() => WeatherService().fetchMetar('KSFO'),
          (_) => Future.error(Exception('offline')));
      expect(status, FetchStatus.offline);
      expect(m, isNull);
    });

    test('a malformed body is a failure, not a half-built report', () async {
      final (status, m) = await withHttp(() => WeatherService().fetchMetar('KSFO'),
          (_) async => http.Response('<html>down</html>', 200));
      expect(status, FetchStatus.failed);
      expect(m, isNull);
    });

    test('a gateway 504 is retried once', () async {
      var calls = 0;
      final (status, m) = await withHttp(() => WeatherService().fetchMetar('KDLH'),
          (_) async {
        calls++;
        return calls == 1
            ? http.Response('<html>504 Gateway Time-out</html>', 504)
            : http.Response(jsonEncode(fixture('metar_KDLH')), 200);
      });
      expect(calls, 2);
      expect(status, FetchStatus.ok);
      expect(m!.icao, 'KDLH');
    });

    test('a persistent 5xx is a failure', () async {
      final (status, _) = await withHttp(() => WeatherService().fetchMetar('KDLH'),
          (_) async => http.Response('', 503));
      expect(status, FetchStatus.failed);
    });
  });

  group('fetchTaf and fetchSnapshot', () {
    test('a TAF is decoded with its groups', () async {
      final (status, t) = await http.runWithClient(
          () => WeatherService().fetchTaf('KSJC'), awcClient);
      expect(status, FetchStatus.ok);
      expect(t!.groups, hasLength(4));
    });

    test('KPAO issues no TAF: "no data"', () async {
      final (status, t) = await http.runWithClient(
          () => WeatherService().fetchTaf('KPAO'), awcClient);
      expect(status, FetchStatus.noData);
      expect(t, isNull);
    });

    test('the snapshot carries METAR, TAF and runways together', () async {
      final s = await http.runWithClient(
          () => WeatherService().fetchSnapshot('kack',
              clock: () => DateTime.utc(2026, 10, 14, 13, 5)),
          awcClient);
      expect(s.station, 'KACK');
      expect(s.metarStatus, FetchStatus.ok);
      expect(s.tafStatus, FetchStatus.ok);
      expect(s.airportStatus, FetchStatus.ok);
      expect(s.airport!.runwayInfo, hasLength(2));
      expect(s.fetchedAt, DateTime.utc(2026, 10, 14, 13, 5));
    });

    test('one failing product does not hide the others', () async {
      final s = await http.runWithClient(
          () => WeatherService().fetchSnapshot('KACK'),
          () => awcClient(status: {'taf:KACK': 500}));
      expect(s.metar, isNotNull);
      expect(s.tafStatus, FetchStatus.failed);
      expect(s.airport, isNotNull);
    });

    test('offline: every product says offline', () async {
      final s = await http.runWithClient(
          () => WeatherService().fetchSnapshot('KACK'),
          () => awcClient(offline: {'metar', 'taf', 'airport'}));
      expect(s.metarStatus, FetchStatus.offline);
      expect(s.tafStatus, FetchStatus.offline);
      expect(s.airportStatus, FetchStatus.offline);
      expect(s.metarProblem, contains('offline'));
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
