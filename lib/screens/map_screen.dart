import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../services/aviation_api_service.dart';
import '../services/flight_plan_service.dart';
import '../services/flight_tracker_service.dart';
import '../services/location_service.dart';

/// Aviation map (charts, airspace, traffic) built on flutter_map. It is not a
/// moving map: the app has no GPS backend, so there is no own-ship position.
///
/// Fully functional today: base map (standard/terrain), live ADS-B traffic
/// overlay (OpenSky), airport search + marker, range rings, and a tap-to-measure
/// distance/bearing tool. Own-ship GPS position is wired through
/// [LocationService] — see that file for what a real GPS fix would need.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

enum _BaseLayer { standard, terrain, satellite, sectional, ifrLow }

/// First chart cycle whose VFRMap tile directory this app was built against.
/// Every later cycle is this date plus a whole number of [kChartCycleDays].
final DateTime kChartCycleAnchor = DateTime.utc(2025, 1, 16);

/// FAA aeronautical charts are re-issued on a 28-day, AIRAC-style cycle.
const int kChartCycleDays = 28;

/// The VFRMap tile-set date (`YYYYMMDD`) that is current at [now].
///
/// VFRMap keys its free chart tiles by the FAA chart cycle date, so a
/// hard-coded value silently rots into 404s the moment the cycle turns over.
/// Rolling the anchor forward in whole cycles keeps a shipped build pointed at
/// the current charts for as long as the tile host keeps publishing them.
/// Dates before the anchor clamp to the anchor rather than going negative.
String vfrmapCycleFor(DateTime now) {
  final days = now.toUtc().difference(kChartCycleAnchor).inDays;
  final cycles = days <= 0 ? 0 : days ~/ kChartCycleDays;
  final date = kChartCycleAnchor.add(Duration(days: cycles * kChartCycleDays));
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '${date.year}$m$d';
}

class _MapScreenState extends State<MapScreen> {
  final MapController _map = MapController();
  final LocationService _location = LocationService();

  _BaseLayer _base = _BaseLayer.standard;
  bool _showTraffic = true;
  bool _showRings = true;
  bool _measuring = false;

  LatLng _center = LocationService.fallbackCenter;
  double _zoom = 8;

  // Airport search result marker.
  LatLng? _airportPoint;
  String? _airportLabel;

  // Tap-to-measure endpoints.
  LatLng? _measureFrom;
  LatLng? _measureTo;

  // Loaded flight plan route + nav log.
  List<Waypoint> _routePoints = [];
  List<NavLogLeg> _navLog = [];
  String? _routeName;
  bool _loadingRoute = false;
  bool _showNavLog = true;

  // Weather radar overlay (RainViewer — free, no API key).
  bool _showRadar = false;
  String? _radarUrlTemplate;

