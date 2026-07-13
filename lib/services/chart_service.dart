import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Charts & Plates browser backed by the FREE FAA data mirror at
// aviationapi.com (no API key required, US airports only).
//
// Endpoint (no key):
//   https://api.aviationapi.com/v1/charts?apt=KLAX
// returns, without group=1:
//   { "KLAX": [ { chart_name, chart_code, pdf_path (full FAA https URL),
//                 pdf_name, ... } ] }
//
// chart_code values observed: APD (airport diagram), MIN (takeoff/alternate
// minimums), IAP (instrument approach), DP (departure), STAR (arrival),
// LAH, HOT, etc.
//
// TODO(charts): geo-referenced overlay on the moving map requires a licensed
// chart provider; this is the free PDF/plate viewer.

const String _chartsBase = 'https://api.aviationapi.com/v1/charts';

/// Human-readable chart categories used to group results in the UI.
///
/// Ordered by the priority in which they should be displayed.
const List<String> kChartCategories = <String>[
  'Airport Diagram',
  'Approaches (IAP)',
  'Departures (DP)',
  'Arrivals (STAR)',
  'Minimums',
  'Other',
];

/// A single FAA chart / plate document.
class ChartDoc {
  /// Human title, e.g. "AIRPORT DIAGRAM" or "ILS OR LOC RWY 25L".
  final String name;

  /// Raw FAA chart_code, e.g. APD / IAP / DP / STAR / MIN.
  final String code;

  /// Human-readable category bucket (see [kChartCategories]).
  final String category;

  /// Full https URL to the FAA PDF plate.
  final String pdfUrl;

  const ChartDoc({
    required this.name,
    required this.code,
    required this.category,
    required this.pdfUrl,
  });

  /// Defensively parse a single chart entry. Returns null when the item is
  /// malformed or has no usable PDF URL.
  static ChartDoc? fromJson(Object? item) {
    if (item is! Map) return null;
    final map = item;

    final pdf = (map['pdf_path'] ?? map['pdf_name'])?.toString().trim() ?? '';
    if (pdf.isEmpty || !pdf.startsWith('http')) return null;

    final code = (map['chart_code'] ?? '').toString().trim();
    final name = (map['chart_name'] ?? map['pdf_name'] ?? 'Chart')
        .toString()
        .trim();

    return ChartDoc(
      name: name.isEmpty ? 'Chart' : name,
      code: code,
      category: categoryForCode(code),
      pdfUrl: pdf,
    );
  }

  /// Map a raw FAA chart_code to a human category bucket.
  static String categoryForCode(String code) {
    switch (code.toUpperCase()) {
      case 'APD':
        return 'Airport Diagram';
      case 'IAP':
        return 'Approaches (IAP)';
      case 'DP':
        return 'Departures (DP)';
      case 'STAR':
        return 'Arrivals (STAR)';
      case 'MIN':
        return 'Minimums';
      default:
        return 'Other';
    }
  }
}

/// Fetches FAA charts from the free aviationapi.com mirror and persists a list
/// of recently-viewed airports.
///
/// Instantiate and dispose in the owning screen's [State] — no global provider
/// registration is required.
class ChartService extends ChangeNotifier {
  static const String _prefsRecentKey = 'charts_recent';
  static const int _maxRecent = 8;

  bool _isLoading = false;
  String? _error;
  List<String> _recent = const [];

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Recently-viewed airport ICAO codes, most recent first.
  List<String> get recent => List.unmodifiable(_recent);

  /// Load the persisted list of recently-viewed airports.
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

  /// Fetch charts for a US airport, grouped by human category.
  ///
  /// Returns a map keyed by category name (only non-empty categories are
  /// present, ordered per [kChartCategories]). On any failure the returned map
  /// is empty and [error] is set. Never throws.
  Future<Map<String, List<ChartDoc>>> fetchCharts(String icao) async {
    final code = icao.trim().toUpperCase();
    if (code.isEmpty) {
      _error = 'Enter an airport identifier.';
      notifyListeners();
      return {};
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    Map<String, List<ChartDoc>> grouped = {};
    try {
      final docs = await _fetch(code);
      if (docs.isEmpty) {
        _error = 'No charts found for $code. US airports only.';
      } else {
        grouped = _group(docs);
        unawaited(_addRecent(code));
      }
    } on TimeoutException {
      _error = 'Request timed out. Check your connection and try again.';
    } catch (_) {
      _error = 'Could not load charts for $code. Please try again.';
    }

    _isLoading = false;
    notifyListeners();
    return grouped;
  }

  /// Core network call. Throws on any failure so [fetchCharts] can report it.
  Future<List<ChartDoc>> _fetch(String icao) async {
    final uri = Uri.parse(_chartsBase).replace(queryParameters: {'apt': icao});

    final response = await http
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw http.ClientException('Charts API ${response.statusCode}', uri);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return const [];

    // Response is keyed by ICAO. Accept the requested key, or fall back to the
    // first list-valued entry to tolerate case / formatting differences.
    Object? entry = decoded[icao];
    if (entry is! List) {
      for (final v in decoded.values) {
        if (v is List) {
          entry = v;
          break;
        }
      }
    }
    if (entry is! List) return const [];

    final out = <ChartDoc>[];
    for (final item in entry) {
      final doc = ChartDoc.fromJson(item);
      if (doc != null) out.add(doc);
    }
    return out;
  }

  /// Group parsed docs into ordered, non-empty category buckets.
  Map<String, List<ChartDoc>> _group(List<ChartDoc> docs) {
    final buckets = <String, List<ChartDoc>>{};
    for (final category in kChartCategories) {
      final matches = docs.where((d) => d.category == category).toList();
      if (matches.isNotEmpty) buckets[category] = matches;
    }
    return buckets;
  }
}
