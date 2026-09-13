import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// E6B flight computer screen.
///
/// Provides a set of real, live-updating aviation calculators:
/// wind triangle, crosswind/headwind components, true airspeed & density
/// altitude, time-speed-distance, fuel planning, and unit conversions.
class E6BScreen extends StatefulWidget {
  const E6BScreen({super.key});

  @override
  State<E6BScreen> createState() => _E6BScreenState();
}

class _E6BScreenState extends State<E6BScreen>
    with SingleTickerProviderStateMixin {
  static const Color _bg = Color(0xFF0A1628);
  static const Color _cyan = Color(0xFF00BCD4);

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('E6B CALCULATOR'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: _cyan,
          labelColor: _cyan,
          unselectedLabelColor: Colors.white54,
          labelStyle: GoogleFonts.orbitron(fontSize: 9, letterSpacing: 1),
          unselectedLabelStyle:
              GoogleFonts.orbitron(fontSize: 9, letterSpacing: 1),
          tabs: const [
            Tab(text: 'WIND'),
            Tab(text: 'X-WIND'),
            Tab(text: 'TAS / DA'),
            Tab(text: 'TIME-SPD-DIST'),
            Tab(text: 'FUEL'),
            Tab(text: 'CONVERT'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _WindTriangleTab(),
          _CrosswindTab(),
          _TasDaTab(),
          _TimeSpeedDistanceTab(),
          _FuelTab(),
          _ConversionTab(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared styling colors / helpers
// ---------------------------------------------------------------------------

const Color _kBg = Color(0xFF0A1628);
const Color _kPanel = Color(0xFF112240);
const Color _kCyan = Color(0xFF00BCD4);
const Color _kAmber = Color(0xFFFFB300);
const Color _kRed = Color(0xFFF44336);

final NumberFormat _num0 = NumberFormat('#,##0');
final NumberFormat _num1 = NumberFormat('#,##0.0');
final NumberFormat _num2 = NumberFormat('#,##0.00');

String _fmt(double? v, NumberFormat f, {String suffix = ''}) {
  if (v == null || v.isNaN || v.isInfinite) return '—';
  return '${f.format(v)}$suffix';
}

double _deg2rad(double d) => d * math.pi / 180.0;
double _rad2deg(double r) => r * 180.0 / math.pi;

/// Normalize a compass value to the 0-360 range.
double _norm360(double d) {
  var v = d % 360.0;
  if (v < 0) v += 360.0;
  return v;
}

/// A labeled numeric input field styled for the app.
class _NumField extends StatelessWidget {
  const _NumField({
    required this.controller,
    required this.label,
    this.suffix,
    this.signed = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? suffix;
  final bool signed;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType:
          TextInputType.numberWithOptions(decimal: true, signed: signed),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
      ],
      style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
      cursorColor: _kCyan,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        suffixStyle: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

/// A panel that groups input fields.
class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kPanel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            container: true,
            header: true,
            child: Text(
              title,
              style: GoogleFonts.orbitron(
                color: _kCyan,
                fontSize: 12,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

/// A single computed-result row shown in a result card.
class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.label,
    required this.value,
    this.color = _kCyan,
    this.big = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$label: ${value == '—' ? 'not available' : value}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              value,
              style: GoogleFonts.orbitron(
                color: color,
                fontSize: big ? 26 : 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A card that displays a list of results prominently.
class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: _kPanel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCyan.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            container: true,
            header: true,
            child: Text(
              title,
              style: GoogleFonts.orbitron(
                color: _kAmber,
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Divider(color: Colors.white12, height: 20),
          ...children,
        ],
      ),
    );
  }
}

/// A scrollable body wrapper with consistent padding/spacing.
class _TabBody extends StatelessWidget {
  const _TabBody({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. Wind Triangle
// ---------------------------------------------------------------------------

class _WindTriangleTab extends StatefulWidget {
  const _WindTriangleTab();

  @override
  State<_WindTriangleTab> createState() => _WindTriangleTabState();
}

class _WindTriangleTabState extends State<_WindTriangleTab> {
  final _course = TextEditingController();
  final _tas = TextEditingController();
  final _windDir = TextEditingController();
  final _windSpd = TextEditingController();

  @override
  void dispose() {
    _course.dispose();
    _tas.dispose();
    _windDir.dispose();
    _windSpd.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = double.tryParse(_course.text);
    final tas = double.tryParse(_tas.text);
    final wd = double.tryParse(_windDir.text);
    final ws = double.tryParse(_windSpd.text);

    double? wca;
    double? heading;
    double? gs;

    if (tc != null && tas != null && tas > 0 && wd != null && ws != null) {
      // Angle between wind (FROM) and the course.
      final rel = _deg2rad(wd - tc);
      final sinArg = (ws * math.sin(rel)) / tas;
      if (sinArg.abs() <= 1.0) {
        final wcaRad = math.asin(sinArg);
        wca = _rad2deg(wcaRad);
        heading = _norm360(tc + wca);
        gs = tas * math.cos(wcaRad) - ws * math.cos(rel);
        if (gs < 0) gs = 0; // wind exceeds TAS along track
      }
    }

    String wcaLabel = '—';
    if (wca != null) {
      final dir = wca >= 0 ? 'R' : 'L';
      wcaLabel = '${_num1.format(wca.abs())}° $dir';
    }

    return _TabBody(
      children: [
        _Panel(
          title: 'WIND TRIANGLE',
          children: [
            _NumField(
              controller: _course,
              label: 'True Course',
              suffix: '°',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            _NumField(
              controller: _tas,
              label: 'True Airspeed',
              suffix: 'kt',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            _NumField(
              controller: _windDir,
              label: 'Wind Direction (from)',
              suffix: '°',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            _NumField(
              controller: _windSpd,
              label: 'Wind Speed',
              suffix: 'kt',
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
        _ResultCard(
          title: 'SOLUTION',
          children: [
            _ResultTile(
              label: 'Heading (true)',
              value: _fmt(heading, _num0, suffix: '°'),
              big: true,
            ),
            _ResultTile(
              label: 'Ground Speed',
              value: _fmt(gs, _num0, suffix: ' kt'),
              color: _kAmber,
              big: true,
            ),
            _ResultTile(
              label: 'Wind Correction Angle',
              value: wcaLabel,
              color: Colors.white,
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Crosswind / Headwind
// ---------------------------------------------------------------------------

class _CrosswindTab extends StatefulWidget {
  const _CrosswindTab();

  @override
  State<_CrosswindTab> createState() => _CrosswindTabState();
}

class _CrosswindTabState extends State<_CrosswindTab> {
  final _rwy = TextEditingController();
  final _windDir = TextEditingController();
  final _windSpd = TextEditingController();

  @override
  void dispose() {
    _rwy.dispose();
    _windDir.dispose();
    _windSpd.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rwy = double.tryParse(_rwy.text);
    final wd = double.tryParse(_windDir.text);
    final ws = double.tryParse(_windSpd.text);

    double? cross;
    double? along; // + headwind, - tailwind
    if (rwy != null && wd != null && ws != null) {
      final rel = _deg2rad(wd - rwy);
      cross = ws * math.sin(rel);
      along = ws * math.cos(rel);
    }

    String crossLabel = '—';
    if (cross != null) {
      final side = cross >= 0 ? 'from right' : 'from left';
      crossLabel = '${_num0.format(cross.abs())} kt $side';
    }

    String alongLabel = '—';
    Color alongColor = _kCyan;
    if (along != null) {
      if (along >= 0) {
        alongLabel = '${_num0.format(along)} kt headwind';
        alongColor = _kCyan;
      } else {
        alongLabel = '${_num0.format(along.abs())} kt tailwind';
        alongColor = _kRed;
      }
    }

    return _TabBody(
      children: [
        _Panel(
          title: 'CROSSWIND / HEADWIND COMPONENT',
          children: [
            _NumField(
              controller: _rwy,
              label: 'Runway Heading',
              suffix: '°',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            _NumField(
              controller: _windDir,
              label: 'Wind Direction (from)',
              suffix: '°',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            _NumField(
              controller: _windSpd,
              label: 'Wind Speed',
              suffix: 'kt',
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
        _ResultCard(
          title: 'COMPONENTS',
          children: [
            _ResultTile(
              label: 'Crosswind',
              value: cross == null ? '—' : '${_num0.format(cross.abs())} kt',
              color: _kAmber,
              big: true,
            ),
            _ResultTile(
              label: 'Crosswind detail',
              value: crossLabel,
              color: Colors.white,
            ),
            _ResultTile(
              label: along != null && along < 0 ? 'Tailwind' : 'Headwind',
              value: along == null ? '—' : '${_num0.format(along.abs())} kt',
              color: alongColor,
              big: true,
            ),
            _ResultTile(
              label: 'Along-runway detail',
              value: alongLabel,
              color: Colors.white,
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 3. True Airspeed & Density Altitude
// ---------------------------------------------------------------------------

class _TasDaTab extends StatefulWidget {
  const _TasDaTab();

  @override
  State<_TasDaTab> createState() => _TasDaTabState();
}

class _TasDaTabState extends State<_TasDaTab> {
  final _elev = TextEditingController();
  final _oat = TextEditingController();
  final _alt = TextEditingController();
  final _cas = TextEditingController();

  @override
  void dispose() {
    _elev.dispose();
    _oat.dispose();
    _alt.dispose();
    _cas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elev = double.tryParse(_elev.text);
    final oat = double.tryParse(_oat.text);
    final alt = double.tryParse(_alt.text);
    final cas = double.tryParse(_cas.text);

    double? pa;
    double? isaTemp;
    double? da;
    double? tas;

    if (elev != null && alt != null) {
      pa = elev + (29.92 - alt) * 1000.0;
      isaTemp = 15.0 - 2.0 * (pa / 1000.0);
      if (oat != null) {
        da = pa + 120.0 * (oat - isaTemp);
        final sigma = math.pow(1.0 - 6.875e-6 * da, 4.2561).toDouble();
        if (cas != null && cas > 0 && sigma > 0) {
          tas = cas / math.sqrt(sigma);
        }
      }
    }

    return _TabBody(
      children: [
        _Panel(
          title: 'TRUE AIRSPEED & DENSITY ALTITUDE',
          children: [
            _NumField(
              controller: _elev,
              label: 'Field Elevation',
              suffix: 'ft',
              signed: true,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            _NumField(
              controller: _alt,
              label: 'Altimeter Setting',
              suffix: 'inHg',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            _NumField(
              controller: _oat,
              label: 'Outside Air Temp (OAT)',
              suffix: '°C',
              signed: true,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            _NumField(
              controller: _cas,
              label: 'Calibrated Airspeed (CAS/IAS)',
              suffix: 'kt',
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
        _ResultCard(
          title: 'ATMOSPHERE',
          children: [
            _ResultTile(
              label: 'Pressure Altitude',
              value: _fmt(pa, _num0, suffix: ' ft'),
              big: true,
            ),
            _ResultTile(
              label: 'Density Altitude',
              value: _fmt(da, _num0, suffix: ' ft'),
              color: _kAmber,
              big: true,
            ),
            _ResultTile(
              label: 'ISA Temp @ PA',
              value: _fmt(isaTemp, _num1, suffix: ' °C'),
              color: Colors.white,
            ),
            _ResultTile(
              label: 'True Airspeed',
              value: _fmt(tas, _num0, suffix: ' kt'),
              color: _kCyan,
              big: true,
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Time-Speed-Distance
// ---------------------------------------------------------------------------

enum _TsdSolve { speed, distance, time }

class _TimeSpeedDistanceTab extends StatefulWidget {
  const _TimeSpeedDistanceTab();

  @override
  State<_TimeSpeedDistanceTab> createState() => _TimeSpeedDistanceTabState();
}

class _TimeSpeedDistanceTabState extends State<_TimeSpeedDistanceTab> {
  final _speed = TextEditingController();
  final _distance = TextEditingController();
  final _time = TextEditingController(); // minutes

  _TsdSolve _solveFor = _TsdSolve.time;

  @override
  void dispose() {
    _speed.dispose();
    _distance.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gs = double.tryParse(_speed.text);
    final dist = double.tryParse(_distance.text);
    final timeMin = double.tryParse(_time.text);

    double? resSpeed;
    double? resDist;
    double? resTimeMin;

    switch (_solveFor) {
      case _TsdSolve.speed:
        if (dist != null && timeMin != null && timeMin > 0) {
          resSpeed = dist / (timeMin / 60.0);
        }
        break;
      case _TsdSolve.distance:
        if (gs != null && timeMin != null) {
          resDist = gs * (timeMin / 60.0);
        }
        break;
      case _TsdSolve.time:
        if (gs != null && gs > 0 && dist != null) {
          resTimeMin = dist / gs * 60.0;
        }
        break;
    }

    String hhmm(double? minutes) {
      if (minutes == null || minutes.isNaN || minutes.isInfinite) return '—';
      final total = minutes.round();
      final h = total ~/ 60;
      final m = total % 60;
      return '${h}h ${m.toString().padLeft(2, '0')}m';
    }

    return _TabBody(
      children: [
        _Panel(
          title: 'TIME • SPEED • DISTANCE',
          children: [
            _SolveSelector<_TsdSolve>(
              options: const {
                _TsdSolve.time: 'TIME',
                _TsdSolve.speed: 'SPEED',
                _TsdSolve.distance: 'DIST',
              },
              value: _solveFor,
              onChanged: (v) => setState(() => _solveFor = v),
            ),
            const SizedBox(height: 16),
            if (_solveFor != _TsdSolve.speed) ...[
              _NumField(
                controller: _speed,
                label: 'Ground Speed',
                suffix: 'kt',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
            ],
            if (_solveFor != _TsdSolve.distance) ...[
              _NumField(
                controller: _distance,
                label: 'Distance',
                suffix: 'NM',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
            ],
            if (_solveFor != _TsdSolve.time)
              _NumField(
                controller: _time,
                label: 'Time',
                suffix: 'min',
                onChanged: (_) => setState(() {}),
              ),
          ],
        ),
        _ResultCard(
          title: 'RESULT',
          children: [
            if (_solveFor == _TsdSolve.speed)
              _ResultTile(
                label: 'Ground Speed',
                value: _fmt(resSpeed, _num1, suffix: ' kt'),
                big: true,
              ),
            if (_solveFor == _TsdSolve.distance)
              _ResultTile(
                label: 'Distance',
                value: _fmt(resDist, _num1, suffix: ' NM'),
                big: true,
              ),
            if (_solveFor == _TsdSolve.time) ...[
              _ResultTile(
                label: 'Time',
                value: hhmm(resTimeMin),
                big: true,
              ),
              _ResultTile(
                label: 'Time (minutes)',
                value: _fmt(resTimeMin, _num1, suffix: ' min'),
                color: Colors.white,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 5. Fuel
// ---------------------------------------------------------------------------

enum _FuelSolve { fuel, endurance, burn }

class _FuelTab extends StatefulWidget {
  const _FuelTab();

  @override
  State<_FuelTab> createState() => _FuelTabState();
}

class _FuelTabState extends State<_FuelTab> {
  final _burn = TextEditingController(); // gph
  final _time = TextEditingController(); // minutes
  final _fuel = TextEditingController(); // gallons

  _FuelSolve _solveFor = _FuelSolve.fuel;

  @override
  void dispose() {
    _burn.dispose();
    _time.dispose();
    _fuel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final burn = double.tryParse(_burn.text);
    final timeMin = double.tryParse(_time.text);
    final fuel = double.tryParse(_fuel.text);

    double? resFuel;
    double? resTimeMin;
    double? resBurn;

    switch (_solveFor) {
      case _FuelSolve.fuel:
        if (burn != null && timeMin != null) {
          resFuel = burn * (timeMin / 60.0);
        }
        break;
      case _FuelSolve.endurance:
        if (burn != null && burn > 0 && fuel != null) {
          resTimeMin = fuel / burn * 60.0;
        }
        break;
      case _FuelSolve.burn:
        if (fuel != null && timeMin != null && timeMin > 0) {
          resBurn = fuel / (timeMin / 60.0);
        }
        break;
    }

    String hhmm(double? minutes) {
      if (minutes == null || minutes.isNaN || minutes.isInfinite) return '—';
      final total = minutes.round();
      final h = total ~/ 60;
      final m = total % 60;
      return '${h}h ${m.toString().padLeft(2, '0')}m';
    }

    return _TabBody(
      children: [
        _Panel(
          title: 'FUEL PLANNING',
          children: [
            _SolveSelector<_FuelSolve>(
              options: const {
                _FuelSolve.fuel: 'FUEL REQ',
                _FuelSolve.endurance: 'ENDURANCE',
                _FuelSolve.burn: 'BURN RATE',
              },
              value: _solveFor,
              onChanged: (v) => setState(() => _solveFor = v),
            ),
            const SizedBox(height: 16),
            if (_solveFor != _FuelSolve.burn) ...[
              _NumField(
                controller: _burn,
                label: 'Fuel Burn',
                suffix: 'gph',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
            ],
            if (_solveFor != _FuelSolve.endurance) ...[
              _NumField(
                controller: _time,
                label: 'Flight Time',
                suffix: 'min',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
            ],
            if (_solveFor != _FuelSolve.fuel)
              _NumField(
                controller: _fuel,
                label: 'Fuel Quantity',
                suffix: 'gal',
                onChanged: (_) => setState(() {}),
              ),
          ],
        ),
        _ResultCard(
          title: 'RESULT',
          children: [
            if (_solveFor == _FuelSolve.fuel)
              _ResultTile(
                label: 'Fuel Required',
                value: _fmt(resFuel, _num1, suffix: ' gal'),
                big: true,
              ),
            if (_solveFor == _FuelSolve.endurance) ...[
              _ResultTile(
                label: 'Endurance',
                value: hhmm(resTimeMin),
                big: true,
              ),
              _ResultTile(
                label: 'Endurance (minutes)',
                value: _fmt(resTimeMin, _num1, suffix: ' min'),
                color: Colors.white,
              ),
            ],
            if (_solveFor == _FuelSolve.burn)
              _ResultTile(
                label: 'Burn Rate',
                value: _fmt(resBurn, _num1, suffix: ' gph'),
                big: true,
              ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 6. Unit conversions
// ---------------------------------------------------------------------------

class _ConvUnit {
  const _ConvUnit(this.label, this.toBase, this.fromBase);

  final String label;

  /// Convert a value in this unit to the category's base unit.
  final double Function(double v) toBase;

  /// Convert a value in the base unit to this unit.
  final double Function(double v) fromBase;
}

class _ConvCategory {
  const _ConvCategory(this.name, this.units);

  final String name;
  final List<_ConvUnit> units;
}

final List<_ConvCategory> _conversionCategories = [
  _ConvCategory('Distance', [
    _ConvUnit('NM', (v) => v * 1852.0, (v) => v / 1852.0),
    _ConvUnit('SM', (v) => v * 1609.344, (v) => v / 1609.344),
    _ConvUnit('km', (v) => v * 1000.0, (v) => v / 1000.0),
    _ConvUnit('m', (v) => v, (v) => v),
  ]),
  _ConvCategory('Altitude', [
    _ConvUnit('ft', (v) => v * 0.3048, (v) => v / 0.3048),
    _ConvUnit('m', (v) => v, (v) => v),
  ]),
  _ConvCategory('Speed', [
    _ConvUnit('kt', (v) => v * 1.852, (v) => v / 1.852), // base km/h
    _ConvUnit('mph', (v) => v * 1.609344, (v) => v / 1.609344),
    _ConvUnit('km/h', (v) => v, (v) => v),
  ]),
  _ConvCategory('Volume', [
    _ConvUnit('gal', (v) => v * 3.785411784, (v) => v / 3.785411784),
    _ConvUnit('L', (v) => v, (v) => v),
  ]),
  _ConvCategory('Weight', [
    _ConvUnit('lbs', (v) => v * 0.45359237, (v) => v / 0.45359237),
    _ConvUnit('kg', (v) => v, (v) => v),
  ]),
  _ConvCategory('Temperature', [
    _ConvUnit('°C', (v) => v, (v) => v),
    _ConvUnit('°F', (v) => (v - 32.0) * 5.0 / 9.0, (v) => v * 9.0 / 5.0 + 32.0),
  ]),
  _ConvCategory('Pressure', [
    _ConvUnit('inHg', (v) => v * 33.8638866667, (v) => v / 33.8638866667),
    _ConvUnit('hPa', (v) => v, (v) => v),
  ]),
];

class _ConversionTab extends StatefulWidget {
  const _ConversionTab();

  @override
  State<_ConversionTab> createState() => _ConversionTabState();
}

class _ConversionTabState extends State<_ConversionTab> {
  final _input = TextEditingController();
  int _categoryIndex = 0;
  int _fromIndex = 0;
  int _toIndex = 1;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _selectCategory(int i) {
    setState(() {
      _categoryIndex = i;
      _fromIndex = 0;
      _toIndex = _conversionCategories[i].units.length > 1 ? 1 : 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final category = _conversionCategories[_categoryIndex];
    final units = category.units;
    final value = double.tryParse(_input.text);

    double? result;
    if (value != null) {
      final base = units[_fromIndex].toBase(value);
      result = units[_toIndex].fromBase(base);
    }

    return _TabBody(
      children: [
        _Panel(
          title: 'UNIT CONVERSIONS',
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (int i = 0; i < _conversionCategories.length; i++)
                  ChoiceChip(
                    label: Text(_conversionCategories[i].name),
                    selected: i == _categoryIndex,
                    onSelected: (_) => _selectCategory(i),
                    backgroundColor: _kBg,
                    selectedColor: _kCyan.withValues(alpha: 0.25),
                    side: BorderSide(
                      color: i == _categoryIndex ? _kCyan : Colors.white24,
                    ),
                    labelStyle: GoogleFonts.inter(
                      color: i == _categoryIndex ? _kCyan : Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _NumField(
              controller: _input,
              label: 'Value',
              signed: true,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _UnitDropdown(
                    label: 'From',
                    units: units,
                    index: _fromIndex,
                    onChanged: (i) => setState(() => _fromIndex = i),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: IconButton(
                    icon: const Icon(Icons.swap_horiz, color: _kAmber),
                    onPressed: () => setState(() {
                      final t = _fromIndex;
                      _fromIndex = _toIndex;
                      _toIndex = t;
                    }),
                  ),
                ),
                Expanded(
                  child: _UnitDropdown(
                    label: 'To',
                    units: units,
                    index: _toIndex,
                    onChanged: (i) => setState(() => _toIndex = i),
                  ),
                ),
              ],
            ),
          ],
        ),
        _ResultCard(
          title: 'RESULT',
          children: [
            _ResultTile(
              label:
                  '${units[_fromIndex].label} → ${units[_toIndex].label}',
              value: _fmt(result, _num2, suffix: ' ${units[_toIndex].label}'),
              big: true,
            ),
          ],
        ),
      ],
    );
  }
}

class _UnitDropdown extends StatelessWidget {
  const _UnitDropdown({
    required this.label,
    required this.units,
    required this.index,
    required this.onChanged,
  });

  final String label;
  final List<_ConvUnit> units;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: index,
          isExpanded: true,
          dropdownColor: _kPanel,
          iconEnabledColor: _kCyan,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
          items: [
            for (int i = 0; i < units.length; i++)
              DropdownMenuItem<int>(
                value: i,
                child: Text(units[i].label),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

/// A small segmented control used to pick which variable to solve for.
class _SolveSelector<T> extends StatelessWidget {
  const _SolveSelector({
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final Map<T, String> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final entries = options.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SOLVE FOR',
          style: GoogleFonts.inter(
            color: Colors.white54,
            fontSize: 11,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _kBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              for (final e in entries)
                Expanded(
                  child: Semantics(
                    container: true,
                    button: true,
                    inMutuallyExclusiveGroup: true,
                    selected: e.key == value,
                    label: 'Solve for ${e.value}',
                    excludeSemantics: true,
                    child: GestureDetector(
                    onTap: () => onChanged(e.key),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: e.key == value ? _kCyan : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Center(
                        child: Text(
                          e.value,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.orbitron(
                            color: e.key == value
                                ? Colors.black
                                : Colors.white70,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
