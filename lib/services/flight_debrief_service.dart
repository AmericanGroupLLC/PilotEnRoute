import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A single sampled point along a recorded flight track.
class TrackPoint {
  /// Latitude in degrees.
  final double lat;

  /// Longitude in degrees.
  final double lon;

  /// Pressure/GPS altitude in feet MSL.
  final double altitudeFt;

  /// Ground speed in knots.
  final double groundSpeedKt;

  /// Track/heading in degrees true (0-360).
  final double headingDeg;

  /// Offset from the start of the track, in seconds.
  final int timestamp;

  const TrackPoint({
    required this.lat,
    required this.lon,
    required this.altitudeFt,
    required this.groundSpeedKt,
    required this.headingDeg,
    required this.timestamp,
  });

  LatLng get latLng => LatLng(lat, lon);

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lon': lon,
        'alt': altitudeFt,
        'gs': groundSpeedKt,
        'hdg': headingDeg,
        't': timestamp,
      };

  factory TrackPoint.fromJson(Map<String, dynamic> j) => TrackPoint(
        lat: (j['lat'] as num?)?.toDouble() ?? 0,
        lon: (j['lon'] as num?)?.toDouble() ?? 0,
        altitudeFt: (j['alt'] as num?)?.toDouble() ?? 0,
        groundSpeedKt: (j['gs'] as num?)?.toDouble() ?? 0,
        headingDeg: (j['hdg'] as num?)?.toDouble() ?? 0,
        timestamp: (j['t'] as num?)?.toInt() ?? 0,
      );
}

/// A recorded (or synthetic) flight, plus computed debrief statistics.
class FlightTrack {
  final String id;
  final String name;
  final DateTime date;
  final List<TrackPoint> points;

  const FlightTrack({
    required this.id,
    required this.name,
    required this.date,
    required this.points,
  });

  bool get isSample => id.startsWith('sample_');

  /// Total elapsed time from first to last point.
  Duration get duration {
    if (points.length < 2) return Duration.zero;
    return Duration(seconds: points.last.timestamp - points.first.timestamp);
  }

