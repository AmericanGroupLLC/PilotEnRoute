/// Real users only ever see real data.
///
/// Each service below used to substitute invented content when its real
/// source was missing or failed: demo aircraft on the map, a "Valid
/// Registration" for any tail, six fake NOTAMs per airport, sample logbook
/// flights, synthetic GPS tracks, a fake notification feed. These tests pin
/// the honest empty/error states so none of that can come back silently.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pilot_enroute/screens/career_screen.dart';
import 'package:pilot_enroute/screens/notam_screen.dart';
import 'package:pilot_enroute/services/flight_debrief_service.dart';
import 'package:pilot_enroute/services/flight_tracker_service.dart';
import 'package:pilot_enroute/services/logbook_service.dart';
import 'package:pilot_enroute/services/notam_service.dart';
import 'package:pilot_enroute/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Runs [body] with every `http` call answered by [handler].
Future<T> withHttp<T>(
  Future<T> Function() body,
  Future<http.Response> Function(http.Request) handler,
) =>
    http.runWithClient(body, () => MockClient(handler));

const _inventedCallsigns = ['UAL123', 'DAL456', 'N12345'];
const _inventedIcao24 = ['a12345', 'b67890', 'c11111'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('live traffic', () {
    test('a non-200 from OpenSky shows no aircraft and an honest error',
        () async {
      final s = FlightTrackerService();
      await withHttp(
        () => s.fetchNearbyFlights(),
        (_) async => http.Response('Too Many Requests', 429),
      );
      expect(s.nearbyFlights, isEmpty);
      expect(s.error, FlightTrackerService.liveTrafficUnavailableMessage);
      expect(s.error, isNot(contains('demo')));
    });

    test('a network failure shows no aircraft', () async {
      final s = FlightTrackerService();
      await withHttp(
        () => s.fetchNearbyFlights(),
        (_) async => throw http.ClientException('offline'),
      );
      expect(s.nearbyFlights, isEmpty);
      expect(s.error, FlightTrackerService.liveTrafficUnavailableMessage);
      for (final c in _inventedCallsigns) {
        expect(s.nearbyFlights.map((a) => a.callsign), isNot(contains(c)));
      }
      for (final id in _inventedIcao24) {
        expect(s.nearbyFlights.map((a) => a.icao24), isNot(contains(id)));
      }
    });

    test('a real OpenSky answer is shown as-is', () async {
      final s = FlightTrackerService();
      await withHttp(
        () => s.fetchNearbyFlights(),
        (_) async => http.Response(
          jsonEncode({
            'time': 1,
            'states': [
              ['a8b7fe', 'N661AP  ', 'United States', 1, 1, -122.19, 37.72,
                91.44, false, 41.18, 290.47, -1.63, null, 30.48, '7773'],
            ],
          }),
          200,
        ),
      );
      expect(s.error, isNull);
      expect(s.nearbyFlights.single.callsign, 'N661AP');
    });
  });

  group('tail number lookup', () {
    test('a found aircraft shows only what adsbdb returned', () async {
      final s = FlightTrackerService();
      late Uri asked;
      await withHttp(
        () => s.lookupTailNumber('n21108'),
        (req) async {
          asked = req.url;
          return http.Response(
            jsonEncode({
              'response': {
                'aircraft': {
                  'type': '757 224/W',
                  'icao_type': 'B752',
                  'manufacturer': 'Boeing',
                  'mode_s': 'A1BFB2',
                  'registration': 'N21108',
                  'registered_owner': 'United Airlines',
                },
              },
            }),
            200,
          );
        },
      );
      expect(asked.toString(), 'https://api.adsbdb.com/v0/aircraft/N21108');
      final info = s.tailNumberInfo!;
      expect(info.tailNumber, 'N21108');
      expect(info.manufacturer, 'Boeing');
      expect(info.model, '757 224/W');
      expect(info.owner, 'United Airlines');
      // Nothing the database did not say: no status, date, engine, seats.
      expect(info.status, isNull);
      expect(info.registrationDate, isNull);
      expect(info.engineType, isNull);
      expect(info.seats, isNull);
      expect(info.weight, isNull);
    });

    test('an unknown tail is not reported as valid', () async {
      final s = FlightTrackerService();
      await withHttp(
        () => s.lookupTailNumber('N1ZZZ'),
        (_) async =>
            http.Response(jsonEncode({'response': 'unknown aircraft'}), 404),
      );
      expect(s.tailNumberInfo, isNull);
      expect(s.tailError, contains('No record for N1ZZZ'));
      expect(s.tailError, contains('does not confirm or deny'));
    });

    test('offline shows an error and no invented record', () async {
      final s = FlightTrackerService();
      await withHttp(
        () => s.lookupTailNumber('N12345'),
        (_) async => throw http.ClientException('offline'),
      );
      expect(s.tailNumberInfo, isNull);
      expect(s.tailError, contains("Couldn't reach the aircraft database"));
      expect(s.tailError, isNot(contains('Cessna')));
    });

    test('the FAA Registry link points at the entered tail', () {
      expect(
        FlightTrackerService.faaRegistryUri('N21108').toString(),
        'https://registry.faa.gov/aircraftinquiry/Search/NNumberResult'
        '?nNumberTxt=21108',
      );
    });
  });

  group('NOTAMs', () {
    test('without FAA credentials there are no NOTAMs and an explicit error',
        () async {
      final s = NotamService();
      await withHttp(
        () => s.fetchByAirport('KPAO'),
        (_) async => fail('no request should be made without credentials'),
      );
      expect(s.hasCredentials, isFalse);
      expect(s.notams, isEmpty);
      // An error, never an empty list that reads as "no NOTAMs".
      expect(s.error, NotamService.noCredentialsMessage);
      expect(s.error, contains('notams.aim.faa.gov'));
    });

    test('a route search also invents nothing', () async {
      final s = NotamService();
      await s.fetchByRoute(['KPAO', 'KMRY']);
      expect(s.notams, isEmpty);
      expect(s.error, isNotNull);
    });
  });

  group('NOTAM screen', () {
    testWidgets('shows "unavailable", not sample notices or an all-clear',
        (tester) async {
      SharedPreferences.setMockInitialValues({'notam_last_icao': 'KPAO'});
      await tester.pumpWidget(const MaterialApp(home: NotamScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('NOTAMs unavailable'), findsOneWidget);
      expect(find.text(NotamService.noCredentialsMessage), findsOneWidget);
      expect(find.text('No NOTAMs'), findsNothing);
      expect(find.textContaining('Sample data'), findsNothing);
      expect(find.textContaining('RWY 04L/22R'), findsNothing);
      expect(find.textContaining('KPAO 07/'), findsNothing);
    });
  });

  group('logbook', () {
    test('with no database the logbook is empty, not sample flights',
        () async {
      final s = LogbookService();
      await s.loadEntries();
      expect(s.entries, isEmpty);
      expect(s.totals.totalTime, 0);
      expect(s.totals.totalFlights, 0);
    });
  });

  group('flight debrief', () {
    test('no recorded flights means no tracks at all', () async {
      final s = FlightDebriefService();
      await s.load();
      expect(s.tracks, isEmpty);
      expect(s.trackById('sample_pattern_kpao'), isNull);
      expect(s.trackById('sample_bay_tour'), isNull);
    });
  });

  group('notification feed', () {
    test('loads empty instead of an invented SAFO/NOTAM/medical feed',
        () async {
      final s = NotificationService();
      await s.loadNotifications();
      expect(s.notifications, isEmpty);
      expect(s.unreadCount, 0);
    });
  });

  group('career pay (BLS)', () {
    test('parses the live BLS medians with their year', () async {
      final rows = await withHttp(
        fetchBlsMedianPay,
        (req) async {
          expect(req.url.host, 'api.bls.gov');
          return http.Response(
            jsonEncode({
              'status': 'REQUEST_SUCCEEDED',
              'Results': {
                'series': [
                  {
                    'seriesID': 'OEUN000000000000053201113',
                    'data': [
                      {'year': '2025', 'value': '232140'},
                    ],
                  },
                  {
                    'seriesID': 'OEUN000000000000053202113',
                    'data': [
                      {'year': '2025', 'value': '148080'},
                    ],
                  },
                ],
              },
            }),
            200,
          );
        },
      );
      expect(rows, hasLength(2));
      expect(rows.first.annualUsd, 232140);
      expect(rows.first.year, '2025');
      expect(rows.last.occupation, 'Air traffic controllers');
    });

    test('a BLS failure throws instead of returning a number', () async {
      await expectLater(
        withHttp(
          fetchBlsMedianPay,
          (_) async => http.Response('nope', 503),
        ),
        throwsA(isA<http.ClientException>()),
      );
    });
  });
}
