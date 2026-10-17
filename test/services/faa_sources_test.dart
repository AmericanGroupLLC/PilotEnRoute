/// Airport details and charts come from official sources that exist.
///
/// Both used to call api.aviationapi.com, which has no DNS record at all, so
/// every lookup failed on every device. Field details now come from the
/// Aviation Weather Center airport endpoint and charts link out to the FAA's
/// d-TPP search. These tests drive both with a stubbed client — no network.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:pilot_enroute/screens/airport_screen.dart';
import 'package:pilot_enroute/screens/charts_screen.dart';
import 'package:pilot_enroute/services/chart_service.dart';
import 'package:pilot_enroute/services/settings_store.dart';
import 'package:pilot_enroute/services/weather_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<T> withHttp<T>(
  Future<T> Function() body,
  Future<http.Response> Function(http.Request) handler,
) =>
    http.runWithClient(body, () => MockClient(handler));

// Trimmed from a real response of
// https://aviationweather.gov/api/data/airport?ids=KLAX&format=json
const _klax = [
  {
    'icaoId': 'KLAX',
    'iataId': 'LAX',
    'faaId': 'LAX',
    'name': 'LOS ANGELES/LOS ANGELES INTL ',
    'state': 'CA',
    'country': 'US',
    'source': 'FAA',
    'elev': 39,
    'magdec': '12E',
    'tower': 'T',
    'freqs': 'LCL/P,119.8;D-ATIS,133.8;D-ATIS,135.65',
    'runways': [
      {'id': '06L/24R', 'dimension': '8926x150', 'surface': 'A'},
      {'id': '06R/24L', 'dimension': '10885x150', 'surface': 'C'},
    ],
  },
];

// Trimmed from the real KHAF response: no tower, freqs "-".
const _khaf = [
  {
    'icaoId': 'KHAF',
    'name': 'HALF MOON BAY/HALF MOON BAY ',
    'state': 'CA',
    'country': 'US',
    'source': 'FAA',
    'elev': 20,
    'magdec': '15E',
    'tower': null,
    'freqs': '-',
    'runways': [
      {'id': '12/30', 'dimension': '5000x150'},
    ],
  },
];

