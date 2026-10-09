import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AircraftState {
  final String icao24;
  final String? callsign;
  final String? originCountry;
  final double? longitude;
  final double? latitude;
  final double? baroAltitude;
  final bool onGround;
  final double? velocity;
  final double? trueTrack;
  final double? verticalRate;
  final String? squawk;
  final int? lastContact;

  AircraftState({
    required this.icao24,
    this.callsign,
    this.originCountry,
    this.longitude,
    this.latitude,
    this.baroAltitude,
    this.onGround = false,
    this.velocity,
    this.trueTrack,
    this.verticalRate,
    this.squawk,
    this.lastContact,
  });

  factory AircraftState.fromList(List<dynamic> s) => AircraftState(
        icao24: s[0] ?? '',
        callsign: (s[1] as String?)?.trim(),
        originCountry: s[2],
        longitude: s[5]?.toDouble(),
        latitude: s[6]?.toDouble(),
        baroAltitude: s[7]?.toDouble(),
        onGround: s[8] ?? false,
        velocity: s[9]?.toDouble(),
        trueTrack: s[10]?.toDouble(),
        verticalRate: s[11]?.toDouble(),
        squawk: s[14],
        lastContact: s[4],
      );

  String get altitudeFt {
    if (baroAltitude == null) return 'N/A';
    return '${(baroAltitude! * 3.28084).round()} ft';
  }

  String get speedKts {
    if (velocity == null) return 'N/A';
    return '${(velocity! * 1.94384).round()} kts';
  }

  String get headingStr {
    if (trueTrack == null) return 'N/A';
    return '${trueTrack!.round()}°';
  }
}

class TailNumberInfo {
  final String tailNumber;
  final String? aircraftType;
  final String? manufacturer;
  final String? model;
  final String? owner;
  final String? registrationDate;
  final String? status;
  final String? engineType;
  final String? seats;
  final String? weight;

  TailNumberInfo({
    required this.tailNumber,
    this.aircraftType,
    this.manufacturer,
    this.model,
    this.owner,
    this.registrationDate,
    this.status,
    this.engineType,
    this.seats,
    this.weight,
  });
}

class FlightTrackerService extends ChangeNotifier {
  List<AircraftState> _nearbyFlights = [];
  AircraftState? _trackedFlight;
  TailNumberInfo? _tailNumberInfo;
  bool _isLoading = false;
  String? _error;
  String? _tailError;
  String _searchQuery = '';

  List<AircraftState> get nearbyFlights => _nearbyFlights;
  AircraftState? get trackedFlight => _trackedFlight;
  TailNumberInfo? get tailNumberInfo => _tailNumberInfo;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get tailError => _tailError;
  String get searchQuery => _searchQuery;

  // OpenSky Network API — free, no auth required
  static const _openSkyBase = 'https://opensky-network.org/api';

  // adsbdb.com — free, keyless public aircraft database. Accepts a
  // registration (e.g. N21108) and returns type, manufacturer and owner.
  static const _adsbdbBase = 'https://api.adsbdb.com/v0/aircraft';

  static const liveTrafficUnavailableMessage =
      'Live traffic unavailable right now (OpenSky). Tap refresh to retry.';

  /// Official FAA N-Number inquiry page for [tail], for the user to check
  /// registration status themselves (the app does not verify registration).
  static Uri faaRegistryUri(String tail) {
    final n = tail.toUpperCase().replaceAll(' ', '');
    final digits = n.startsWith('N') ? n.substring(1) : n;
    return Uri.parse(
      'https://registry.faa.gov/aircraftinquiry/Search/NNumberResult?nNumberTxt=$digits',
    );
  }

  // Fetch flights in a bounding box (around a location)
  Future<void> fetchNearbyFlights({
    double lat = 37.7749,
    double lon = -122.4194,
    double radius = 2.0, // degrees
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final url = Uri.parse(
        '$_openSkyBase/states/all'
        '?lamin=${lat - radius}&lomin=${lon - radius}'
        '&lamax=${lat + radius}&lomax=${lon + radius}',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final states = data['states'] as List<dynamic>? ?? [];
        _nearbyFlights = states
            .where((s) => s != null && s.length > 8)
            .map((s) => AircraftState.fromList(s))
            .where((a) => !a.onGround)
            .toList();
        _nearbyFlights.sort((a, b) {
          final altA = a.baroAltitude ?? 0;
          final altB = b.baroAltitude ?? 0;
          return altB.compareTo(altA);
        });
      } else {
        // Never substitute invented aircraft: an empty list plus an honest
        // error is the only safe answer when live traffic is unavailable.
        _error = liveTrafficUnavailableMessage;
        _nearbyFlights = [];
      }
    } catch (e) {
      _error = liveTrafficUnavailableMessage;
      _nearbyFlights = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  // Search by callsign or ICAO24
  Future<void> searchByCallsign(String callsign) async {
    _searchQuery = callsign.toUpperCase();
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final url = Uri.parse('$_openSkyBase/states/all');
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final states = data['states'] as List<dynamic>? ?? [];
        final all = states
            .where((s) => s != null && s.length > 8)
            .map((s) => AircraftState.fromList(s))
            .toList();

        final match = all.where((a) =>
            (a.callsign?.toUpperCase().contains(_searchQuery) ?? false) ||
            a.icao24.toUpperCase().contains(_searchQuery));

        if (match.isNotEmpty) {
          _trackedFlight = match.first;
        } else {
          _error = 'No flight found for "$callsign"';
          _trackedFlight = null;
        }
      } else {
        _error = 'API unavailable. Try again.';
      }
    } catch (e) {
      _error = 'Network error.';
    }

    _isLoading = false;
    notifyListeners();
  }

