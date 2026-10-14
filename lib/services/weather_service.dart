import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:http/http.dart' as http;

import '../core/minimums/go_check.dart';
import '../core/weather/awc_models.dart';

export '../core/minimums/go_check.dart' show FetchStatus, WeatherSnapshot;
export '../core/weather/awc_models.dart';

/// Aviation Weather Center data API — free, keyless, run by NOAA.
/// https://aviationweather.gov/data/api/
///
/// Every METAR, TAF and airport the app shows comes straight from here. (It
/// used to go through a third-party METAR proxy; that is gone.)
const String awcBase = 'https://aviationweather.gov/api/data';

/// One AWC answer: how it ended and, if it worked, the decoded JSON.
class AwcAnswer {
  final FetchStatus status;
  final Object? json;
  final int? httpStatus;
  const AwcAnswer(this.status, {this.json, this.httpStatus});
}

/// The colour a flight category keeps everywhere: VFR green, MVFR blue, IFR
/// red, LIFR magenta. It is never shown on its own — the category text and
/// an icon always go with it.
Color flightCategoryColor(String category) {
  switch (category.toUpperCase()) {
    case 'VFR':
      return const Color(0xFF2B8A3E);
    case 'MVFR':
      return const Color(0xFF1C64C8);
    case 'IFR':
      return const Color(0xFFC1121F);
    case 'LIFR':
      return const Color(0xFFB0158F);
    default:
      return const Color(0xFF6B7178);
  }
}

class WeatherService extends ChangeNotifier {
  /// Station the Weather tab last showed.
  String? lastStation;