void main() {
  group('d-TPP cycle', () {
    test('2026-10-12 is in cycle 2610 (effective 2026-10-01)', () {
      expect(dtppCycleFor(DateTime.utc(2026, 10, 12)), '2610');
    });

    test('the cycle turns over on its effective date', () {
      expect(dtppCycleFor(DateTime.utc(2026, 9, 30)), '2609');
      expect(dtppCycleFor(DateTime.utc(2026, 10, 1)), '2610');
      expect(dtppCycleFor(DateTime.utc(2026, 10, 29)), '2611');
    });

    test('numbering restarts with the first cycle of a year', () {
      expect(dtppCycleFor(DateTime.utc(2026, 1, 21)), '2513');
      expect(dtppCycleFor(DateTime.utc(2026, 1, 22)), '2601');
    });

    test('dates before the anchor still land on a real cycle', () {
      expect(dtppCycleFor(DateTime.utc(2025, 1, 23)), '2501');
      expect(dtppCycleFor(DateTime.utc(2025, 12, 25)), '2513');
    });

    test('a local-time argument is interpreted in UTC', () {
      final local = DateTime.utc(2026, 10, 1, 12).toLocal();
      expect(dtppCycleFor(local), '2610');
    });

    test('the search link is the FAA d-TPP results page', () {
      expect(
        dtppSearchUri(' klax ', now: DateTime.utc(2026, 10, 12)).toString(),
        'https://www.faa.gov/air_traffic/flight_info/aeronav/digital_products/'
        'dtpp/search/results/?cycle=2610&ident=KLAX',
      );
    });
  });

  group('ChartService.linkFor', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('an empty identifier is refused with a message', () {
      final s = ChartService();
      expect(s.linkFor('  '), isNull);
      expect(s.error, isNotNull);
    });

    test('something that is not an airport identifier is refused', () {
      final s = ChartService();
      expect(s.linkFor('KLAX!'), isNull);
      expect(s.linkFor('LOSANGELES'), isNull);
      expect(s.error, contains('not an airport identifier'));
    });

    test('a valid identifier yields the link and is remembered', () {
      final s = ChartService();
      final uri = s.linkFor('klax', now: DateTime.utc(2026, 10, 12));
      expect(uri, isNotNull);
      expect(uri!.host, 'www.faa.gov');
      expect(uri.queryParameters, {'cycle': '2610', 'ident': 'KLAX'});
      expect(s.error, isNull);
      expect(s.recent, ['KLAX']);
    });
  });

  group('WeatherService.fetchAirportDetail', () {
    test('asks the AWC airport endpoint and decodes a towered field', () async {
      late Uri asked;
      final a = await withHttp(
        () => WeatherService().fetchAirportDetail('klax'),
        (req) async {
          asked = req.url;
          return http.Response(jsonEncode(_klax), 200,
              headers: {'content-type': 'application/json'});
        },
      );

      expect(asked.host, 'aviationweather.gov');
      expect(asked.path, '/api/data/airport');
      expect(asked.queryParameters, {'ids': 'KLAX', 'format': 'json'});

      expect(a, isNotNull);
      expect(a!.icao, 'KLAX');
      expect(a.name, 'LOS ANGELES/LOS ANGELES INTL');
      expect(a.isUs, isTrue);
      expect(a.source, 'FAA');
      expect(a.towered, isTrue);
      // AWC publishes elevation in metres; KLAX is 128 ft.
      expect(a.elevationM, 39);
      expect(a.elevationFt, 128);
      expect(a.magneticVariation, '12E');
      expect(a.frequencies,
          ['LCL/P 119.8', 'D-ATIS 133.8', 'D-ATIS 135.65']);
      expect(a.runways, ['06L/24R 8926x150 ft', '06R/24L 10885x150 ft']);
    });

    test('an untowered field with no frequencies says so, not zeros', () async {
      final a = await withHttp(
        () => WeatherService().fetchAirportDetail('KHAF'),
        (_) async => http.Response(jsonEncode(_khaf), 200),
      );
      expect(a!.towered, isFalse);
      expect(a.frequencies, isEmpty);
      expect(a.runways, ['12/30 5000x150 ft']);
    });

    test('204 (unknown airport or an IATA code) is "no record"', () async {
      final a = await withHttp(
        () => WeatherService().fetchAirportDetail('LAX'),
        (_) async => http.Response('', 204),
      );
      expect(a, isNull);
    });

    test('an empty list is "no record"', () async {
      final a = await withHttp(
        () => WeatherService().fetchAirportDetail('ZZZZ'),
        (_) async => http.Response('[]', 200),
      );
      expect(a, isNull);
    });

    test('a gateway 504 is retried once', () async {
      var calls = 0;
      final a = await withHttp(
        () => WeatherService().fetchAirportDetail('KLAX'),
        (_) async {
          calls++;
          return calls == 1
              ? http.Response('<html>504 Gateway Time-out</html>', 504)
              : http.Response(jsonEncode(_klax), 200);
        },
      );
      expect(calls, 2);
      expect(a!.icao, 'KLAX');
    });

    test('a persistent failure throws instead of returning empty', () async {
      var calls = 0;
      await expectLater(
        withHttp(
          () => WeatherService().fetchAirportDetail('KLAX'),
          (_) async {
            calls++;
            return http.Response('<html>504</html>', 504);
          },
        ),
        throwsA(isA<http.ClientException>()),
      );
      expect(calls, 2);
    });

    test('a network error throws', () async {
      await expectLater(
        withHttp(
          () => WeatherService().fetchAirportDetail('KLAX'),
          (req) async => throw http.ClientException('no route', req.url),
        ),
        throwsA(isA<http.ClientException>()),
      );
    });
  });

  testWidgets('ChartsScreen names the real source and refuses bad input',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: ChartsScreen()));
    await tester.pump();

    expect(find.textContaining('FAA d-TPP'), findsWidgets);
    expect(find.textContaining('aviationapi'), findsNothing);

    await tester.enterText(find.byType(TextField), 'K!');
    await tester.tap(find.text('OPEN'));
    await tester.pump();
    expect(find.textContaining('not an airport identifier'), findsOneWidget);
  });

  group('AirportScreen FAA section', () {
    Future<void> lookUpKlax(WidgetTester tester, int awcStatus) async {
      // Tall enough that the lazily built list lays out every section.
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      await http.runWithClient(() async {
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => SettingsStore()),
            ChangeNotifierProvider(create: (_) => WeatherService()),
          ],
          child: const MaterialApp(home: AirportScreen()),
        ));
        await tester.enterText(find.byKey(const Key('airport-ident')), 'klax');
        await tester.tap(find.byKey(const Key('airport-lookup')));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      }, () => MockClient((req) async {
            // The screen talks to aviationweather.gov only.
            expect(req.url.host, 'aviationweather.gov');
            if (req.url.path == '/api/data/airport') {
              return awcStatus == 200
                  ? http.Response(jsonEncode(_klax), 200)
                  : http.Response('<html>gateway</html>', awcStatus);
            }
            return http.Response('', 204);
          }));
    }

    testWidgets('shows AWC field details and the FAA charts link',
        (tester) async {
      await lookUpKlax(tester, 200);
      expect(find.text('Field details'), findsOneWidget);
      expect(find.text('LOS ANGELES/LOS ANGELES INTL'), findsOneWidget);
      expect(find.text('128 ft (39 m) MSL'), findsOneWidget);
      expect(find.text('Source: FAA data via aviationweather.gov'),
          findsOneWidget);
      expect(find.text('Charts & plates'), findsOneWidget);
      expect(find.text('Open FAA terminal procedures'), findsOneWidget);
    });

    testWidgets('a failed AWC request says so and still offers the charts',
        (tester) async {
      await lookUpKlax(tester, 503);
      expect(find.textContaining('Could not load field details'),
          findsOneWidget);
      expect(find.text('Open FAA terminal procedures'), findsOneWidget);
    });
  });

  test('no code in lib/ requests the dead aviationapi.com host', () {
    final url = RegExp(r'https?://[A-Za-z0-9.-]*aviationapi\.com');
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (url.hasMatch(f.readAsStringSync())) hits.add(f.path);
    }
    expect(hits, isEmpty);
  });
}