  final _searchCtrl = TextEditingController();
  final Distance _distance = const Distance();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshTraffic());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _refreshTraffic() async {
    if (!mounted) return;
    final tracker = context.read<FlightTrackerService>();
    await tracker.fetchNearbyFlights(
      lat: _center.latitude,
      lon: _center.longitude,
      radius: 2.5,
    );
  }

  Future<void> _searchAirport() async {
    final code = _searchCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    FocusScope.of(context).unfocus();
    final api = context.read<AviationApiService>();
    final airport = await api.fetchAirport(code);
    if (!mounted) return;
    if (airport != null && (airport.lat != 0 || airport.lon != 0)) {
      final p = LatLng(airport.lat, airport.lon);
      setState(() {
        _airportPoint = p;
        _airportLabel = airport.icao.isNotEmpty ? airport.icao : code;
        _center = p;
        _zoom = 11;
      });
      _map.move(p, _zoom);
      _refreshTraffic();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Airport "$code" not found')),
      );
    }
  }

  Future<void> _pickPlan() async {
    final service = context.read<FlightPlanService>();
    await service.loadPlans();
    if (!mounted) return;
    final plans = service.plans;
    if (plans.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No saved flight plans yet')),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF112240),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text('LOAD FLIGHT PLAN',
                  style: GoogleFonts.orbitron(
                      color: Colors.white, fontSize: 12, letterSpacing: 1)),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final p in plans)
                    ListTile(
                      leading:
                          const Icon(Icons.route, color: Color(0xFF00BCD4)),
                      title: Text('${p.departure} → ${p.destination}',
                          style: GoogleFonts.inter(color: Colors.white)),
                      subtitle: Text(p.name,
                          style: GoogleFonts.inter(
                              color: Colors.white54, fontSize: 12)),
                      onTap: () {
                        Navigator.pop(ctx);
                        _loadPlan(p);
                      },
                    ),
                  if (_routePoints.isNotEmpty)
                    ListTile(
                      leading:
                          const Icon(Icons.clear, color: Color(0xFFF44336)),
                      title: Text('Clear route',
                          style: GoogleFonts.inter(color: Colors.white)),
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _routePoints = [];
                          _navLog = [];
                          _routeName = null;
                        });
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadPlan(FlightPlan plan) async {
    setState(() => _loadingRoute = true);
    final api = context.read<AviationApiService>();
    final planService = context.read<FlightPlanService>();

    // Resolve an ordered list of points: departure, any waypoints with coords,
    // then destination. Airport identifiers are resolved via the airport API;
    // waypoints that already carry coordinates are used directly.
    final resolved = <Waypoint>[];

    Future<void> addAirport(String code) async {
      if (code.trim().isEmpty) return;
      final info = await api.fetchAirport(code.trim());
      if (info != null && (info.lat != 0 || info.lon != 0)) {
        resolved.add(Waypoint(
          identifier: info.icao.isNotEmpty ? info.icao : code.trim(),
          name: info.name,
          lat: info.lat,
          lon: info.lon,
          type: 'airport',
        ));
      }
    }

    await addAirport(plan.departure);
    for (final w in plan.waypoints) {
      if (w.lat != 0 || w.lon != 0) resolved.add(w);
    }
    await addAirport(plan.destination);

    if (!mounted) return;
    if (resolved.length < 2) {
      setState(() => _loadingRoute = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not resolve route airports for the map')),
      );
      return;
    }

    final navLog = planService.computeNavLog(
      resolved,
      groundSpeedKts: plan.cruiseSpeed,
    );
    final bounds = LatLngBounds.fromPoints(
        resolved.map((w) => LatLng(w.lat, w.lon)).toList());
    setState(() {
      _routePoints = resolved;
      _navLog = navLog;
      _routeName = '${plan.departure} → ${plan.destination}';
      _loadingRoute = false;
      _showNavLog = true;
    });
    _map.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)));
  }

  Future<void> _toggleRadar() async {
    if (_showRadar) {
      setState(() => _showRadar = false);
      return;
    }
    // RainViewer publishes a free index of the latest radar tile paths.
    try {
      final resp = await http
          .get(Uri.parse('https://api.rainviewer.com/public/weather-maps.json'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final host = data['host'] as String? ?? 'https://tilecache.rainviewer.com';
        final radar = data['radar'] as Map<String, dynamic>?;
        final past = radar?['past'] as List?;
        final path = (past != null && past.isNotEmpty)
            ? (past.last as Map<String, dynamic>)['path'] as String?
            : null;
        if (path != null && mounted) {
          setState(() {
            _radarUrlTemplate =
                '$host$path/256/{z}/{x}/{y}/2/1_1.png';
            _showRadar = true;
          });
          return;
        }
      }
    } catch (_) {
      // fall through to the error message below
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Radar unavailable right now')),
      );
    }
  }

  void _onMapTap(TapPosition _, LatLng point) {
    if (!_measuring) return;
    setState(() {
      if (_measureFrom == null || _measureTo != null) {
        _measureFrom = point;
        _measureTo = null;
      } else {
        _measureTo = point;
      }
    });
  }

  double _bearing(LatLng a, LatLng b) {
    final lat1 = a.latitudeInRad;
    final lat2 = b.latitudeInRad;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        title: const Text('AVIATION MAP'),
        actions: [
          IconButton(
            tooltip: 'Load flight plan',
            icon: const Icon(Icons.route),
            onPressed: _pickPlan,
          ),
          IconButton(
            tooltip: 'Refresh traffic',
            icon: const Icon(Icons.refresh),
            onPressed: _refreshTraffic,
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildMap(),
          _buildSearchBar(),
          _buildLayerControls(),
          if (_measuring) _buildMeasureReadout(),
          if (_navLog.isNotEmpty) _buildNavLogPanel(),
          _buildGpsBanner(),
          if (_showTraffic) _buildTrafficBanner(),
          if (_loadingRoute)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black38,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00BCD4),
        foregroundColor: Colors.black,
        onPressed: () {
          // Recenter on own-ship if available, else on current center.
          final target = _location.current ?? _center;
          _map.move(target, _zoom);
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }

  Widget _buildMap() {
    return Consumer<FlightTrackerService>(
      builder: (context, tracker, _) {
        return FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: _center,
            initialZoom: _zoom,
            minZoom: 3,
            maxZoom: 16,
            onTap: _onMapTap,
            onPositionChanged: (position, _) {
              if (position.center != null) _center = position.center!;
              if (position.zoom != null) _zoom = position.zoom!;
            },
          ),
          children: [
            _buildBaseTileLayer(),
            if (_showRadar && _radarUrlTemplate != null)
              Opacity(
                opacity: 0.55,
                child: TileLayer(
                  urlTemplate: _radarUrlTemplate!,
                  userAgentPackageName: 'com.pilotenroute.app',
                  tileProvider: NetworkTileProvider(),
                ),
              ),
            if (_routePoints.length >= 2)
              PolylineLayer(polylines: [
                Polyline(
                  points:
                      _routePoints.map((w) => LatLng(w.lat, w.lon)).toList(),
                  color: const Color(0xFF00BCD4),
                  strokeWidth: 3,
                ),
              ]),
            if (_showRings) _buildRings(),
            if (_measureFrom != null && _measureTo != null)
              PolylineLayer(polylines: [
                Polyline(
                  points: [_measureFrom!, _measureTo!],
                  color: const Color(0xFFFFB300),
                  strokeWidth: 3,
                ),
              ]),
            if (_showTraffic) _buildTraffic(tracker),
            _buildMarkers(),
          ],
        );
      },
    );
  }

  /// Returns the base map tile layer for the currently selected [_base].
  ///
  /// VFRMap sectional/IFR tiles use TMS addressing and only publish up to
  /// ~zoom 11; any tile that 404s simply renders blank (no crash).
  TileLayer _buildBaseTileLayer() {
    switch (_base) {
      case _BaseLayer.standard:
        return TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.pilotenroute.app',
          maxZoom: 16,
        );
      case _BaseLayer.terrain:
        return TileLayer(
          urlTemplate: 'https://tile.opentopomap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.pilotenroute.app',
          maxZoom: 16,
        );
      case _BaseLayer.satellite:
        return TileLayer(
          urlTemplate:
              'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
          userAgentPackageName: 'com.pilotenroute.app',
          maxZoom: 16,
        );
      case _BaseLayer.sectional:
        return TileLayer(
          urlTemplate:
              'https://vfrmap.com/${vfrmapCycleFor(DateTime.now())}'
              '/tiles/vfrc/{z}/{y}/{x}.jpg',
          userAgentPackageName: 'com.pilotenroute.app',
          tms: true,
          maxNativeZoom: 11,
        );
      case _BaseLayer.ifrLow:
        return TileLayer(
          urlTemplate:
              'https://vfrmap.com/${vfrmapCycleFor(DateTime.now())}'
              '/tiles/ifrlc/{z}/{y}/{x}.jpg',
          userAgentPackageName: 'com.pilotenroute.app',
          tms: true,
          maxNativeZoom: 11,
        );
    }
  }

  String _baseLayerName(_BaseLayer layer) {
    switch (layer) {
      case _BaseLayer.standard:
        return 'Standard (OSM)';
      case _BaseLayer.terrain:
        return 'Terrain (OpenTopo)';
      case _BaseLayer.satellite:
        return 'Satellite (Esri)';
      case _BaseLayer.sectional:
        return 'VFR Sectional';
      case _BaseLayer.ifrLow:
        return 'IFR Low';
    }
  }

  IconData _baseLayerIcon(_BaseLayer layer) {
    switch (layer) {
      case _BaseLayer.standard:
        return Icons.map;
      case _BaseLayer.terrain:
        return Icons.terrain;
      case _BaseLayer.satellite:
        return Icons.satellite_alt;
      case _BaseLayer.sectional:
        return Icons.map_outlined;
      case _BaseLayer.ifrLow:
        return Icons.alt_route;
    }
  }

  void _showLayerPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF112240),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text('BASE LAYER',
                  style: GoogleFonts.orbitron(
                      color: Colors.white, fontSize: 12, letterSpacing: 1)),
            ),
            for (final layer in _BaseLayer.values)
              ListTile(
                leading: Icon(_baseLayerIcon(layer),
                    color: layer == _base
                        ? const Color(0xFF00BCD4)
                        : Colors.white70),
                title: Text(
                  _baseLayerName(layer),
                  style: GoogleFonts.inter(
                    color:
                        layer == _base ? const Color(0xFF00BCD4) : Colors.white,
                    fontWeight:
                        layer == _base ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: layer == _base
                    ? const Icon(Icons.check, color: Color(0xFF00BCD4))
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _base = layer);
                },
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Text(
                'Sectional & IFR Low are free demo tiles (VFRMap).',
                style: GoogleFonts.inter(
                    color: const Color(0xFFFFB300), fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  CircleLayer _buildRings() {
    const nm = 1852.0; // metres per nautical mile
    final origin = _location.current ?? _center;
    return CircleLayer(
      circles: [
        for (final r in const [5.0, 10.0, 25.0])
          CircleMarker(
            point: origin,
            radius: r * nm,
            useRadiusInMeter: true,
            color: Colors.transparent,
            borderColor: const Color(0xFF00BCD4).withAlpha(90),
            borderStrokeWidth: 1,
          ),
      ],
    );
  }

  MarkerLayer _buildTraffic(FlightTrackerService tracker) {
    return MarkerLayer(
      markers: [
        for (final f in tracker.nearbyFlights)
          if (f.latitude != null && f.longitude != null)
            Marker(
              point: LatLng(f.latitude!, f.longitude!),
              width: 30,
              height: 30,
              child: Transform.rotate(
                angle: ((f.trueTrack ?? 0) * math.pi / 180),
                child: const Icon(
                  Icons.flight,
                  color: Color(0xFFFFB300),
                  size: 22,
                ),
              ),
            ),
      ],
    );
  }

  MarkerLayer _buildMarkers() {
    return MarkerLayer(
      markers: [
        for (final w in _routePoints)
          Marker(
            point: LatLng(w.lat, w.lon),
            width: 70,
            height: 40,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  w.type == 'airport'
                      ? Icons.flight_takeoff
                      : Icons.circle,
                  color: const Color(0xFF00BCD4),
                  size: w.type == 'airport' ? 22 : 12,
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  color: Colors.black54,
                  child: Text(
                    w.identifier,
                    style: GoogleFonts.orbitron(
                        fontSize: 8, color: const Color(0xFF00BCD4)),
                  ),
                ),
              ],
            ),
          ),
        if (_location.current != null)
          Marker(
            point: _location.current!,
            width: 34,
            height: 34,
            child: Transform.rotate(
              angle: ((_location.headingDeg ?? 0) * math.pi / 180),
              child: const Icon(Icons.navigation,
                  color: Color(0xFF00E5FF), size: 30),
            ),
          ),
        if (_airportPoint != null)
          Marker(
            point: _airportPoint!,
            width: 80,
            height: 46,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on,
                    color: Color(0xFF4CAF50), size: 26),
                if (_airportLabel != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    color: Colors.black54,
                    child: Text(
                      _airportLabel!,
                      style: GoogleFonts.orbitron(
                          fontSize: 8, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        for (final p in [_measureFrom, _measureTo])
          if (p != null)
            Marker(
              point: p,
              width: 16,
              height: 16,
              child: const Icon(Icons.circle,
                  color: Color(0xFFFFB300), size: 12),
            ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Positioned(
      top: 10,
      left: 10,
      right: 60,
      child: Material(
        color: Colors.transparent,
        child: TextField(
          controller: _searchCtrl,
          textCapitalization: TextCapitalization.characters,
          onSubmitted: (_) => _searchAirport(),
          style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search airport (ICAO/IATA)…',
            filled: true,
            fillColor: const Color(0xFF112240).withAlpha(240),
            prefixIcon: const Icon(Icons.search, color: Color(0xFF00BCD4)),
            suffixIcon: IconButton(
              tooltip: 'Forward',
              icon: const Icon(Icons.arrow_forward, color: Color(0xFF00BCD4)),
              onPressed: _searchAirport,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
          ),
        ),
      ),
    );
  }

  Widget _buildLayerControls() {
    return Positioned(
      top: 70,
      right: 10,
      child: Column(
        children: [
          _mapButton(
            icon: _baseLayerIcon(_base),
            active: true,
            tooltip: 'Base layer: ${_baseLayerName(_base)}',
            onTap: _showLayerPicker,
          ),
          const SizedBox(height: 8),
          _mapButton(
            icon: Icons.flight,
            active: _showTraffic,
            tooltip: 'Traffic overlay',
            onTap: () => setState(() => _showTraffic = !_showTraffic),
          ),
          const SizedBox(height: 8),
          _mapButton(
            icon: Icons.radar,
            active: _showRings,
            tooltip: 'Range rings',
            onTap: () => setState(() => _showRings = !_showRings),
          ),
          const SizedBox(height: 8),
          _mapButton(
            icon: Icons.cloud,
            active: _showRadar,
            tooltip: 'Weather radar (RainViewer)',
            onTap: _toggleRadar,
          ),
          const SizedBox(height: 8),
          _mapButton(
            icon: Icons.straighten,
            active: _measuring,
            tooltip: 'Measure distance/bearing',
            onTap: () => setState(() {
              _measuring = !_measuring;
              if (!_measuring) {
                _measureFrom = null;
                _measureTo = null;
              }
            }),
          ),
        ],
      ),
    );
  }

  Widget _mapButton({
    required IconData icon,
    required bool active,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active
            ? const Color(0xFF00BCD4)
            : const Color(0xFF112240).withAlpha(240),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon,
                color: active ? Colors.black : Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildMeasureReadout() {
    String text = 'Tap two points to measure';
    if (_measureFrom != null && _measureTo != null) {
      final metres = _distance(_measureFrom!, _measureTo!);
      final nm = metres / 1852.0;
      final brg = _bearing(_measureFrom!, _measureTo!);
      text =
          '${nm.toStringAsFixed(1)} NM  •  ${brg.toStringAsFixed(0)}° T';
    } else if (_measureFrom != null) {
      text = 'Tap destination point';
    }
    return Positioned(
      bottom: 20,
      left: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF112240).withAlpha(240),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFB300)),
        ),
        child: Text(
          text,
          style: GoogleFonts.orbitron(
              color: const Color(0xFFFFB300),
              fontSize: 12,
              fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildNavLogPanel() {
    final totalDist =
        _navLog.isNotEmpty ? _navLog.last.cumulativeDistanceNm : 0.0;
    final totalTimeHr =
        _navLog.isNotEmpty ? _navLog.last.cumulativeTimeHr : 0.0;
    final totalFuel = _navLog.fold<double>(0, (s, l) => s + l.fuelGal);
    final totalMin = (totalTimeHr * 60).round();

    return Positioned(
      left: 10,
      right: 10,
      bottom: 16,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 260),
        decoration: BoxDecoration(
          color: const Color(0xFF112240).withAlpha(244),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF00BCD4).withAlpha(120)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => setState(() => _showNavLog = !_showNavLog),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                child: Row(
                  children: [
                    const Icon(Icons.route, color: Color(0xFF00BCD4), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _routeName ?? 'NAV LOG',
                        style: GoogleFonts.orbitron(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      '${totalDist.toStringAsFixed(0)} NM · '
                      '${totalMin ~/ 60}h ${totalMin % 60}m · '
                      '${totalFuel.toStringAsFixed(1)} gal',
                      style: GoogleFonts.inter(
                          color: const Color(0xFFFFB300), fontSize: 11),
                    ),
                    Icon(_showNavLog ? Icons.expand_more : Icons.expand_less,
                        color: Colors.white54),
                  ],
                ),
              ),
            ),
            if (_showNavLog)
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  itemCount: _navLog.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white12, height: 12),
                  itemBuilder: (context, i) {
                    final leg = _navLog[i];
                    return Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text('${leg.from} → ${leg.to}',
                              style: GoogleFonts.inter(
                                  color: Colors.white, fontSize: 12)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('${leg.trueCourse.toStringAsFixed(0)}°T',
                              style: GoogleFonts.inter(
                                  color: Colors.white70, fontSize: 12)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('${leg.distanceNm.toStringAsFixed(0)} NM',
                              style: GoogleFonts.inter(
                                  color: Colors.white70, fontSize: 12)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(leg.timeHms,
                              textAlign: TextAlign.end,
                              style: GoogleFonts.inter(
                                  color: const Color(0xFFFFB300), fontSize: 12)),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Shown when live traffic could not be fetched, so an empty traffic
  /// layer is never mistaken for "no traffic nearby".
  Widget _buildTrafficBanner() {
    return Consumer<FlightTrackerService>(
      builder: (context, tracker, _) {
        if (tracker.error == null) return const SizedBox.shrink();
        return Positioned(
          bottom: 56,
          left: 10,
          right: 80,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(180),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFB300)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: Color(0xFFFFB300), size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tracker.error!,
                    style: GoogleFonts.inter(
                        color: const Color(0xFFFFB300), fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGpsBanner() {
    if (_location.isAvailable) return const SizedBox.shrink();
    return Positioned(
      bottom: 20,
      right: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(160),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.gps_off, color: Colors.white54, size: 14),
            const SizedBox(width: 6),
            Text(
              'No GPS position · study map only',
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