  /// Ground track distance in nautical miles (haversine, summed leg by leg).
  double get distanceNm {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += _haversineNm(points[i - 1].latLng, points[i].latLng);
    }
    return total;
  }

  double get maxAltitudeFt {
    if (points.isEmpty) return 0;
    return points.map((p) => p.altitudeFt).reduce(math.max);
  }

  double get maxGroundSpeedKt {
    if (points.isEmpty) return 0;
    return points.map((p) => p.groundSpeedKt).reduce(math.max);
  }

  /// Rough final descent rate in feet-per-minute over the last ~30 s of data.
  /// Labeled an ESTIMATE in the UI — this is not certified performance data.
  double get finalDescentRateFpm {
    if (points.length < 2) return 0;
    final last = points.last;
    final windowStart = last.timestamp - 30;
    // Find the earliest point still inside the trailing window.
    TrackPoint ref = points.first;
    for (final p in points) {
      if (p.timestamp >= windowStart) {
        ref = p;
        break;
      }
    }
    final dtSec = last.timestamp - ref.timestamp;
    if (dtSec <= 0) return 0;
    final dAlt = last.altitudeFt - ref.altitudeFt; // negative = descending
    return dAlt / dtSec * 60.0;
  }

  /// Simple qualitative landing grade derived from [finalDescentRateFpm].
  /// ESTIMATE only.
  String get landingGrade {
    final rate = finalDescentRateFpm.abs();
    if (rate < 150) return 'GREASER';
    if (rate < 350) return 'NORMAL';
    if (rate < 600) return 'FIRM';
    return 'HARD';
  }

  static double _haversineNm(LatLng a, LatLng b) {
    const earthRadiusNm = 3440.065;
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final lat1 = _rad(a.latitude);
    final lat2 = _rad(b.latitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return 2 * earthRadiusNm * math.asin(math.min(1.0, math.sqrt(h)));
  }

  static double _rad(double deg) => deg * math.pi / 180.0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'date': date.toIso8601String(),
        'points': points.map((p) => p.toJson()).toList(),
      };

  factory FlightTrack.fromJson(Map<String, dynamic> j) => FlightTrack(
        id: j['id'] as String? ?? 'track_${DateTime.now().millisecondsSinceEpoch}',
        name: j['name'] as String? ?? 'Flight',
        date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
        points: (j['points'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(TrackPoint.fromJson)
            .toList(),
      );
}

/// Manages recorded flight tracks for the Flight Debrief / track replay feature.
///
/// Persists user-recorded tracks to shared_preferences (JSON, key
/// [_storageKey]) and always exposes 1-2 built-in synthetic SAMPLE tracks so
/// the debrief screen is usable before any real flight has been recorded.
///
/// TODO(gps): real recording will consume LocationService position stream once
/// geolocator is wired — [beginRecording]/[recordPosition]/[endRecording] below
/// are stubs that already model the intended shape of that flow.
class FlightDebriefService extends ChangeNotifier {
  static const _storageKey = 'debrief_tracks';

  final List<FlightTrack> _userTracks = [];
  late final List<FlightTrack> _samples = _buildSampleTracks();

  bool _loaded = false;
  bool get isLoaded => _loaded;

  // Recording buffer (stub until GPS is wired — see the class doc above).
  final List<TrackPoint> _recordingBuffer = [];
  bool _recording = false;
  bool get isRecording => _recording;

  /// All tracks shown in the UI: user recordings first, then built-in samples.
  List<FlightTrack> get tracks => [..._userTracks, ..._samples];

  /// Load persisted user tracks. Safe to call multiple times.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      _userTracks.clear();
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              final track = FlightTrack.fromJson(item);
              if (track.points.isNotEmpty) _userTracks.add(track);
            }
          }
        }
      }
    } catch (_) {
      // Corrupt/empty storage should never crash the screen.
      _userTracks.clear();
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(_userTracks.map((t) => t.toJson()).toList());
      await prefs.setString(_storageKey, data);
    } catch (_) {
      // Persistence is best-effort; never crash on write failure.
    }
  }

  FlightTrack? trackById(String id) {
    for (final t in tracks) {
      if (t.id == id) return t;
    }
    return null;
  }

  Future<void> addTrack(FlightTrack track) async {
    _userTracks.insert(0, track);
    notifyListeners();
    await _persist();
  }

  /// Removes a user-recorded track. Sample tracks are read-only and ignored.
  Future<void> deleteTrack(String id) async {
    final before = _userTracks.length;
    _userTracks.removeWhere((t) => t.id == id);
    if (_userTracks.length != before) {
      notifyListeners();
      await _persist();
    }
  }

  // --- Recording stubs (to be driven from the LocationService stream) ------

  void beginRecording() {
    _recording = true;
    _recordingBuffer.clear();
    notifyListeners();
  }

  /// Models the per-fix append that the LocationService position stream will
  /// drive once GPS is wired (see the class doc).
  void recordPosition(TrackPoint point) {
    if (!_recording) return;
    _recordingBuffer.add(point);
  }

  Future<FlightTrack?> endRecording({String? name}) async {
    _recording = false;
    if (_recordingBuffer.isEmpty) {
      notifyListeners();
      return null;
    }
    final track = FlightTrack(
      id: 'track_${DateTime.now().millisecondsSinceEpoch}',
      name: name ?? 'Recorded Flight',
      date: DateTime.now(),
      points: List<TrackPoint>.from(_recordingBuffer),
    );
    _recordingBuffer.clear();
    await addTrack(track);
    return track;
  }

  // --- Synthetic sample tracks ---------------------------------------------

  List<FlightTrack> _buildSampleTracks() {
    return [
      _buildPatternSample(),
      _buildBayTourSample(),
    ];
  }

  /// A short synthetic closed traffic pattern at Palo Alto (KPAO), Rwy 31.
  FlightTrack _buildPatternSample() {
    // KPAO field: 37.4611 N, 122.1150 W, elevation ~5 ft.
    final gen = _TrackBuilder(startLat: 37.4611, startLon: -122.1150, startAltFt: 5);
    // Takeoff & upwind climb on runway heading 313.
    gen.leg(headingDeg: 313, groundSpeedKt: 70, targetAltFt: 500, seconds: 40);
    // Crosswind, climbing to pattern altitude.
    gen.leg(headingDeg: 43, groundSpeedKt: 80, targetAltFt: 800, seconds: 25);
    // Downwind, level at 800 ft.
    gen.leg(headingDeg: 133, groundSpeedKt: 90, targetAltFt: 800, seconds: 45);
    // Base, beginning descent.
    gen.leg(headingDeg: 223, groundSpeedKt: 80, targetAltFt: 500, seconds: 25);
    // Final approach, descending to the numbers.
    gen.leg(headingDeg: 313, groundSpeedKt: 65, targetAltFt: 20, seconds: 40);
    // Touchdown & rollout.
    gen.leg(headingDeg: 313, groundSpeedKt: 15, targetAltFt: 5, seconds: 15);
    return FlightTrack(
      id: 'sample_pattern_kpao',
      name: 'KPAO Pattern Work',
      date: DateTime.now().subtract(const Duration(days: 3)),
      points: gen.points,
    );
  }

  /// A short synthetic bay sightseeing hop out of KPAO.
  FlightTrack _buildBayTourSample() {
    final gen = _TrackBuilder(startLat: 37.4611, startLon: -122.1150, startAltFt: 5);
    gen.leg(headingDeg: 313, groundSpeedKt: 75, targetAltFt: 1500, seconds: 60);
    gen.leg(headingDeg: 20, groundSpeedKt: 110, targetAltFt: 3500, seconds: 120);
    gen.leg(headingDeg: 90, groundSpeedKt: 120, targetAltFt: 3500, seconds: 90);
    gen.leg(headingDeg: 160, groundSpeedKt: 115, targetAltFt: 2500, seconds: 120);
    gen.leg(headingDeg: 240, groundSpeedKt: 100, targetAltFt: 1200, seconds: 90);
    gen.leg(headingDeg: 313, groundSpeedKt: 70, targetAltFt: 20, seconds: 60);
    gen.leg(headingDeg: 313, groundSpeedKt: 15, targetAltFt: 5, seconds: 15);
    return FlightTrack(
      id: 'sample_bay_tour',
      name: 'Bay Tour Hop',
      date: DateTime.now().subtract(const Duration(days: 10)),
      points: gen.points,
    );
  }
}

