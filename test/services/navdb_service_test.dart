/// Navaid database: CSV parsing, search and the favourites/waypoint store.
///
/// The navaid feed is a multi-megabyte third-party CSV, so the parser has to
/// survive quoted commas, embedded quotes and junk rows without losing the
/// whole dataset — and the search has to stay bounded.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pilot_enroute/services/navdb_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _header =
    'id,filename,ident,name,type,frequency_khz,latitude_deg,longitude_deg,'
    'elevation_ft,iso_country';

String _row(
  String ident,
  String name,
  String type,
  String khz,
  String lat,
  String lon, {
  String elev = '100',
  String country = 'US',
}) =>
    '1,file,$ident,$name,$type,$khz,$lat,$lon,$elev,$country';

/// Runs [body] with every `http.get` answered by [handler].
Future<T> withHttp<T>(
  Future<T> Function() body,
  Future<http.Response> Function(http.Request) handler,
) =>
    http.runWithClient(body, () => MockClient(handler));

Future<http.Response> csvOk(String body) async => http.Response(body, 200);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('CSV row parsing', () {
    final cols = {
      'ident': 2,
      'name': 3,
      'type': 4,
      'frequency_khz': 5,
      'latitude_deg': 6,
      'longitude_deg': 7,
      'elevation_ft': 8,
      'iso_country': 9,
    };

    List<String> fields(String line) => line.split(',');

    test('frequency is converted from kHz to MHz', () {
      // 116 800 kHz displayed as 116 800 instead of 116.80 would be unusable.
      final n = Navaid.fromCsvRow(
        fields(_row('SFO', 'San Francisco', 'VOR-DME', '115800', '37.6', '-122.3')),
        cols,
      );
      expect(n!.frequencyMhz, closeTo(115.8, 1e-9));
    });

    test('a row with no ident is dropped', () {
      expect(
        Navaid.fromCsvRow(fields(_row('', 'Nameless', 'VOR', '110000', '1', '2')),
            cols),
        isNull,
      );
    });

    test('a row with unparseable coordinates is dropped', () {
      expect(
        Navaid.fromCsvRow(
            fields(_row('BAD', 'Bad', 'VOR', '110000', 'north', 'west')), cols),
        isNull,
      );
    });

    test('a missing frequency or elevation is null, not zero', () {
      // Zero would render as "0.00 MHz", which reads like a real frequency.
      final n = Navaid.fromCsvRow(
        fields(_row('NDB1', 'Beacon', 'NDB', '', '10', '20', elev: '')),
        cols,
      );
      expect(n!.frequencyMhz, isNull);
      expect(n.elevationFt, isNull);
    });

    test('a row with fewer columns than the header does not throw', () {
      expect(Navaid.fromCsvRow(['1', 'file', 'ABC'], cols), isNull);
    });

    test('a nameless navaid falls back to its ident', () {
      final n = Navaid.fromCsvRow(
          fields(_row('OAK', '', 'VOR', '116800', '37.7', '-122.2')), cols);
      expect(n!.name, equals('OAK'));
      expect(n.type, equals('VOR'));
    });
  });

  group('loading the feed', () {
    test('a well-formed feed loads every usable row', () async {
      final csv = [
        _header,
        _row('SFO', 'San Francisco', 'VOR-DME', '115800', '37.6', '-122.3'),
        _row('OAK', 'Oakland', 'VOR-DME', '116800', '37.7', '-122.2'),
        _row('SAU', 'Sausalito', 'VOR', '116200', '37.8', '-122.5'),
      ].join('\n');

      final s = NavDbService();
      await withHttp(() => s.ensureLoaded(), (_) => csvOk(csv));

      expect(s.isLoaded, isTrue);
      expect(s.error, isNull);
      expect(s.navaidCount, equals(3));
      expect(s.isLoading, isFalse);
    });

    test('a quoted field containing a comma stays one field', () async {
      // Without this the name splits and every later column shifts left,
      // putting longitude into the elevation slot.
      final csv = [
        _header,
        '1,file,PYE,"Point Reyes, CA",VOR-DME,113200,38.07,-122.86,400,US',
      ].join('\n');

      final s = NavDbService();
      await withHttp(() => s.ensureLoaded(), (_) => csvOk(csv));

      final n = s.navaids.single;
      expect(n.name, equals('Point Reyes, CA'));
      expect(n.lat, closeTo(38.07, 1e-9));
      expect(n.lon, closeTo(-122.86, 1e-9));
      expect(n.elevationFt, equals(400));
    });

    test('an escaped double quote inside a field is unescaped', () async {
      final csv = [
        _header,
        '1,file,ABC,"The ""Big"" One",VOR,110000,10,20,50,US',
      ].join('\n');

      final s = NavDbService();
      await withHttp(() => s.ensureLoaded(), (_) => csvOk(csv));
      expect(s.navaids.single.name, equals('The "Big" One'));
    });

    test('blank lines and CRLF endings do not create phantom navaids',
        () async {
      final csv = '$_header\r\n'
          '${_row('SFO', 'San Francisco', 'VOR', '115800', '37.6', '-122.3')}\r\n'
          '\r\n'
          '${_row('OAK', 'Oakland', 'VOR', '116800', '37.7', '-122.2')}\r\n';

      final s = NavDbService();
      await withHttp(() => s.ensureLoaded(), (_) => csvOk(csv));
      expect(s.navaidCount, equals(2));
    });

    test('one bad row does not abort the parse', () async {
      final csv = [
        _header,
        _row('SFO', 'San Francisco', 'VOR', '115800', '37.6', '-122.3'),
        'garbage',
        _row('OAK', 'Oakland', 'VOR', '116800', '37.7', '-122.2'),
      ].join('\n');

      final s = NavDbService();
      await withHttp(() => s.ensureLoaded(), (_) => csvOk(csv));
      expect(s.navaidCount, equals(2));
    });

    test('an empty body loads to an empty list rather than an error', () async {
      final s = NavDbService();
      await withHttp(() => s.ensureLoaded(), (_) => csvOk(''));
      expect(s.navaids, isEmpty);
      expect(s.isLoaded, isTrue);
    });

    test('a server error surfaces a retryable message, not a crash', () async {
      final s = NavDbService();
      await withHttp(
        () => s.ensureLoaded(),
        (_) async => http.Response('nope', 503),
      );

      expect(s.isLoaded, isFalse);
      expect(s.isLoading, isFalse);
      expect(s.error, isNotNull);
      expect(s.error, contains('retry'));
      expect(s.navaids, isEmpty);
    });

    test('a transport failure surfaces the same honest message', () async {
      final s = NavDbService();
      await withHttp(
        () => s.ensureLoaded(),
        (_) => Future.error(const SocketExceptionStub()),
      );
      expect(s.error, isNotNull);
      expect(s.isLoaded, isFalse);
    });

    test('a second call does not refetch, but reload does', () async {
      var requests = 0;
      final csv = [
        _header,
        _row('SFO', 'San Francisco', 'VOR', '115800', '37.6', '-122.3'),
      ].join('\n');

      final s = NavDbService();
      await withHttp(() async {
        await s.ensureLoaded();
        await s.ensureLoaded();
        expect(requests, equals(1),
            reason: 'the feed is multi-megabyte; once per session');
        await s.reload();
        expect(requests, equals(2));
      }, (_) async {
        requests++;
        return http.Response(csv, 200);
      });
    });
  });

  group('search', () {
    Future<NavDbService> loaded() async {
      final csv = [
        _header,
        _row('SFO', 'San Francisco', 'VOR-DME', '115800', '37.6', '-122.3'),
        _row('OAK', 'Oakland', 'VOR-DME', '116800', '37.7', '-122.2'),
        _row('SAU', 'Sausalito', 'VORTAC', '116200', '37.8', '-122.5'),
        _row('FMG', 'Mustang', 'NDB', '365', '39.5', '-119.6'),
        _row('CZQ', 'Clovis', 'TACAN', '112900', '36.8', '-119.8'),
      ].join('\n');
      final s = NavDbService();
      await withHttp(() => s.ensureLoaded(), (_) => csvOk(csv));
      return s;
    }

    test('an empty query returns everything', () async {
      final s = await loaded();
      expect(s.search(''), hasLength(5));
    });

    test('search matches ident and name, case-insensitively', () async {
      final s = await loaded();
      expect(s.search('sfo').single.ident, equals('SFO'));
      expect(s.search('oakland').single.ident, equals('OAK'));
      expect(s.search('MUSTANG').single.ident, equals('FMG'));
    });

    test('a type filter matches by substring so VORTAC counts as a VOR',
        () async {
      final s = await loaded();
      expect(s.search('', typeFilter: 'VOR').map((n) => n.ident),
          containsAll(['SFO', 'OAK', 'SAU']));
      expect(s.search('', typeFilter: 'NDB').single.ident, equals('FMG'));
      expect(s.search('', typeFilter: 'TACAN').single.ident, equals('CZQ'));
    });

    test('the All filter disables filtering', () async {
      final s = await loaded();
      expect(s.search('', typeFilter: 'All'), hasLength(5));
      expect(NavDbService.typeFilters.first, equals('All'));
    });

    test('a query with no match returns empty rather than everything',
        () async {
      final s = await loaded();
      expect(s.search('zzzz'), isEmpty);
    });

    test('results are capped so a full dataset cannot lock the UI', () async {
      final rows = <String>[_header];
      for (var i = 0; i < kMaxSearchResults + 50; i++) {
        rows.add(_row('V$i', 'Navaid $i', 'VOR', '110000', '10', '20'));
      }
      final s = NavDbService();
      await withHttp(() => s.ensureLoaded(), (_) => csvOk(rows.join('\n')));

      expect(s.navaidCount, equals(kMaxSearchResults + 50));
      expect(s.search(''), hasLength(kMaxSearchResults));
    });

    test('byIdents resolves favourites regardless of case', () async {
      final s = await loaded();
      expect(s.byIdents(['sfo', 'OAK']).map((n) => n.ident),
          containsAll(['SFO', 'OAK']));
      expect(s.byIdents(const []), isEmpty);
    });
  });

  group('favourites and user waypoints', () {
    test('a favourite survives a restart and is case-insensitive', () async {
      final a = NavDbService();
      await a.toggleFavorite('sfo');
      expect(a.isFavorite('SFO'), isTrue);

      final b = NavDbService();
      await b.loadPrefs();
      expect(b.isFavorite('sfo'), isTrue);
      expect(b.favorites, equals(['SFO']));
    });

    test('toggling twice removes the favourite', () async {
      final s = NavDbService();
      await s.toggleFavorite('SFO');
      await s.toggleFavorite('SFO');
      expect(s.favorites, isEmpty);

      final next = NavDbService();
      await next.loadPrefs();
      expect(next.favorites, isEmpty);
    });

    test('a user waypoint survives a restart with its coordinates', () async {
      final a = NavDbService();
      await a.addUserWaypoint('  Home Field  ', 37.4611, -122.1150);

      final b = NavDbService();
      await b.loadPrefs();

      expect(b.userWaypoints, hasLength(1));
      expect(b.userWaypoints.single.name, equals('Home Field'));
      expect(b.userWaypoints.single.lat, closeTo(37.4611, 1e-9));
      expect(b.userWaypoints.single.lon, closeTo(-122.1150, 1e-9));
    });

    test('a removed waypoint stays removed', () async {
      final a = NavDbService();
      await a.addUserWaypoint('Home', 1, 2);
      await a.removeUserWaypoint(a.userWaypoints.single.id);

      final b = NavDbService();
      await b.loadPrefs();
      expect(b.userWaypoints, isEmpty);
    });

    test('a corrupt stored waypoint is skipped, the good ones still load',
        () async {
      SharedPreferences.setMockInitialValues({
        'navdb_user_waypoints': [
          'not json',
          jsonEncode({'id': '1', 'name': 'Good', 'lat': 1.0, 'lon': 2.0}),
          jsonEncode({'id': '2', 'name': 'No coords'}),
        ],
      });
      final s = NavDbService();
      await s.loadPrefs();

      expect(s.userWaypoints, hasLength(1));
      expect(s.userWaypoints.single.name, equals('Good'));
    });

    test('a waypoint round-trips through JSON', () {
      const wp = UserWaypoint(id: '7', name: 'Strip', lat: 12.5, lon: -3.25);
      final restored = UserWaypoint.fromJson(wp.toJson())!;
      expect(restored.id, equals('7'));
      expect(restored.name, equals('Strip'));
      expect(restored.lat, equals(12.5));
      expect(restored.lon, equals(-3.25));
    });
  });
}

/// A stand-in for a real socket failure — the service only cares that the
/// future errors.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
  @override
  String toString() => 'SocketException: offline';
}
