import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Navigation Database service — VOR / NDB / TACAN / DME navaids sourced from the
// free, open OurAirports dataset, plus user-defined favorites and waypoints.
//
// Data source (FREE, no API key):
//   https://davidmegginson.github.io/ourairports-data/navaids.csv
//
// The CSV is a few MB. We fetch it ONCE per session, parse the useful subset,
// and hold it in memory.
//
// TODO(navdb): cache to Hive/sqflite for offline; consider a bundled subset to
// avoid a multi-MB download.
// TODO(navdb): add en-route fixes/waypoints dataset (e.g. FAA CIFP/NASR) for
// intersections & RNAV fixes — these are NOT present in navaids.csv.
// ─────────────────────────────────────────────────────────────────────────────

const String _navaidsCsvUrl =
    'https://davidmegginson.github.io/ourairports-data/navaids.csv';

const String _favoritesKey = 'navdb_favorites';
const String _userWaypointsKey = 'navdb_user_waypoints';

/// Maximum number of parsed navaids kept in memory / rendered — guards against
/// the multi-thousand-row dataset overwhelming the UI.
const int kMaxSearchResults = 200;

/// A single navaid parsed from the OurAirports dataset.
class Navaid {
  final String ident;
  final String name;
  final String type; // VOR, VOR-DME, NDB, TACAN, DME, etc.
  final double? frequencyMhz; // frequency_khz / 1000
  final double lat;
  final double lon;
  final double? elevationFt;
  final String country;

  const Navaid({
    required this.ident,
    required this.name,
    required this.type,
    required this.frequencyMhz,
    required this.lat,
    required this.lon,
    required this.elevationFt,
    required this.country,
  });

  /// Parse a CSV row given a column-name → index lookup. Returns null when the
  /// row is malformed or lacks the essentials (ident + coordinates).
  static Navaid? fromCsvRow(List<String> row, Map<String, int> cols) {
    String field(String name) {
      final i = cols[name];
      if (i == null || i < 0 || i >= row.length) return '';
      return row[i].trim();
    }

    final ident = field('ident');
    if (ident.isEmpty) return null;

    final lat = double.tryParse(field('latitude_deg'));
    final lon = double.tryParse(field('longitude_deg'));
    if (lat == null || lon == null) return null;

    final khz = double.tryParse(field('frequency_khz'));
    final elev = double.tryParse(field('elevation_ft'));

    final type = field('type');
    final name = field('name');

    return Navaid(
      ident: ident,
      name: name.isEmpty ? ident : name,
      type: type.isEmpty ? 'NAVAID' : type,
      frequencyMhz: khz != null ? khz / 1000.0 : null,
      lat: lat,
      lon: lon,
      elevationFt: elev,
      country: field('iso_country'),
    );
  }
}

/// A user-created waypoint (persisted to shared_preferences).
class UserWaypoint {
  final String id;
  final String name;
  final double lat;
  final double lon;

  const UserWaypoint({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lat': lat,
        'lon': lon,
      };

  static UserWaypoint? fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    final name = json['name']?.toString();
    final lat = (json['lat'] as num?)?.toDouble();
    final lon = (json['lon'] as num?)?.toDouble();
    if (id == null || name == null || lat == null || lon == null) return null;
    return UserWaypoint(id: id, name: name, lat: lat, lon: lon);
  }
}

/// Owns navaid data, favorites, and user waypoints.
///
/// Instantiate and dispose in the owning screen's [State] — no global provider
/// registration is required.
class NavDbService extends ChangeNotifier {
  bool _isLoading = false;
  bool _isLoaded = false;
  String? _error;

  List<Navaid> _navaids = const [];
  final Set<String> _favorites = <String>{};
  final List<UserWaypoint> _userWaypoints = <UserWaypoint>[];

  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;
  String? get error => _error;
  int get navaidCount => _navaids.length;

  List<Navaid> get navaids => List.unmodifiable(_navaids);
  List<String> get favorites => List.unmodifiable(_favorites);
  List<UserWaypoint> get userWaypoints => List.unmodifiable(_userWaypoints);

  /// The distinct type filters offered in the UI (mapped to substring matches).
  static const List<String> typeFilters = ['All', 'VOR', 'NDB', 'TACAN', 'DME'];

  // ── Persistence bootstrap ──────────────────────────────────────────────────

  /// Load favorites + user waypoints from disk. Safe to call multiple times.
  Future<void> loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final favs = prefs.getStringList(_favoritesKey);
      if (favs != null) {
        _favorites
          ..clear()
          ..addAll(favs);
      }

