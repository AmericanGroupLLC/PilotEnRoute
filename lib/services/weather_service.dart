import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:http/http.dart' as http;

// Aviation Weather Center API — Free, no auth required
// https://aviationweather.gov/data/api/
// RotatePilot METAR proxy (CORS-enabled) — https://rotatepilot.com/api/v1/metar
const String _awcBase = 'https://aviationweather.gov/api/data';
const String _rotatePilotMetar = 'https://rotatepilot.com/api/v1/metar';

// OpenSky Network — Free, anonymous access
// https://opensky-network.org/api
const String _openSkyBase = 'https://opensky-network.org/api';

class MetarData {
  final String icao;
  final String raw;
  final String category; // VFR/MVFR/IFR/LIFR
  final int? ceilingFt;
  final int? windDir;
  final int? windSpeedKt;
  final int? windGustKt;
  final double? temperatureC;
  final double? dewpointC;
  final double? altimeterInHg;
  final double? visibilitySm;
  final String? tafRaw;

  MetarData({
    required this.icao,
    required this.raw,
    required this.category,
    this.ceilingFt,
    this.windDir,
    this.windSpeedKt,
    this.windGustKt,
    this.temperatureC,
    this.dewpointC,
    this.altimeterInHg,
    this.visibilitySm,
    this.tafRaw,
  });

  factory MetarData.fromJson(Map<String, dynamic> json) {
    final taf = json['taf'] as Map<String, dynamic>?;
    // Visibility may arrive under several keys / types depending on source.
    // Guard nulls and non-numeric strings (e.g. "10+") with tryParse.
    final visRaw = json['visibilitySm'] ?? json['visibility'] ?? json['visib'];
    double? vis;
    if (visRaw is num) {
      vis = visRaw.toDouble();
    } else if (visRaw != null) {
      vis = double.tryParse(visRaw.toString().replaceAll(RegExp(r'[^0-9.]'), ''));
    }
    return MetarData(
      icao: json['icao']?.toString() ?? '',
      raw: json['raw']?.toString() ?? '',
      category: json['category']?.toString() ?? 'VFR',
      ceilingFt: (json['ceilingFt'] as num?)?.toInt(),
      windDir: (json['windDir'] as num?)?.toInt(),
      windSpeedKt: (json['windSpeedKt'] as num?)?.toInt(),
      windGustKt: (json['windGustKt'] as num?)?.toInt(),
      temperatureC: (json['temperatureC'] as num?)?.toDouble(),
      dewpointC: (json['dewpointC'] as num?)?.toDouble(),
      altimeterInHg: (json['altimeterInHg'] as num?)?.toDouble(),
      visibilitySm: vis,
      tafRaw: taf?['raw']?.toString(),
    );
  }

  Color get categoryColor {
    switch (category) {
      case 'VFR':
        return const Color(0xFF4CAF50);
      case 'MVFR':
        return const Color(0xFF2196F3);
      case 'IFR':
        return const Color(0xFFF44336);
      case 'LIFR':
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF9E9E9E);
    }
  }
}

class LiveFlight {
  final String icao24;
  final String? callsign;
  final String? country;
  final double? longitude;
  final double? latitude;
  final double? altitude;
  final bool onGround;
  final double? velocity;
  final double? heading;
  final double? verticalRate;

  LiveFlight({
    required this.icao24,
    this.callsign,
    this.country,
    this.longitude,
    this.latitude,
    this.altitude,
    required this.onGround,
    this.velocity,
    this.heading,
    this.verticalRate,
  });

  factory LiveFlight.fromStateVector(List<dynamic> state) {
    return LiveFlight(
      icao24: state[0]?.toString() ?? '',
      callsign: state[1]?.toString().trim(),
      country: state[2]?.toString(),
      longitude: (state[5] as num?)?.toDouble(),
      latitude: (state[6] as num?)?.toDouble(),
      altitude: (state[7] as num?)?.toDouble(),
      onGround: state[8] as bool? ?? false,
      velocity: (state[9] as num?)?.toDouble(),
      heading: (state[10] as num?)?.toDouble(),
      verticalRate: (state[11] as num?)?.toDouble(),
    );
  }
}

