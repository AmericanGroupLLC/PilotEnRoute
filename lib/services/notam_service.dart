import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// FAA NOTAM API — https://external-api.faa.gov/notamapi/v1/notams
// The FAA API requires client_id / client_secret headers. Supply real
// credentials below to fetch live NOTAMs. Without them, or when a request
// fails, the service returns no NOTAMs and an explicit error — never invented
// notices, and never an empty list that could read as "no NOTAMs".
//
// TODO(notam-keys): supply FAA NOTAM API credentials
const String _faaClientId = '';
const String _faaClientSecret = '';

const String _faaNotamBase = 'https://external-api.faa.gov/notamapi/v1/notams';

/// Broad category used for color-coded chips and filtering.
enum NotamCategory { runway, taxiway, airspace, obstacle, communication, other }

extension NotamCategoryX on NotamCategory {
  /// Short label shown on chips.
  String get label {
    switch (this) {
      case NotamCategory.runway:
        return 'RWY';
      case NotamCategory.taxiway:
        return 'TWY';
      case NotamCategory.airspace:
        return 'AIRSPACE';
      case NotamCategory.obstacle:
        return 'OBST';
      case NotamCategory.communication:
        return 'COM';
      case NotamCategory.other:
        return 'OTHER';
    }
  }

  /// Color-coded accent matching the app palette.
  Color get color {
    switch (this) {
      case NotamCategory.runway:
        return const Color(0xFFF44336); // red — runway closures are critical
      case NotamCategory.taxiway:
        return const Color(0xFFFFB300); // amber
      case NotamCategory.airspace:
        return const Color(0xFF00BCD4); // cyan
      case NotamCategory.obstacle:
        return const Color(0xFFFFB300); // amber
      case NotamCategory.communication:
        return const Color(0xFF4CAF50); // green
      case NotamCategory.other:
        return const Color(0xFF9E9E9E); // grey
    }
  }
}

/// A single decoded NOTAM.
class Notam {
  final String id;
  final String location; // ICAO of the affected facility
  final String type; // classification, e.g. FDC / DOM / INTL
  final String text; // decoded plain-text body
  final DateTime? effectiveStart;
  final DateTime? effectiveEnd;
  final NotamCategory category;

  const Notam({
    required this.id,
    required this.location,
    required this.type,
    required this.text,
    required this.category,
    this.effectiveStart,
    this.effectiveEnd,
  });

  /// Whether the NOTAM has no explicit end (permanent / until further notice).
  bool get isPermanent => effectiveEnd == null;

  /// Parse a single NOTAM item from the FAA API response.
  ///
  /// The FAA response wraps each NOTAM under
  /// `properties.coreNOTAMData.notam`. This adapter is defensive: every field
  /// is optional and safely coerced so malformed items never crash the UI.
  static Notam? fromFaaItem(Map<String, dynamic> item) {
    final props = item['properties'];
    if (props is! Map<String, dynamic>) return null;

    final core = props['coreNOTAMData'];
    final coreMap = core is Map<String, dynamic> ? core : const {};
    final notam = coreMap['notam'];
    final notamMap =
        notam is Map<String, dynamic> ? notam : const <String, dynamic>{};

    final translations = coreMap['notamTranslation'];
    String? decoded;
    if (translations is List) {
      for (final t in translations) {
        if (t is Map<String, dynamic>) {
          final simple = t['simpleText']?.toString();
          final formatted = t['formattedText']?.toString();
          decoded = (simple != null && simple.trim().isNotEmpty)
              ? simple
              : formatted;
          if (decoded != null && decoded.trim().isNotEmpty) break;
        }
      }
    }

    final rawText = notamMap['text']?.toString();
    final body = (decoded != null && decoded.trim().isNotEmpty)
        ? decoded.trim()
        : (rawText?.trim() ?? '');
    if (body.isEmpty) return null;

    final id = notamMap['number']?.toString() ??
        notamMap['id']?.toString() ??
        item['id']?.toString() ??
        'NOTAM';
    final location = notamMap['location']?.toString() ??
        notamMap['icaoLocation']?.toString() ??
        '';
    final classification = notamMap['classification']?.toString() ??
        notamMap['type']?.toString() ??
        'NOTAM';

    return Notam(
      id: id,
      location: location,
      type: classification,
      text: body,
      effectiveStart: _tryParseDate(notamMap['effectiveStart']?.toString()),
      effectiveEnd: _tryParseDate(notamMap['effectiveEnd']?.toString()),
      category: _categorize(body),
    );
  }

