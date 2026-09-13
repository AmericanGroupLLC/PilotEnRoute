import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Own-ship location provider.
///
/// NOTE: Real device GPS requires the `geolocator` package, which is not yet a
/// dependency of this project. This service is intentionally a thin, stable
/// interface so a real GPS backend can be dropped in without touching any UI.
///
/// TODO(gps): add `geolocator` (and iOS/Android location permissions) then
/// implement [startTracking] using `Geolocator.getPositionStream(...)`, updating
/// [current], [headingDeg], [groundSpeedKt] and calling [notifyListeners].
/// `permission_handler` (already a dependency) can request Location permission.
class LocationService extends ChangeNotifier {
  LatLng? _current;
  double? _headingDeg;
  double? _groundSpeedKt;
  double? _altitudeFt;
  bool _tracking = false;
  bool _available = false; // becomes true once a real GPS backend is wired

  /// Last known own-ship position, or null if GPS is unavailable/not started.
  LatLng? get current => _current;
  double? get headingDeg => _headingDeg;
  double? get groundSpeedKt => _groundSpeedKt;
  double? get altitudeFt => _altitudeFt;
  bool get isTracking => _tracking;

  /// Whether a real location backend is available. False until `geolocator`
  /// is wired in — the UI uses this to show a clear "GPS not configured" state
  /// instead of pretending to have a fix.
  bool get isAvailable => _available;

  /// Sensible default map center when no GPS fix exists (San Francisco Bay).
  static const LatLng fallbackCenter = LatLng(37.7749, -122.4194);

  /// Begin location updates. No-op stub today; see the library note above.
  Future<void> startTracking() async {
    _tracking = false; // flips to true once a real backend delivers fixes
    notifyListeners();
  }

  Future<void> stopTracking() async {
    _tracking = false;
    notifyListeners();
  }

  /// Test/manual hook so other features (e.g. flight-debrief replay) can push a
  /// simulated position into the same interface the real GPS backend will use.
  void updatePosition({
    required LatLng position,
    double? heading,
    double? groundSpeedKt,
    double? altitudeFt,
  }) {
    _current = position;
    _headingDeg = heading ?? _headingDeg;
    _groundSpeedKt = groundSpeedKt ?? _groundSpeedKt;
    _altitudeFt = altitudeFt ?? _altitudeFt;
    _tracking = true;
    _available = true;
    notifyListeners();
  }
}