class WeatherService extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;
  MetarData? _currentMetar;
  List<LiveFlight> _liveFlights = [];
  bool _flightsLoading = false;

  bool get isLoading => _isLoading;
  String? get error => _error;
  MetarData? get currentMetar => _currentMetar;
  List<LiveFlight> get liveFlights => _liveFlights;
  bool get flightsLoading => _flightsLoading;

  /// Fetch METAR + TAF via RotatePilot (CORS-enabled proxy)
  Future<MetarData?> fetchMetar(String icao, {bool includeTaf = true}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final tafParam = includeTaf ? '&taf=1' : '';
      final url = '$_rotatePilotMetar?icao=${icao.toUpperCase()}$tafParam';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentMetar = MetarData.fromJson(data);
        _isLoading = false;
        notifyListeners();
        return _currentMetar;
      } else {
        _error = 'METAR not available for $icao';
      }
    } catch (e) {
      _error = 'Weather fetch failed: $e';
      debugPrint(_error);
    }

    _isLoading = false;
    notifyListeners();
    return null;
  }

  /// Fetch live flights over a bounding box from OpenSky Network
  /// Anonymous access: 400 credits/day, 10s resolution
  Future<void> fetchLiveFlights({
    double lamin = 24.0,
    double lomin = -125.0,
    double lamax = 50.0,
    double lomax = -66.0,
  }) async {
    _flightsLoading = true;
    notifyListeners();

    try {
      final url =
          '$_openSkyBase/states/all?lamin=$lamin&lomin=$lomin&lamax=$lamax&lomax=$lomax';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final states = data['states'] as List? ?? [];
        _liveFlights = states
            .where((s) => s != null && (s as List).length > 10)
            .map((s) => LiveFlight.fromStateVector(s as List))
            .where((f) => f.latitude != null && f.longitude != null)
            .take(200)
            .toList();
      } else if (response.statusCode == 429) {
        _error = 'Rate limit reached. Try again in a few minutes.';
      }
    } catch (e) {
      debugPrint('Live flights error: $e');
      // Silently fail — live flights are optional
    }

    _flightsLoading = false;
    notifyListeners();
  }

  /// Fetch PIREP (Pilot Reports) from Aviation Weather Center
  Future<List<Map<String, dynamic>>> fetchPireps({String? icao}) async {
    try {
      String url = '$_awcBase/pirep?format=json&age=2';
      if (icao != null) url += '&id=$icao';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.cast<Map<String, dynamic>>().take(10).toList();
        }
      }
    } catch (e) {
      debugPrint('PIREP fetch error: $e');
    }
    return [];
  }

  /// Fetch SIGMETs from Aviation Weather Center
  Future<List<Map<String, dynamic>>> fetchSigmets() async {
    try {
      const url = '$_awcBase/isigmet?format=json';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.cast<Map<String, dynamic>>().take(10).toList();
        }
      }
    } catch (e) {
      debugPrint('SIGMET fetch error: $e');
    }
    return [];
  }

  /// Fetch G-AIRMETs (graphical AIRMETs) from Aviation Weather Center
  Future<List<Map<String, dynamic>>> fetchAirmets() async {
    try {
      const url = '$_awcBase/airmet?format=json';
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

  /// Fetch winds/temperatures aloft from Aviation Weather Center.
  // TODO(weather): confirm winds-aloft endpoint/shape; fallback to raw FB text.
  Future<List<Map<String, dynamic>>> fetchWindsAloft({String? region}) async {
    final reg = region ?? 'all';
    // Primary attempt: structured JSON winds/temps aloft.
    try {
      final url = '$_awcBase/windtemp?format=json&region=$reg&level=low';
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

    // Fallback: fetch the FB text product and return as a single raw entry.
    try {
      final url = '$_awcBase/windtemp?region=$reg&level=low';
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