  /// GET one AWC product. 204 / empty list is "no data", a network failure
  /// is "offline", anything else non-200 is "failed". A 5xx is retried once:
  /// the AWC gateway intermittently answers 504 (seen 2026-10-14).
  Future<AwcAnswer> get(String product, Map<String, String> query) async {
    final uri = Uri.parse('$awcBase/$product').replace(queryParameters: query);
    http.Response response;
    var attempt = 0;
    try {
      while (true) {
        response = await http.get(uri, headers: {
          'Accept': 'application/json'
        }).timeout(const Duration(seconds: 15));
        if (response.statusCode < 500 || ++attempt >= 2) break;
      }
    } catch (_) {
      // Timeout, no route, DNS, TLS: the server was never reached.
      return const AwcAnswer(FetchStatus.offline);
    }
    if (response.statusCode == 204) {
      return const AwcAnswer(FetchStatus.noData, httpStatus: 204);
    }
    if (response.statusCode != 200) {
      return AwcAnswer(FetchStatus.failed, httpStatus: response.statusCode);
    }
    if (response.body.trim().isEmpty) {
      return const AwcAnswer(FetchStatus.noData, httpStatus: 200);
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is List && decoded.isEmpty) {
        return const AwcAnswer(FetchStatus.noData, httpStatus: 200);
      }
      return AwcAnswer(FetchStatus.ok, json: decoded, httpStatus: 200);
    } on FormatException {
      return const AwcAnswer(FetchStatus.failed, httpStatus: 200);
    }
  }

  static Map<dynamic, dynamic>? _first(Object? json) {
    if (json is List) {
      for (final item in json) {
        if (item is Map) return item;
      }
    }
    return null;
  }

  /// Latest METAR for [station] (ICAO).
  Future<(FetchStatus, MetarObservation?)> fetchMetar(String station) async {
    final a = await get('metar', {
      'ids': station.trim().toUpperCase(),
      'format': 'json',
    });
    if (a.status != FetchStatus.ok) return (a.status, null);
    final m = _first(a.json);
    if (m == null) return (FetchStatus.noData, null);
    return (FetchStatus.ok, MetarObservation.fromJson(m));
  }

  /// Current TAF for [station]. Many fields (KPAO among them) issue none.
  Future<(FetchStatus, TafReport?)> fetchTaf(String station) async {
    final a = await get('taf', {
      'ids': station.trim().toUpperCase(),
      'format': 'json',
    });
    if (a.status != FetchStatus.ok) return (a.status, null);
    final m = _first(a.json);
    if (m == null) return (FetchStatus.noData, null);
    return (FetchStatus.ok, TafReport.fromJson(m));
  }

  /// Airport reference data for [icao] from the Aviation Weather Center.
  ///
  /// Returns null when AWC has no record (it answers 204 with an empty body,
  /// also for IATA codes such as "LAX"). Throws on a network failure, a
  /// timeout or any other status, so the caller can say the lookup failed
  /// rather than show an empty card. A 5xx is retried once.
  Future<AirportReference?> fetchAirportDetail(String icao) async {
    final uri = Uri.parse('$awcBase/airport').replace(queryParameters: {
      'ids': icao.trim().toUpperCase(),
      'format': 'json',
    });

    http.Response response;
    var attempt = 0;
    while (true) {
      response = await http.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode < 500 || ++attempt >= 2) break;
    }

    if (response.statusCode == 204) return null;
    if (response.statusCode != 200) {
      throw http.ClientException('AWC airport ${response.statusCode}', uri);
    }
    if (response.body.trim().isEmpty) return null;

    final decoded = jsonDecode(response.body);
    final m = _first(decoded);
    return m == null ? null : AirportReference.fromJson(m);
  }

  /// METAR, TAF and airport (for runway alignments) together, each with its
  /// own status so one failing does not hide the others.
  Future<WeatherSnapshot> fetchSnapshot(String station,
      {DateTime Function() clock = DateTime.now}) async {
    final id = station.trim().toUpperCase();
    final results = await Future.wait([
      fetchMetar(id),
      fetchTaf(id),
      _airportStatus(id),
    ]);
    final metar = results[0] as (FetchStatus, MetarObservation?);
    final taf = results[1] as (FetchStatus, TafReport?);
    final apt = results[2] as (FetchStatus, AirportReference?);
    return WeatherSnapshot(
      station: id,
      metarStatus: metar.$1,
      metar: metar.$2,
      tafStatus: taf.$1,
      taf: taf.$2,
      airportStatus: apt.$1,
      airport: apt.$2,
      fetchedAt: clock(),
    );
  }

  Future<(FetchStatus, AirportReference?)> _airportStatus(String id) async {
    try {
      final a = await fetchAirportDetail(id);
      return (a == null ? FetchStatus.noData : FetchStatus.ok, a);
    } on http.ClientException catch (e) {
      return (
        e.message.startsWith('AWC airport') ? FetchStatus.failed : FetchStatus.offline,
        null
      );
    } catch (_) {
      return (FetchStatus.offline, null);
    }
  }

  /// PIREPs (pilot reports) from AWC, newest first, at most ten.
  Future<List<Map<String, dynamic>>> fetchPireps({String? icao}) async {
    try {
      String url = '$awcBase/pirep?format=json&age=2';
      if (icao != null) url += '&id=$icao';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .take(10)
              .toList();
        }
      }
    } catch (e) {
      debugPrint('PIREP fetch error: $e');
    }
    return [];
  }

  /// International SIGMETs from AWC.
  Future<List<Map<String, dynamic>>> fetchSigmets() async {
    try {
      const url = '$awcBase/isigmet?format=json';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .take(10)
              .toList();
        }
      }
    } catch (e) {
      debugPrint('SIGMET fetch error: $e');
    }
    return [];
  }

  /// G-AIRMETs (graphical AIRMETs) from AWC.
  Future<List<Map<String, dynamic>>> fetchAirmets() async {
    try {
      const url = '$awcBase/airmet?format=json';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .take(15)
              .toList();
        }
      }
    } catch (e) {
      debugPrint('AIRMET fetch error: $e');
    }
    return [];
  }

  /// Winds and temperatures aloft. AWC serves the FB text product; a JSON
  /// form is tried first and the raw text is the fallback.
  Future<List<Map<String, dynamic>>> fetchWindsAloft({String? region}) async {
    final reg = region ?? 'all';
    try {
      final url = '$awcBase/windtemp?format=json&region=$reg&level=low';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          return data
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .take(15)
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Winds aloft (json) fetch error: $e');
    }

    try {
      final url = '$awcBase/windtemp?region=$reg&level=low';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
        return [
          {'raw': response.body.trim()}
        ];
      }
    } catch (e) {
      debugPrint('Winds aloft (raw FB) fetch error: $e');
    }
    return [];
  }
}
