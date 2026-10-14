/// Recorded real aviationweather.gov answers (test/fixtures/awc/). Each file
/// carries the UTC capture time and the exact request in its header fields;
/// `response` is the body exactly as AWC returned it.
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> fixtureDoc(String name) =>
    jsonDecode(File('test/fixtures/awc/$name.json').readAsStringSync())
        as Map<String, dynamic>;

/// The decoded AWC body.
dynamic fixture(String name) => fixtureDoc(name)['response'];

/// The first object of a list body.
Map<String, dynamic> first(String name) =>
    (fixture(name) as List).first as Map<String, dynamic>;

DateTime capturedAt(String name) =>
    DateTime.parse(fixtureDoc(name)['_captured_utc'] as String);

/// A fake HTTP client that answers AWC metar/taf/airport requests from the
/// fixtures for [stations]; anything else is 204, like AWC.
MockClient awcClient({Set<String>? offline, Map<String, int>? status}) {
  return MockClient((req) async {
    if (req.url.host != 'aviationweather.gov') return http.Response('', 404);
    final product = req.url.pathSegments.last;
    final id = (req.url.queryParameters['ids'] ?? '').toUpperCase();
    if (offline?.contains(product) ?? false) {
      throw http.ClientException('offline', req.url);
    }
    final forced = status?['$product:$id'];
    if (forced != null) return http.Response('', forced);
    final f = File('test/fixtures/awc/${product}_$id.json');
    if (!f.existsSync()) return http.Response('', 204);
    final body = fixture('${product}_$id');
    return http.Response(jsonEncode(body), 200,
        headers: {'content-type': 'application/json'});
  });
}