  // Aircraft lookup by registration via adsbdb.com. This shows only what
  // the public database returns; it is not an FAA registration check.
  Future<void> lookupTailNumber(String tailNumber) async {
    _isLoading = true;
    _tailError = null;
    _tailNumberInfo = null;
    notifyListeners();

    final normalized = tailNumber.toUpperCase().replaceAll(' ', '');
    if (normalized.isEmpty) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final url = Uri.parse('$_adsbdbBase/${Uri.encodeComponent(normalized)}');
      final response =
          await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aircraft = (data is Map && data['response'] is Map)
            ? (data['response'] as Map)['aircraft']
            : null;
        if (aircraft is Map) {
          String? str(String key) {
            final v = aircraft[key];
            return (v is String && v.trim().isNotEmpty) ? v.trim() : null;
          }

          _tailNumberInfo = TailNumberInfo(
            tailNumber: str('registration') ?? normalized,
            aircraftType: str('icao_type'),
            manufacturer: str('manufacturer'),
            model: str('type'),
            owner: str('registered_owner'),
          );
        } else {
          _tailError = _tailNotFoundMessage(normalized);
        }
      } else if (response.statusCode == 404) {
        _tailError = _tailNotFoundMessage(normalized);
      } else {
        _tailError = 'Couldn\'t reach the aircraft database. Try again.';
      }
    } catch (e) {
      _tailError =
          'Couldn\'t reach the aircraft database. Check your connection and try again.';
    }

    _isLoading = false;
    notifyListeners();
  }

  String _tailNotFoundMessage(String tail) =>
      'No record for $tail in the public aircraft database (adsbdb.com). '
      'This does not confirm or deny FAA registration. Check the FAA Registry.';

  // Airport arrivals — flights that landed at <icao> in the last ~12 hours.
  // TODO(tracking): airline schedules/delay data need a commercial API
  // (AviationStack/FlightAware); OpenSky gives historical arrivals/departures
  // for the free demo.
  Future<List<Map<String, dynamic>>> fetchArrivals(String icao) async {
    final airport = icao.trim().toUpperCase();
    if (airport.isEmpty) return [];

    // OpenSky requires begin/end within ~7 days and a not-too-large range.
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final begin = now - 43200; // last ~12 hours

    try {
      final url = Uri.parse(
        '$_openSkyBase/flights/arrival'
        '?airport=$airport&begin=$begin&end=$now',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is! List) return [];
        return data.map<Map<String, dynamic>>((f) {
          final callsign = (f['callsign'] as String?)?.trim();
          final icao24 = (f['icao24'] as String?)?.trim();
          return {
            'callsign': (callsign != null && callsign.isNotEmpty)
                ? callsign
                : (icao24 ?? 'Unknown').toUpperCase(),
            'from': f['estDepartureAirport'] ?? 'Unknown',
            'to': airport,
            'time': f['lastSeen'],
          };
        }).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Airport departures — flights that took off from <icao> in the last ~12 hours.
  Future<List<Map<String, dynamic>>> fetchDepartures(String icao) async {
    final airport = icao.trim().toUpperCase();
    if (airport.isEmpty) return [];

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final begin = now - 43200; // last ~12 hours

    try {
      final url = Uri.parse(
        '$_openSkyBase/flights/departure'
        '?airport=$airport&begin=$begin&end=$now',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is! List) return [];
        return data.map<Map<String, dynamic>>((f) {
          final callsign = (f['callsign'] as String?)?.trim();
          final icao24 = (f['icao24'] as String?)?.trim();
          return {
            'callsign': (callsign != null && callsign.isNotEmpty)
                ? callsign
                : (icao24 ?? 'Unknown').toUpperCase(),
            'from': airport,
            'to': f['estArrivalAirport'] ?? 'Unknown',
            'time': f['firstSeen'],
          };
        }).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
