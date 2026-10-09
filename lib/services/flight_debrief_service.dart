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
/// [_storageKey]). Only the user's own recordings are ever shown.
///
/// TODO(gps): real recording will consume LocationService position stream once
/// geolocator is wired — [beginRecording]/[recordPosition]/[endRecording] below
/// are stubs that already model the intended shape of that flow.
class FlightDebriefService extends ChangeNotifier {
  static const _storageKey = 'debrief_tracks';

  final List<FlightTrack> _userTracks = [];

  bool _loaded = false;
  bool get isLoaded => _loaded;

  // Recording buffer (stub until GPS is wired — see the class doc above).
  final List<TrackPoint> _recordingBuffer = [];
  bool _recording = false;
  bool get isRecording => _recording;

  /// All tracks shown in the UI: the user's own recordings only.
  List<FlightTrack> get tracks => List.unmodifiable(_userTracks);

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

  /// Removes a user-recorded track.
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
}
