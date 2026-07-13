import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../services/flight_debrief_service.dart';

// Shared palette.
const _kBg = Color(0xFF0A1628);
const _kCard = Color(0xFF112240);
const _kCyan = Color(0xFF00BCD4);
const _kAmber = Color(0xFFFFB300);
const _kRed = Color(0xFFF44336);
const _kGreen = Color(0xFF4CAF50);

/// Flight Debrief — list of recorded/sample tracks; tapping one opens a
/// CloudAhoy-lite replay view with a moving-map, timeline scrub and profiles.
class DebriefScreen extends StatefulWidget {
  const DebriefScreen({super.key});

  @override
  State<DebriefScreen> createState() => _DebriefScreenState();
}

class _DebriefScreenState extends State<DebriefScreen> {
  // Screen owns the service instance so no provider registration is required.
  final FlightDebriefService _service = FlightDebriefService();

  @override
  void initState() {
    super.initState();
    _service.load();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(title: const Text('FLIGHT DEBRIEF')),
      body: AnimatedBuilder(
        animation: _service,
        builder: (context, _) {
          final tracks = _service.tracks;
          if (!_service.isLoaded) {
            return const Center(
              child: CircularProgressIndicator(color: _kCyan),
            );
          }
          if (tracks.isEmpty) {
            return _buildEmpty();
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: tracks.length,
            itemBuilder: (context, i) => _buildTrackCard(tracks[i]),
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.route, color: Colors.white24, size: 56),
            const SizedBox(height: 16),
            Text(
              'No flights recorded yet.',
              style: GoogleFonts.orbitron(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Recorded tracks will appear here for replay and debrief.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackCard(FlightTrack track) {
    final df = DateFormat('MMM d, yyyy');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openReplay(track),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _kCyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.timeline, color: _kCyan, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.name,
                            style: GoogleFonts.orbitron(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            df.format(track.date),
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                    if (track.isSample)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _kAmber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'SAMPLE',
                          style: GoogleFonts.orbitron(
                            fontSize: 8,
                            color: _kAmber,
                            letterSpacing: 1,
                          ),
                        ),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 20),
                        onPressed: () => _confirmDelete(track),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _stat('DURATION', _fmtDuration(track.duration)),
                    _stat('DISTANCE', '${track.distanceNm.toStringAsFixed(1)} NM'),
                    _stat('MAX ALT', '${track.maxAltitudeFt.round()} ft'),
                    _stat('MAX GS', '${track.maxGroundSpeedKt.round()} kt'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.orbitron(fontSize: 8, color: Colors.white38, letterSpacing: 1),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.orbitron(fontSize: 12, color: _kCyan, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _openReplay(FlightTrack track) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _ReplayView(track: track)),
    );
  }

  Future<void> _confirmDelete(FlightTrack track) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        title: Text('Delete flight?',
            style: GoogleFonts.orbitron(color: Colors.white, fontSize: 15)),
        content: Text(track.name,
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('CANCEL', style: GoogleFonts.orbitron(color: Colors.white54, fontSize: 11)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('DELETE', style: GoogleFonts.orbitron(color: _kRed, fontSize: 11)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _service.deleteTrack(track.id);
    }
  }
}

String _fmtDuration(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '${m}m ${s.toString().padLeft(2, '0')}s';
}

/// Track replay view: moving-map, play/pause/scrub timeline, altitude & GS
/// profiles, live readouts and an ESTIMATE landing/maneuver summary.
class _ReplayView extends StatefulWidget {
  final FlightTrack track;
  const _ReplayView({required this.track});

  @override
  State<_ReplayView> createState() => _ReplayViewState();
}

class _ReplayViewState extends State<_ReplayView> {
  final MapController _map = MapController();
  Timer? _timer;

  int _index = 0;
  bool _playing = false;
  int _speed = 1; // 1x / 2x / 4x / 8x

  List<TrackPoint> get _points => widget.track.points;

  @override
  void dispose() {
    _timer?.cancel();
    _map.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_points.length < 2) return;
    if (_playing) {
      _pause();
    } else {
      // Restart from the beginning if parked at the end.
      if (_index >= _points.length - 1) _index = 0;
      _play();
    }
  }

  void _play() {
    _timer?.cancel();
    setState(() => _playing = true);
    final interval = Duration(milliseconds: (400 / _speed).round().clamp(30, 400));
    _timer = Timer.periodic(interval, (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_index >= _points.length - 1) {
        _pause();
        return;
      }
      setState(() => _index++);
      _followCamera();
    });
  }

  void _pause() {
    _timer?.cancel();
    _timer = null;
    if (mounted) setState(() => _playing = false);
  }

  void _setSpeed(int s) {
    setState(() => _speed = s);
    if (_playing) _play(); // reschedule at new cadence
  }

  void _scrubTo(double v) {
    _pause();
    setState(() => _index = v.round().clamp(0, _points.length - 1));
    _followCamera();
  }

  void _followCamera() {
    if (_points.isEmpty) return;
    final p = _points[_index.clamp(0, _points.length - 1)];
    try {
      _map.move(p.latLng, _map.camera.zoom);
    } catch (_) {
      // MapController not ready yet — ignore.
    }
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(title: const Text('FLIGHT DEBRIEF')),
      body: _points.isEmpty
          ? _buildNoData()
          : SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        track.name,
                        style: GoogleFonts.orbitron(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _buildMap(),
                    _buildReadouts(),
                    _buildTimeline(),
                    _buildProfileCard(
                      title: 'ALTITUDE PROFILE',
                      unit: 'ft',
                      color: _kCyan,
                      valueOf: (p) => p.altitudeFt,
                    ),
                    _buildProfileCard(
                      title: 'GROUND SPEED PROFILE',
                      unit: 'kt',
                      color: _kAmber,
                      valueOf: (p) => p.groundSpeedKt,
                    ),
                    _buildLandingAnalysis(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildNoData() {
    return Center(
      child: Text(
        'This track has no data to replay.',
        style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
      ),
    );
  }

  Widget _buildMap() {
    final current = _points[_index.clamp(0, _points.length - 1)];
    return SizedBox(
      height: 300,
      child: FlutterMap(
        mapController: _map,
        options: MapOptions(
          initialCenter: current.latLng,
          initialZoom: 12,
          minZoom: 3,
          maxZoom: 16,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.pilotenroute.app',
            maxZoom: 16,
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: _points.map((p) => p.latLng).toList(),
                color: _kCyan.withValues(alpha: 0.85),
                strokeWidth: 3,
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              // Start marker.
              Marker(
                point: _points.first.latLng,
                width: 16,
                height: 16,
                child: const Icon(Icons.circle, color: _kGreen, size: 12),
              ),
              // Current aircraft position.
              Marker(
                point: current.latLng,
                width: 36,
                height: 36,
                child: Transform.rotate(
                  angle: current.headingDeg * math.pi / 180.0,
                  child: const Icon(Icons.navigation, color: Color(0xFF00E5FF), size: 30),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReadouts() {
    final p = _points[_index.clamp(0, _points.length - 1)];
    final elapsed = Duration(seconds: p.timestamp - _points.first.timestamp);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          _readout('ALT', '${p.altitudeFt.round()}', 'ft', _kCyan),
          _readout('GS', '${p.groundSpeedKt.round()}', 'kt', _kAmber),
          _readout('HDG', p.headingDeg.round().toString().padLeft(3, '0'), '°', Colors.white),
          _readout('ELAPSED', _fmtDuration(elapsed), '', _kGreen),
        ],
      ),
    );
  }

  Widget _readout(String label, String value, String unit, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          children: [
            Text(label,
                style: GoogleFonts.orbitron(fontSize: 8, color: Colors.white38, letterSpacing: 1)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: RichText(
                text: TextSpan(
                  text: value,
                  style: GoogleFonts.orbitron(
                    fontSize: 15,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                  children: [
                    if (unit.isNotEmpty)
                      TextSpan(
                        text: ' $unit',
                        style: GoogleFonts.inter(fontSize: 9, color: Colors.white38),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline() {
    final maxIndex = (_points.length - 1).toDouble();
    final value = _index.toDouble().clamp(0.0, maxIndex);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _kCyan,
              inactiveTrackColor: Colors.white12,
              thumbColor: _kCyan,
              overlayColor: _kCyan.withValues(alpha: 0.2),
              trackHeight: 3,
            ),
            child: Slider(
              value: value,
              min: 0,
              max: maxIndex <= 0 ? 1 : maxIndex,
              onChanged: maxIndex <= 0 ? null : _scrubTo,
            ),
          ),
          Row(
            children: [
              IconButton(
                iconSize: 40,
                icon: Icon(
                  _playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                  color: _kCyan,
                ),
                onPressed: _points.length < 2 ? null : _togglePlay,
              ),
              const Spacer(),
              for (final s in const [1, 2, 4, 8]) _speedChip(s),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
    );
  }

  Widget _speedChip(int s) {
    final active = _speed == s;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: GestureDetector(
        onTap: () => _setSpeed(s),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active ? _kCyan : _kCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? _kCyan : Colors.white12),
          ),
          child: Text(
            '${s}x',
            style: GoogleFonts.orbitron(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: active ? Colors.black : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard({
    required String title,
    required String unit,
    required Color color,
    required double Function(TrackPoint) valueOf,
  }) {
    final first = _points.first.timestamp.toDouble();
    final spots = _points
        .map((p) => FlSpot((p.timestamp - first), valueOf(p)))
        .toList();
    final maxX = spots.isEmpty ? 1.0 : spots.last.x;
    final currentX = (_points[_index.clamp(0, _points.length - 1)].timestamp - first).toDouble();

    double maxY = 1;
    for (final s in spots) {
      if (s.y > maxY) maxY = s.y;
    }
    final niceMaxY = (maxY * 1.15);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      padding: const EdgeInsets.fromLTRB(12, 14, 16, 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.orbitron(fontSize: 10, color: color, letterSpacing: 1),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 130,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: maxX <= 0 ? 1 : maxX,
                minY: 0,
                maxY: niceMaxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) =>
                      const FlLine(color: Colors.white10, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: (maxX <= 0 ? 1 : maxX) / 4,
                      getTitlesWidget: (v, meta) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${(v / 60).toStringAsFixed(0)}m',
                          style: GoogleFonts.inter(color: Colors.white38, fontSize: 8),
                        ),
                      ),
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      interval: niceMaxY / 2,
                      getTitlesWidget: (v, meta) => Text(
                        v.round().toString(),
                        style: GoogleFonts.inter(color: Colors.white38, fontSize: 8),
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    color: color,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: color.withValues(alpha: 0.12),
                    ),
                  ),
                ],
                extraLinesData: ExtraLinesData(
                  verticalLines: [
                    VerticalLine(
                      x: currentX,
                      color: Colors.white70,
                      strokeWidth: 1.5,
                      dashArray: const [4, 3],
                    ),
                  ],
                ),
                lineTouchData: const LineTouchData(enabled: false),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'unit: $unit',
            style: GoogleFonts.inter(fontSize: 8, color: Colors.white24),
          ),
        ],
      ),
    );
  }

  Widget _buildLandingAnalysis() {
    final track = widget.track;
    final rate = track.finalDescentRateFpm;
    final grade = track.landingGrade;
    Color gradeColor;
    switch (grade) {
      case 'GREASER':
        gradeColor = _kGreen;
        break;
      case 'NORMAL':
        gradeColor = _kCyan;
        break;
      case 'FIRM':
        gradeColor = _kAmber;
        break;
      default:
        gradeColor = _kRed;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flight_land, color: _kAmber, size: 18),
              const SizedBox(width: 8),
              Text(
                'LANDING ANALYSIS',
                style: GoogleFonts.orbitron(fontSize: 11, color: _kAmber, letterSpacing: 1),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'ESTIMATE',
                  style: GoogleFonts.orbitron(fontSize: 8, color: Colors.white54, letterSpacing: 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TOUCHDOWN GRADE',
                      style: GoogleFonts.orbitron(fontSize: 8, color: Colors.white38, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(
                    grade,
                    style: GoogleFonts.orbitron(
                      fontSize: 20,
                      color: gradeColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('FINAL DESCENT',
                      style: GoogleFonts.orbitron(fontSize: 8, color: Colors.white38, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(
                    '${rate.round()} fpm',
                    style: GoogleFonts.orbitron(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),
          Text('MANEUVER SUMMARY',
              style: GoogleFonts.orbitron(fontSize: 8, color: Colors.white38, letterSpacing: 1)),
          const SizedBox(height: 6),
          Text(
            _maneuverSummary(track),
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, height: 1.5),
          ),
        ],
      ),
    );
  }

  String _maneuverSummary(FlightTrack track) {
    final pts = track.points;
    if (pts.length < 2) return 'Not enough data for a maneuver summary.';
    var climbSec = 0;
    var descentSec = 0;
    var cruiseSec = 0;
    for (var i = 1; i < pts.length; i++) {
      final dt = pts[i].timestamp - pts[i - 1].timestamp;
      if (dt <= 0) continue;
      final dAlt = pts[i].altitudeFt - pts[i - 1].altitudeFt;
      final fpm = dAlt / dt * 60.0;
      if (fpm > 150) {
        climbSec += dt;
      } else if (fpm < -150) {
        descentSec += dt;
      } else {
        cruiseSec += dt;
      }
    }
    String m(int s) => '${(s / 60).toStringAsFixed(1)} min';
    return 'Climb ${m(climbSec)}  •  Cruise/level ${m(cruiseSec)}  •  '
        'Descent ${m(descentSec)}. Peak altitude ${track.maxAltitudeFt.round()} ft, '
        'peak ground speed ${track.maxGroundSpeedKt.round()} kt. (ESTIMATE — derived from GPS track only.)';
  }
}