      final wps = prefs.getStringList(_userWaypointsKey);
      if (wps != null) {
        _userWaypoints.clear();
        for (final raw in wps) {
          try {
            final decoded = jsonDecode(raw);
            if (decoded is Map<String, dynamic>) {
              final wp = UserWaypoint.fromJson(decoded);
              if (wp != null) _userWaypoints.add(wp);
            }
          } catch (_) {
            // Skip malformed entries.
          }
        }
      }
      notifyListeners();
    } catch (_) {
      // Persistence is best-effort; ignore failures.
    }
  }

  // ── Navaid loading ─────────────────────────────────────────────────────────

  /// Fetch + parse the navaids CSV exactly once. Subsequent calls are no-ops
  /// unless a previous attempt failed.
  Future<void> ensureLoaded() async {
    if (_isLoaded || _isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http
          .get(Uri.parse(_navaidsCsvUrl))
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw http.ClientException(
            'Navaid data ${response.statusCode}', Uri.parse(_navaidsCsvUrl));
      }

      _navaids = _parseCsv(response.body);
      _isLoaded = true;
      _error = null;
    } catch (e) {
      _error = 'Could not load navaid data. Check your connection and retry.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Force a reload (used by retry / pull-to-refresh).
  Future<void> reload() async {
    _isLoaded = false;
    await ensureLoaded();
  }

  /// Minimal RFC-4180-ish CSV parser that handles quoted fields with commas
  /// and escaped double-quotes. Robust to trailing/blank lines.
  List<Navaid> _parseCsv(String body) {
    final rows = _splitRows(body);
    if (rows.isEmpty) return const [];

    final header = _splitFields(rows.first);
    final cols = <String, int>{};
    for (var i = 0; i < header.length; i++) {
      cols[header[i].trim()] = i;
    }

    final out = <Navaid>[];
    for (var i = 1; i < rows.length; i++) {
      final line = rows[i];
      if (line.trim().isEmpty) continue;
      try {
        final fields = _splitFields(line);
        final navaid = Navaid.fromCsvRow(fields, cols);
        if (navaid != null) out.add(navaid);
      } catch (_) {
        // Never let one bad row abort the parse.
      }
    }
    return out;
  }

  /// Split the file into logical rows, respecting newlines inside quotes.
  List<String> _splitRows(String body) {
    final rows = <String>[];
    final sb = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < body.length; i++) {
      final ch = body[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
        sb.write(ch);
      } else if ((ch == '\n' || ch == '\r') && !inQuotes) {
        if (sb.isNotEmpty) {
          rows.add(sb.toString());
          sb.clear();
        }
      } else {
        sb.write(ch);
      }
    }
    if (sb.isNotEmpty) rows.add(sb.toString());
    return rows;
  }

  /// Split a single CSV line into fields.
  List<String> _splitFields(String line) {
    final fields = <String>[];
    final sb = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          sb.write('"');
          i++; // skip escaped quote
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == ',' && !inQuotes) {
        fields.add(sb.toString());
        sb.clear();
      } else {
        sb.write(ch);
      }
    }
    fields.add(sb.toString());
    return fields;
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  /// Case-insensitive search by ident or name, optionally filtered by type.
  /// [typeFilter] is one of [typeFilters]; 'All' (or null) disables filtering.
  /// Capped at [kMaxSearchResults] to keep rendering bounded.
  List<Navaid> search(String query, {String? typeFilter}) {
    final q = query.trim().toLowerCase();
    final filter = (typeFilter == null || typeFilter == 'All')
        ? null
        : typeFilter.toUpperCase();

    final matches = <Navaid>[];
    for (final n in _navaids) {
      if (filter != null && !n.type.toUpperCase().contains(filter)) continue;
      if (q.isNotEmpty) {
        final inIdent = n.ident.toLowerCase().contains(q);
        final inName = n.name.toLowerCase().contains(q);
        if (!inIdent && !inName) continue;
      }
      matches.add(n);
      if (matches.length >= kMaxSearchResults) break;
    }
    return matches;
  }

  /// Look up navaids by exact ident (used to resolve favorites to full records).
  List<Navaid> byIdents(Iterable<String> idents) {
    final wanted = idents.map((e) => e.toUpperCase()).toSet();
    if (wanted.isEmpty) return const [];
    return _navaids
        .where((n) => wanted.contains(n.ident.toUpperCase()))
        .toList();
  }

  // ── Favorites ──────────────────────────────────────────────────────────────

  bool isFavorite(String ident) => _favorites.contains(ident.toUpperCase());

  Future<void> toggleFavorite(String ident) async {
    final key = ident.toUpperCase();
    if (_favorites.contains(key)) {
      _favorites.remove(key);
    } else {
      _favorites.add(key);
    }
    notifyListeners();
    await _persistFavorites();
  }

  Future<void> _persistFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_favoritesKey, _favorites.toList());
    } catch (_) {
      // Best-effort.
    }
  }

  // ── User waypoints ─────────────────────────────────────────────────────────

  Future<void> addUserWaypoint(String name, double lat, double lon) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    _userWaypoints.add(
      UserWaypoint(id: id, name: name.trim(), lat: lat, lon: lon),
    );
    notifyListeners();
    await _persistUserWaypoints();
  }

  Future<void> removeUserWaypoint(String id) async {
    _userWaypoints.removeWhere((w) => w.id == id);
    notifyListeners();
    await _persistUserWaypoints();
  }

  Future<void> _persistUserWaypoints() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded =
          _userWaypoints.map((w) => jsonEncode(w.toJson())).toList();
      await prefs.setStringList(_userWaypointsKey, encoded);
    } catch (_) {
      // Best-effort.
    }
  }
}
