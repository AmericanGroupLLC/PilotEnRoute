import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Charts & Plates: the FAA's official digital Terminal Procedures Publication
// (d-TPP) — airport diagrams, approaches, departures, arrivals, minimums.
//
// This used to call the free mirror api.aviationapi.com, which no longer has
// any DNS record, so every request failed. The FAA's own per-cycle index
// (https://aeronav.faa.gov/d-tpp/<cycle>/xml_data/d-tpp_Metafile.xml) is about
// 16 MB of XML, too much to download on a phone to list one airport's charts.
// Instead the app opens the FAA's official d-TPP search for the airport in the
// browser; that page lists every chart for the cycle, each linking to its PDF
// on aeronav.faa.gov:
//   https://www.faa.gov/air_traffic/flight_info/aeronav/digital_products/dtpp/search/results/?cycle=2610&ident=KLAX
// US airports only. Accepts the ICAO (KLAX) or FAA (LAX) identifier.
//
// TODO(charts): geo-referenced overlay on the moving map requires a licensed
// chart provider.

/// First day of AIRAC/d-TPP cycle 2601. Cycles are [kDtppCycleDays] long.
final DateTime kDtppCycleAnchor = DateTime.utc(2026, 1, 22);
const int kDtppCycleDays = 28;

/// The d-TPP cycle id (YYNN, e.g. "2610") in effect on [when].
///
/// YY is the year the cycle starts in and NN its number within that year, so
/// the id rolls over every 28 days without a code change.
String dtppCycleFor(DateTime when) {
  final utc = when.toUtc();
  final day = DateTime.utc(utc.year, utc.month, utc.day);
  final elapsed = day.difference(kDtppCycleAnchor).inDays;
  final n = (elapsed / kDtppCycleDays).floor();
  final start = kDtppCycleAnchor.add(Duration(days: n * kDtppCycleDays));

  var number = 1;
  var previous = start.subtract(const Duration(days: kDtppCycleDays));
  while (previous.year == start.year) {
    number++;
    previous = previous.subtract(const Duration(days: kDtppCycleDays));
  }
  final yy = (start.year % 100).toString().padLeft(2, '0');
  return '$yy${number.toString().padLeft(2, '0')}';
}

/// The FAA's official d-TPP search results page for [ident] in the cycle in
/// effect on [now] (defaults to the current time).
Uri dtppSearchUri(String ident, {DateTime? now}) => Uri.https(
      'www.faa.gov',
      '/air_traffic/flight_info/aeronav/digital_products/dtpp/search/results/',
      {
        'cycle': dtppCycleFor(now ?? DateTime.now()),
        'ident': ident.trim().toUpperCase(),
      },
    );

final RegExp _identPattern = RegExp(r'^[A-Z0-9]{3,4}$');

/// Builds the FAA d-TPP link for an airport and persists a list of
/// recently-opened airports.
///
/// Instantiate and dispose in the owning screen's [State] — no global provider
/// registration is required.
class ChartService extends ChangeNotifier {
  static const String _prefsRecentKey = 'charts_recent';
  static const int _maxRecent = 8;

  String? _error;
  List<String> _recent = const [];

  String? get error => _error;

  /// Recently-opened airport identifiers, most recent first.
  List<String> get recent => List.unmodifiable(_recent);

  /// Load the persisted list of recently-opened airports.
  Future<void> loadRecent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _recent = prefs.getStringList(_prefsRecentKey) ?? const [];
    } catch (_) {
      _recent = const [];
    }
    notifyListeners();
  }

  Future<void> _addRecent(String icao) async {
    final code = icao.trim().toUpperCase();
    if (code.isEmpty) return;
    final updated = <String>[code, ..._recent.where((e) => e != code)];
    if (updated.length > _maxRecent) {
      updated.removeRange(_maxRecent, updated.length);
    }
    _recent = updated;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsRecentKey, _recent);
    } catch (_) {
      // Persistence is best-effort; ignore failures.
    }
  }

  /// The FAA d-TPP search link for [icao], recorded as recent.
  ///
  /// Returns null and sets [error] when the identifier is empty or is not a
  /// 3-4 character airport identifier. Never throws.
  Uri? linkFor(String icao, {DateTime? now}) {
    final code = icao.trim().toUpperCase();
    if (code.isEmpty) {
      _error = 'Enter an airport identifier.';
      notifyListeners();
      return null;
    }
    if (!_identPattern.hasMatch(code)) {
      _error = '$code is not an airport identifier. Use ICAO (KLAX) or '
          'FAA (LAX).';
      notifyListeners();
      return null;
    }
    _error = null;
    unawaited(_addRecent(code));
    return dtppSearchUri(code, now: now);
  }
}