/// Helper that simulates simple constant-heading legs, integrating position
/// from ground speed so sample tracks look like real GPS breadcrumbs.
class _TrackBuilder {
  double _lat;
  double _lon;
  double _alt;
  int _t = 0;
  final List<TrackPoint> points = [];

  _TrackBuilder({
    required double startLat,
    required double startLon,
    required double startAltFt,
  })  : _lat = startLat,
        _lon = startLon,
        _alt = startAltFt {
    points.add(TrackPoint(
      lat: _lat,
      lon: _lon,
      altitudeFt: _alt,
      groundSpeedKt: 0,
      headingDeg: 0,
      timestamp: 0,
    ));
  }

  void leg({
    required double headingDeg,
    required double groundSpeedKt,
    required double targetAltFt,
    required int seconds,
    int stepSeconds = 2,
  }) {
    if (seconds <= 0) return;
    final startAlt = _alt;
    final hr = headingDeg * math.pi / 180.0;
    // Ground speed in knots -> degrees of latitude per second.
    final degLatPerSec = groundSpeedKt / 3600.0 / 60.0;
    for (var s = stepSeconds; s <= seconds; s += stepSeconds) {
      final frac = s / seconds;
      _alt = startAlt + (targetAltFt - startAlt) * frac;
      final dLat = math.cos(hr) * degLatPerSec * stepSeconds;
      final cosLat = math.cos(_lat * math.pi / 180.0);
      final dLon = math.sin(hr) * degLatPerSec * stepSeconds / (cosLat.abs() < 1e-6 ? 1e-6 : cosLat);
      _lat += dLat;
      _lon += dLon;
      _t += stepSeconds;
      points.add(TrackPoint(
        lat: _lat,
        lon: _lon,
        altitudeFt: _alt,
        groundSpeedKt: groundSpeedKt,
        headingDeg: headingDeg,
        timestamp: _t,
      ));
    }
  }
}
