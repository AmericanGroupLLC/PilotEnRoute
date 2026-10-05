import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../services/weight_balance_service.dart';
import 'package:agl_i18n/agl_i18n.dart';

// App palette.
const _kBg = Color(0xFF0A1628);
const _kCard = Color(0xFF112240);
const _kCyan = Color(0xFF00BCD4);
const _kAmber = Color(0xFFFFB300);
const _kRed = Color(0xFFF44336);
const _kGreen = Color(0xFF4CAF50);

class WeightBalanceScreen extends StatefulWidget {
  const WeightBalanceScreen({super.key});

  @override
  State<WeightBalanceScreen> createState() => _WeightBalanceScreenState();
}

class _WeightBalanceScreenState extends State<WeightBalanceScreen> {
  // The screen OWNS its service instance (no provider registration needed).
  final WeightBalanceService _service = WeightBalanceService();

  final Map<String, TextEditingController> _stationControllers = {};
  final TextEditingController _paltController =
      TextEditingController(text: '0');
  final TextEditingController _oatController = TextEditingController(text: '15');

  final NumberFormat _num0 = NumberFormat('#,##0');
  final NumberFormat _num1 = NumberFormat('#,##0.0');
  final NumberFormat _num2 = NumberFormat('#,##0.00');

  String? _syncedProfileId;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceChanged);
    _service.init();
  }

  void _onServiceChanged() {
    _syncControllers();
    if (mounted) setState(() {});
  }

  /// Rebuild the per-station text controllers when the active profile changes.
  void _syncControllers() {
    if (!_service.isLoaded) return;
    final profile = _service.activeProfile;
    if (_syncedProfileId == profile.id &&
        _stationControllers.length == profile.stations.length) {
      return;
    }
    _syncedProfileId = profile.id;
    for (final c in _stationControllers.values) {
      c.dispose();
    }
    _stationControllers.clear();
    for (final s in profile.stations) {
      final v = _service.stationValue(s.name);
      _stationControllers[s.name] =
          TextEditingController(text: v == 0 ? '' : _trim(v));
    }
  }

  String _trim(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toString();
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    for (final c in _stationControllers.values) {
      c.dispose();
    }
    _paltController.dispose();
    _oatController.dispose();
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('WEIGHT & BALANCE'),
        actions: [
          IconButton(
            tooltip: 'Add custom aircraft',
            icon: const Icon(Icons.add, color: _kCyan),
            onPressed: _service.isLoaded ? () => _openEditor(null) : null,
          ),
        ],
      ),
      body: !_service.isLoaded
          ? const Center(
              child: CircularProgressIndicator(color: _kCyan),
            )
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final profile = _service.activeProfile;
    final result = _service.compute(profile, _service.loading);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildDisclaimer(),
        const SizedBox(height: 12),
        _buildProfileSelector(profile),
        const SizedBox(height: 12),
        _buildStationsCard(profile),
        const SizedBox(height: 12),
        _buildResultsCard(profile, result),
        const SizedBox(height: 12),
        _buildEnvelopeCard(profile, result),
        const SizedBox(height: 12),
        _buildPerformanceCard(),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Disclaimer ───────────────────────────────────────────────────────────────
  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kAmber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kAmber.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: _kAmber, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Representative data — always verify against your aircraft '
              'POH/AFM before flight.',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: _kAmber,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Profile selector ─────────────────────────────────────────────────────────
  Widget _buildProfileSelector(AircraftProfile profile) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('AIRCRAFT', _kCyan),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                dropdownColor: _kCard,
                value: profile.id,
                icon: const Icon(Icons.arrow_drop_down, color: _kCyan),
                style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
                items: _service.profiles
                    .map(
                      (p) => DropdownMenuItem(
                        value: p.id,
                        child: Row(
                          children: [
                            Icon(
                              p.isBuiltIn
                                  ? Icons.flight
                                  : Icons.edit_note,
                              size: 16,
                              color: p.isBuiltIn ? _kCyan : _kAmber,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                p.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (id) {
                  if (id != null) _service.setActiveProfile(id);
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statChip('EMPTY WT',
                  '${_num0.format(profile.emptyWeight)} lb', _kCyan),
              const SizedBox(width: 8),
              _statChip(
                  'EMPTY ARM', '${_num1.format(profile.emptyArm)} in', _kCyan),
              const SizedBox(width: 8),
              _statChip('MAX GROSS',
                  '${_num0.format(profile.maxGross)} lb', _kAmber),
            ],
          ),
          if (!profile.isBuiltIn) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kCyan,
                      side: const BorderSide(color: _kCyan),
                    ),
                    onPressed: () => _openEditor(profile),
                    icon: const Icon(Icons.edit, size: 16),
                    label: Text('EDIT',
                        style: GoogleFonts.orbitron(fontSize: 10)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kRed,
                      side: const BorderSide(color: _kRed),
                    ),
                    onPressed: () => _confirmDelete(profile),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: Text('DELETE',
                        style: GoogleFonts.orbitron(fontSize: 10)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Station inputs ───────────────────────────────────────────────────────────
  Widget _buildStationsCard(AircraftProfile profile) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('LOADING', _kCyan),
          const SizedBox(height: 6),
          ...profile.stations.map((s) => _buildStationRow(s)),
        ],
      ),
    );
  }

  Widget _buildStationRow(WBStation s) {
    final controller = _stationControllers[s.name];
    final isFuel = s.isFuel;
    final input = _service.stationValue(s.name);
    final derivedWeight =
        isFuel ? input * kFuelWeightPerGallon : input;
    final overLimit = s.maxWeight != null && derivedWeight > s.maxWeight! + 1e-9;
    final overFuel =
        isFuel && s.maxGallons != null && input > s.maxGallons! + 1e-9;
    final warn = overLimit || overFuel;

    String subtitle = 'arm ${_num1.format(s.arm)} in';
    if (isFuel) {
      subtitle += '  •  ${_num0.format(derivedWeight)} lb'
          '  •  max ${_num0.format(s.maxGallons ?? 0)} gal';
    } else if (s.maxWeight != null) {
      subtitle += '  •  max ${_num0.format(s.maxWeight!)} lb';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.name,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: warn ? _kRed : Colors.white54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              textAlign: TextAlign.right,
              style: GoogleFonts.orbitron(
                fontSize: 14,
                color: warn ? _kRed : _kCyan,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                isDense: true,
                suffixText: isFuel ? 'gal' : 'lb',
                suffixStyle:
                    GoogleFonts.inter(fontSize: 10, color: Colors.white38),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                filled: true,
                fillColor: _kBg,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kCyan),
                ),
              ),
              onChanged: (t) {
                final v = double.tryParse(t) ?? 0;
                _service.setStationValue(s.name, v);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Results ──────────────────────────────────────────────────────────────────
  Widget _buildResultsCard(AircraftProfile profile, WBResult r) {
    final cgText = r.hasCg ? '${_num2.format(r.cg)} in' : '—';
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('RESULTS', _kCyan),
          const SizedBox(height: 12),
          Row(
            children: [
              _bigStat('TOTAL WEIGHT',
                  '${_num0.format(r.totalWeight)} lb', _kCyan),
              const SizedBox(width: 10),
              _bigStat('CG', cgText, _kCyan),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _bigStat('TOTAL MOMENT',
                  '${_num0.format(r.totalMoment)} in-lb', Colors.white70),
              const SizedBox(width: 10),
              _bigStat(
                'CG LIMITS',
                '${_num1.format(r.fwdLimit)}–${_num1.format(r.aftLimit)}',
                Colors.white70,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _passFail(
            'GROSS WEIGHT',
            r.weightOk,
            r.weightOk
                ? '${_num0.format(profile.maxGross - r.totalWeight)} lb under max gross'
                : 'Exceeds max gross (${_num0.format(profile.maxGross)} lb)',
          ),
          const SizedBox(height: 8),
          _passFail(
            'CENTER OF GRAVITY',
            r.cgOk,
            !r.hasCg
                ? 'No load entered'
                : r.cgOk
                    ? 'Within CG envelope'
                    : 'Outside CG envelope for this weight',
          ),
        ],
      ),
    );
  }

  Widget _passFail(String label, bool ok, String detail) {
    final color = ok ? _kGreen : _kRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.cancel, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.orbitron(
                    fontSize: 10,
                    color: color,
                    letterSpacing: 1,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
          Text(
            ok ? 'PASS' : 'FAIL',
            style: GoogleFonts.orbitron(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ── Envelope chart ───────────────────────────────────────────────────────────
  Widget _buildEnvelopeCard(AircraftProfile profile, WBResult r) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('CG ENVELOPE', _kCyan),
          const SizedBox(height: 8),
          Text(
            'Weight (lb) vs. CG (in aft of datum)',
            style: GoogleFonts.inter(fontSize: 10, color: Colors.white54),
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 1.25,
            child: CustomPaint(
              painter: _EnvelopePainter(
                envelope: profile.envelope,
                maxGross: profile.maxGross,
                cg: r.cg,
                weight: r.totalWeight,
                hasPoint: r.hasCg,
                inside: r.cgOk,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _legendDot(_kCyan, 'Envelope'),
              const SizedBox(width: 16),
              _legendDot(r.cgOk ? _kGreen : _kRed, 'Current load'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color c, String label) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(
          color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: GoogleFonts.inter(fontSize: 10, color: Colors.white54)),
      ],
    );
  }

  // ── Performance ──────────────────────────────────────────────────────────────
  Widget _buildPerformanceCard() {
    final pa = double.tryParse(_paltController.text) ?? 0;
    final oat = double.tryParse(_oatController.text) ?? 15;
    final da = WeightBalanceService.densityAltitude(pa, oat);
    final factor = WeightBalanceService.takeoffFactor(da);
    final pct = ((factor - 1) * 100).round();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('PERFORMANCE ESTIMATE', _kAmber),
          const SizedBox(height: 4),
          Text(
            'Rough approximation only — not a POH performance chart.',
            style: GoogleFonts.inter(fontSize: 10, color: Colors.white54),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _perfInput(
                  'PRESSURE ALT',
                  _paltController,
                  'ft',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _perfInput(
                  'OAT',
                  _oatController,
                  '°C',
                  allowNegative: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _bigStat('DENSITY ALT', '${_num0.format(da)} ft',
                  da > pa ? _kAmber : _kGreen),
              const SizedBox(width: 10),
              _bigStat('TAKEOFF ROLL', '+$pct%', pct >= 20 ? _kRed : _kAmber),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Est. ground roll ~$pct% longer than a sea-level standard day '
            '(rule of thumb: +10% per 1,000 ft density altitude). Always use '
            'the takeoff/landing charts in your POH.',
            style: GoogleFonts.inter(
                fontSize: 10, color: Colors.white54, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _perfInput(String label, TextEditingController c, String suffix,
      {bool allowNegative = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.orbitron(
                fontSize: 9, color: Colors.white54, letterSpacing: 1)),
        const SizedBox(height: 6),
        TextField(
          controller: c,
          keyboardType: TextInputType.numberWithOptions(
              decimal: true, signed: allowNegative),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
                RegExp(allowNegative ? r'[0-9.\-]' : r'[0-9.]')),
          ],
          style: GoogleFonts.orbitron(
              fontSize: 15, color: _kAmber, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            isDense: true,
            suffixText: suffix,
            suffixStyle: GoogleFonts.inter(fontSize: 10, color: Colors.white38),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            filled: true,
            fillColor: _kBg,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kAmber),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  // ── Shared widgets ───────────────────────────────────────────────────────────
  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: child,
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Text(
      text,
      style: GoogleFonts.orbitron(
        fontSize: 11,
        color: color,
        letterSpacing: 2,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          children: [
            Text(label,
                style: GoogleFonts.orbitron(
                    fontSize: 8, color: Colors.white38, letterSpacing: 1)),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(value,
                  style: GoogleFonts.orbitron(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bigStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.orbitron(
                    fontSize: 8, color: Colors.white38, letterSpacing: 1)),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: GoogleFonts.orbitron(
                      fontSize: 16,
                      color: color,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Delete confirm ───────────────────────────────────────────────────────────
  void _confirmDelete(AircraftProfile profile) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        title: Text('Delete aircraft?',
            style: GoogleFonts.orbitron(fontSize: 14, color: Colors.white)),
        content: Text('Remove "${profile.name}"? This cannot be undone.',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL',
                style: GoogleFonts.orbitron(fontSize: 11, color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              _service.deleteCustom(profile.id);
              Navigator.pop(ctx);
            },
            child: Text('DELETE',
                style: GoogleFonts.orbitron(fontSize: 11, color: _kRed)),
          ),
        ],
      ),
    );
  }

  // ── Editor ───────────────────────────────────────────────────────────────────
  void _openEditor(AircraftProfile? existing) {
    showDialog<AircraftProfile>(
      context: context,
      builder: (ctx) => _ProfileEditorDialog(
        existing: existing,
        newId: _service.newCustomId(),
      ),
    ).then((profile) {
      if (profile != null) {
        _service.addOrUpdateCustom(profile);
        _service.setActiveProfile(profile.id);
      }
    });
  }
}

// ── Envelope painter ───────────────────────────────────────────────────────────
class _EnvelopePainter extends CustomPainter {
  final List<WBEnvelopePoint> envelope;
  final double maxGross;
  final double cg;
  final double weight;
  final bool hasPoint;
  final bool inside;

  _EnvelopePainter({
    required this.envelope,
    required this.maxGross,
    required this.cg,
    required this.weight,
    required this.hasPoint,
    required this.inside,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const left = 44.0;
    const bottom = 24.0;
    const top = 8.0;
    const right = 8.0;
    final plotW = size.width - left - right;
    final plotH = size.height - top - bottom;
    if (plotW <= 0 || plotH <= 0 || envelope.isEmpty) return;

    // Axis ranges.
    double minCg = double.infinity, maxCg = -double.infinity;
    double minW = double.infinity, maxW = -double.infinity;
    for (final p in envelope) {
      minCg = math.min(minCg, p.fwdCG);
      maxCg = math.max(maxCg, p.aftCG);
      minW = math.min(minW, p.weight);
      maxW = math.max(maxW, p.weight);
    }
    maxW = math.max(maxW, maxGross);
    if (hasPoint && cg.isFinite) {
      minCg = math.min(minCg, cg);
      maxCg = math.max(maxCg, cg);
      maxW = math.max(maxW, weight);
      minW = math.min(minW, weight);
    }
    // Padding on ranges.
    final cgPad = (maxCg - minCg) * 0.10 + 0.5;
    final wPad = (maxW - minW) * 0.08 + 20;
    minCg -= cgPad;
    maxCg += cgPad;
    minW -= wPad;
    maxW += wPad;
    if (maxCg - minCg < 1e-6) maxCg = minCg + 1;
    if (maxW - minW < 1e-6) maxW = minW + 1;

    double px(double c) => left + (c - minCg) / (maxCg - minCg) * plotW;
    double py(double w) => top + (1 - (w - minW) / (maxW - minW)) * plotH;

    // Axes.
    final axisPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    canvas.drawLine(
        const Offset(left, top), Offset(left, top + plotH), axisPaint);
    canvas.drawLine(Offset(left, top + plotH),
        Offset(left + plotW, top + plotH), axisPaint);

    // Grid + labels.
    final gridPaint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 1;
    const wSteps = 4;
    for (int i = 0; i <= wSteps; i++) {
      final w = minW + (maxW - minW) * i / wSteps;
      final y = py(w);
      canvas.drawLine(Offset(left, y), Offset(left + plotW, y), gridPaint);
      _text(canvas, w.round().toString(), Offset(2, y - 5),
          const Color(0xFF8A97A8), 8);
    }
    const cSteps = 4;
    for (int i = 0; i <= cSteps; i++) {
      final c = minCg + (maxCg - minCg) * i / cSteps;
      final x = px(c);
      _text(canvas, c.toStringAsFixed(0), Offset(x - 8, top + plotH + 6),
          const Color(0xFF8A97A8), 8);
    }

    // Envelope polygon.
    final path = Path();
    // Forward (left) edge, ascending weight.
    for (int i = 0; i < envelope.length; i++) {
      final p = envelope[i];
      final pt = Offset(px(p.fwdCG), py(p.weight));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    // Aft (right) edge, descending weight.
    for (int i = envelope.length - 1; i >= 0; i--) {
      final p = envelope[i];
      path.lineTo(px(p.aftCG), py(p.weight));
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = _kCyan.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = _kCyan
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Max gross reference line.
    final mgY = py(maxGross);
    final dashPaint = Paint()
      ..color = _kAmber.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    _dashedLine(canvas, Offset(left, mgY), Offset(left + plotW, mgY), dashPaint);

    // Current point.
    if (hasPoint && cg.isFinite) {
      final c = inside ? _kGreen : _kRed;
      final center = Offset(px(cg), py(weight));
      canvas.drawCircle(center, 7, Paint()..color = c.withValues(alpha: 0.25));
      canvas.drawCircle(center, 4, Paint()..color = c);
      canvas.drawCircle(
        center,
        4,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint p) {
    const dash = 5.0, gap = 4.0;
    final total = (b - a).distance;
    final dir = (b - a) / total;
    double d = 0;
    while (d < total) {
      final start = a + dir * d;
      final end = a + dir * math.min(d + dash, total);
      canvas.drawLine(start, end, p);
      d += dash + gap;
    }
  }

  void _text(Canvas canvas, String s, Offset o, Color color, double size) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: GoogleFonts.inter(fontSize: size, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, o);
  }

  @override
  bool shouldRepaint(covariant _EnvelopePainter old) {
    return old.cg != cg ||
        old.weight != weight ||
        old.inside != inside ||
        old.hasPoint != hasPoint ||
        old.maxGross != maxGross ||
        old.envelope != envelope;
  }
}

// ── Custom profile editor ──────────────────────────────────────────────────────
class _ProfileEditorDialog extends StatefulWidget {
  final AircraftProfile? existing;
  final String newId;

  const _ProfileEditorDialog({required this.existing, required this.newId});

  @override
  State<_ProfileEditorDialog> createState() => _ProfileEditorDialogState();
}

class _ProfileEditorDialogState extends State<_ProfileEditorDialog> {
  late final Map<String, TextEditingController> _c;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    WBStation? station(bool Function(WBStation) test) {
      final list = e?.stations.where(test);
      return (list != null && list.isNotEmpty) ? list.first : null;
    }

    final front = e == null ? null : station((s) => s.arm > 0 && !s.isFuel);
    final fuel = e == null ? null : station((s) => s.isFuel);
    final bag = e == null
        ? null
        : station((s) => !s.isFuel && s.maxWeight != null);
    // Rear: a non-fuel station that isn't the front and isn't baggage.
    WBStation? rear;
    if (e != null) {
      for (final s in e.stations) {
        if (!s.isFuel &&
            s.maxWeight == null &&
            s.name != front?.name) {
          rear = s;
          break;
        }
      }
    }

    final envFirst = (e != null && e.envelope.isNotEmpty) ? e.envelope.first : null;
    final envLast = (e != null && e.envelope.isNotEmpty) ? e.envelope.last : null;

    String s(num? v) => v == null ? '' : _fmt(v.toDouble());

    _c = {
      'name': TextEditingController(text: e?.name ?? ''),
      'emptyWeight': TextEditingController(text: s(e?.emptyWeight)),
      'emptyArm': TextEditingController(text: s(e?.emptyArm)),
      'maxGross': TextEditingController(text: s(e?.maxGross)),
      'frontArm': TextEditingController(text: s(front?.arm)),
      'rearArm': TextEditingController(text: s(rear?.arm)),
      'bagArm': TextEditingController(text: s(bag?.arm)),
      'bagMax': TextEditingController(text: s(bag?.maxWeight)),
      'fuelArm': TextEditingController(text: s(fuel?.arm)),
      'fuelGal': TextEditingController(text: s(fuel?.maxGallons)),
      'envMinW': TextEditingController(text: s(envFirst?.weight)),
      'fwdLight': TextEditingController(text: s(envFirst?.fwdCG)),
      'aftLight': TextEditingController(text: s(envFirst?.aftCG)),
      'fwdHeavy': TextEditingController(text: s(envLast?.fwdCG)),
      'aftHeavy': TextEditingController(text: s(envLast?.aftCG)),
    };
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  double _d(String key) => double.tryParse(_c[key]!.text.trim()) ?? 0;

  void _save() {
    final name = _c['name']!.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aircraft name is required')),
      );
      return;
    }
    final maxGross = _d('maxGross');
    final minW = _d('envMinW');
    final profile = AircraftProfile(
      id: widget.existing?.id ?? widget.newId,
      name: name,
      emptyWeight: _d('emptyWeight'),
      emptyArm: _d('emptyArm'),
      maxGross: maxGross,
      isBuiltIn: false,
      stations: [
        WBStation(name: 'Front seats (pilot + pax)', arm: _d('frontArm')),
        WBStation(name: 'Rear seats', arm: _d('rearArm')),
        WBStation(
            name: 'Baggage',
            arm: _d('bagArm'),
            maxWeight: _d('bagMax') > 0 ? _d('bagMax') : null),
        WBStation(
            name: 'Fuel',
            arm: _d('fuelArm'),
            isFuel: true,
            maxGallons: _d('fuelGal') > 0 ? _d('fuelGal') : null),
      ],
      envelope: [
        WBEnvelopePoint(
            minW > 0 ? minW : 0, _d('fwdLight'), _d('aftLight')),
        WBEnvelopePoint(
            maxGross > 0 ? maxGross : minW + 1, _d('fwdHeavy'), _d('aftHeavy')),
      ],
    );
    Navigator.pop(context, profile);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _kCard,
      title: Text(
        widget.existing == null ? 'NEW AIRCRAFT' : 'EDIT AIRCRAFT',
        style: GoogleFonts.orbitron(
            fontSize: 14, color: _kCyan, letterSpacing: 1),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field('name', 'Aircraft name', text: true),
              _group('BASIC'),
              _field('emptyWeight', 'Empty weight (lb)'),
              _field('emptyArm', 'Empty arm (in)'),
              _field('maxGross', 'Max gross weight (lb)'),
              _group('STATION ARMS (in)'),
              _field('frontArm', 'Front seats arm'),
              _field('rearArm', 'Rear seats arm'),
              _field('bagArm', 'Baggage arm'),
              _field('bagMax', 'Baggage max (lb)'),
              _field('fuelArm', 'Fuel arm'),
              _field('fuelGal', 'Fuel capacity (gal)'),
              _group('CG ENVELOPE'),
              _field('envMinW', 'Min envelope weight (lb)'),
              _field('fwdLight', 'Fwd CG at min weight (in)'),
              _field('aftLight', 'Aft CG at min weight (in)'),
              _field('fwdHeavy', 'Fwd CG at max gross (in)'),
              _field('aftHeavy', 'Aft CG at max gross (in)'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('CANCEL',
              style:
                  GoogleFonts.orbitron(fontSize: 11, color: Colors.white54)),
        ),
        TextButton(
          onPressed: _save,
          child: Text('SAVE',
              style: GoogleFonts.orbitron(fontSize: 11, color: _kCyan)),
        ),
      ],
    );
  }

  Widget _group(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Text(label,
          style: GoogleFonts.orbitron(
              fontSize: 9, color: _kAmber, letterSpacing: 1.5)),
    );
  }

  Widget _field(String key, String label, {bool text = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: TextField(
        controller: _c[key],
        keyboardType: text
            ? TextInputType.text
            : const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: text
            ? null
            : [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          filled: true,
          fillColor: _kBg,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.white12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kCyan),
          ),
        ),
      ),
    );
  }
}