  static DateTime? _tryParseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    // Values like "PERM" or "UFN" have no parseable date.
    return DateTime.tryParse(value)?.toLocal();
  }

  /// Heuristic classification of a NOTAM into a broad category from its text.
  static NotamCategory _categorize(String text) {
    final t = text.toUpperCase();
    if (t.contains('RWY') || t.contains('RUNWAY')) {
      return NotamCategory.runway;
    }
    if (t.contains('TWY') || t.contains('TAXIWAY')) {
      return NotamCategory.taxiway;
    }
    if (t.contains('AIRSPACE') ||
        t.contains('TFR') ||
        t.contains('RESTRICTED') ||
        t.contains('PROHIBITED') ||
        t.contains('MOA')) {
      return NotamCategory.airspace;
    }
    if (t.contains('OBST') ||
        t.contains('OBSTACLE') ||
        t.contains('CRANE') ||
        t.contains('TOWER')) {
      return NotamCategory.obstacle;
    }
    if (t.contains('COM') ||
        t.contains('FREQ') ||
        t.contains('ILS') ||
        t.contains('VOR') ||
        t.contains('NAV') ||
        t.contains('GPS')) {
      return NotamCategory.communication;
    }
    return NotamCategory.other;
  }
}

/// Fetches NOTAMs from the FAA API. Never substitutes sample notices.
///
/// Instantiate and dispose in the owning screen's [State] — no global provider
/// registration is required.
class NotamService extends ChangeNotifier {
  static const String _prefsLastIcaoKey = 'notam_last_icao';

  static const String noCredentialsMessage =
      'Live NOTAMs aren\'t available in this app yet. Check official NOTAMs '
      'at notams.aim.faa.gov or 1800wxbrief.com before flight.';
  static const String fetchFailedMessage = 'Couldn\'t load NOTAMs. Try again.';

  bool _isLoading = false;
  String? _error;
  List<Notam> _notams = const [];
  String _lastQuery = '';

  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Notam> get notams => List.unmodifiable(_notams);
  String get lastQuery => _lastQuery;

  /// True when this build carries FAA NOTAM API credentials. The drawer hides
  /// the NOTAMs entry when it is false.
  static bool get credentialsConfigured =>
      _faaClientId.isNotEmpty && _faaClientSecret.isNotEmpty;

  bool get hasCredentials => credentialsConfigured;

  /// Load the last searched ICAO from persistent storage, if any.
  Future<String?> loadLastIcao() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefsLastIcaoKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveLastIcao(String icao) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsLastIcaoKey, icao);
    } catch (_) {
      // Persistence is best-effort; ignore failures.
    }
  }

  /// Fetch NOTAMs for a single airport ICAO code.
  Future<void> fetchByAirport(String icao) async {
    final code = icao.trim().toUpperCase();
    if (code.isEmpty) return;
    _lastQuery = code;

    _isLoading = true;
    _error = null;
    notifyListeners();

    final results = await _fetch([code]);
    _notams = results;
    _isLoading = false;
    notifyListeners();

    unawaited(_saveLastIcao(code));
  }

  /// Fetch NOTAMs for a route (list of ICAO codes), merged and de-duplicated.
  Future<void> fetchByRoute(List<String> icaos) async {
    final codes = icaos
        .map((e) => e.trim().toUpperCase())
        .where((e) => e.isNotEmpty)
        .toList();
    if (codes.isEmpty) return;
    _lastQuery = codes.join(' ');

    _isLoading = true;
    _error = null;
    notifyListeners();

    final results = await _fetch(codes);
    _notams = results;
    _isLoading = false;
    notifyListeners();
  }

  /// Core fetch: live FAA API per ICAO. With no credentials, or on any
  /// failure, returns an empty list and sets [error] so the screen can never
  /// present "no NOTAMs" when the truth is "NOTAMs unknown".
  Future<List<Notam>> _fetch(List<String> codes) async {
    if (!hasCredentials) {
      _error = noCredentialsMessage;
      return const [];
    }

    try {
      final all = <Notam>[];
      final seen = <String>{};
      for (final code in codes) {
        final items = await _fetchFaa(code);
        for (final n in items) {
          if (seen.add(n.id)) all.add(n);
        }
      }
      _error = null;
      return all;
    } catch (e) {
      _error = fetchFailedMessage;
      return const [];
    }
  }

  /// Live FAA API call for one ICAO. Throws on any failure so the caller can
  /// report the error.
  Future<List<Notam>> _fetchFaa(String icao) async {
    final uri = Uri.parse(_faaNotamBase).replace(queryParameters: {
      'icaoLocation': icao,
      'pageSize': '50',
      'pageNum': '1',
    });

    final response = await http.get(
      uri,
      headers: {
        'client_id': _faaClientId,
        'client_secret': _faaClientSecret,
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw http.ClientException('FAA API ${response.statusCode}', uri);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return const [];

    final items = decoded['items'];
    if (items is! List) return const [];

    final out = <Notam>[];
    for (final item in items) {
      if (item is Map<String, dynamic>) {
        final n = Notam.fromFaaItem(item);
        if (n != null) out.add(n);
      }
    }
    return out;
  }
}
