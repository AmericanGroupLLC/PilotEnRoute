import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fuel Management screen.
///
/// Self-contained: owns its own [Timer] for the tank timer and reads/writes
/// the switch-interval preference directly via [SharedPreferences]. No provider
/// registration and no changes to main.dart are required.
class FuelScreen extends StatefulWidget {
  const FuelScreen({super.key});

  @override
  State<FuelScreen> createState() => _FuelScreenState();
}

class _FuelScreenState extends State<FuelScreen> {
  // ── Palette (matches app conventions) ──────────────────────────────────────
  static const Color _bg = Sky.canvas;
  static const Color _card = Sky.card;
  static const Color _cyan = Sky.teal;
  static const Color _amber = Sky.caution;
  static const Color _red = Sky.stop;
  static const Color _green = Sky.go;

  static const String _kSwitchIntervalPref = 'fuel_switch_interval';

  // ── Fuel calculator inputs ─────────────────────────────────────────────────
  final TextEditingController _totalFuelCtrl = TextEditingController();
  final TextEditingController _burnRateCtrl = TextEditingController();
  final TextEditingController _reserveCtrl =
      TextEditingController(text: '30'); // minutes, VFR day default
  final TextEditingController _groundSpeedCtrl = TextEditingController();
  final TextEditingController _plannedTimeCtrl = TextEditingController(); // min
  final TextEditingController _plannedDistCtrl = TextEditingController(); // nm

  // ── Fuel cost inputs ───────────────────────────────────────────────────────
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _costGallonsCtrl = TextEditingController();

  // ── Tank timer state ───────────────────────────────────────────────────────
  Timer? _timer;
  bool _running = false;
  int _currentTankSeconds = 0; // elapsed on the active tank this leg
  int _leftTotalSeconds = 0; // running total on LEFT
  int _rightTotalSeconds = 0; // running total on RIGHT
  bool _leftActive = true; // true = LEFT, false = RIGHT
  int _switchIntervalMinutes = 30; // persisted preference
  bool _alertActive = false; // SWITCH TANKS alert latched
  bool _hapticFired = false; // prevent repeated haptics per crossing

  @override
  void initState() {
    super.initState();
    _loadSwitchInterval();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _totalFuelCtrl.dispose();
    _burnRateCtrl.dispose();
    _reserveCtrl.dispose();
    _groundSpeedCtrl.dispose();
    _plannedTimeCtrl.dispose();
    _plannedDistCtrl.dispose();
    _priceCtrl.dispose();
    _costGallonsCtrl.dispose();
    super.dispose();
  }

  // ── Preferences ────────────────────────────────────────────────────────────
  Future<void> _loadSwitchInterval() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getInt(_kSwitchIntervalPref);
      if (stored != null && stored > 0 && mounted) {
        setState(() => _switchIntervalMinutes = stored);
      }
    } catch (_) {
      // Ignore storage errors — fall back to in-memory default.
    }
  }

  Future<void> _saveSwitchInterval() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kSwitchIntervalPref, _switchIntervalMinutes);
    } catch (_) {
      // Non-fatal.
    }
  }

  // ── Tank timer control ─────────────────────────────────────────────────────
  void _startTimer() {
    if (_running) return;
    setState(() => _running = true);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _currentTankSeconds++;
        final intervalSeconds = _switchIntervalMinutes * 60;
        if (intervalSeconds > 0 && _currentTankSeconds >= intervalSeconds) {
          if (!_alertActive) _alertActive = true;
          if (!_hapticFired) {
            _hapticFired = true;
            HapticFeedback.heavyImpact();
          }
        }
      });
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    if (mounted) setState(() => _running = false);
  }

  void _resetTimer() {
    _timer?.cancel();
    if (mounted) {
      setState(() {
        _running = false;
        _currentTankSeconds = 0;
        _alertActive = false;
        _hapticFired = false;
      });
    }
  }

  /// Switch active tank: banks the current leg's time onto the active tank's
  /// running total and resets the current-tank timer (keeps running if active).
  void _switchTank() {
    setState(() {
      if (_leftActive) {
        _leftTotalSeconds += _currentTankSeconds;
      } else {
        _rightTotalSeconds += _currentTankSeconds;
      }
      _leftActive = !_leftActive;
      _currentTankSeconds = 0;
      _alertActive = false;
      _hapticFired = false;
    });
  }

  // ── Formatting helpers ─────────────────────────────────────────────────────
  static String _fmtHMS(int totalSeconds) {
    if (totalSeconds < 0) totalSeconds = 0;
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  /// Format a duration given in minutes (double) as HH:MM.
  static String _fmtHM(double minutes) {
    if (minutes.isNaN || minutes.isInfinite || minutes < 0) minutes = 0;
    final total = minutes.round();
    final h = total ~/ 60;
    final m = total % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  double? _parse(TextEditingController c) {
    final v = double.tryParse(c.text.trim());
    if (v == null) return null;
    return v;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('FUEL MANAGEMENT'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildCalculatorCard(),
          const SizedBox(height: 12),
          _buildTankTimerCard(),
          const SizedBox(height: 12),
          _buildCostCard(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1 + 4. Fuel calculator + reserve compliance
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildCalculatorCard() {
    final totalFuel = _parse(_totalFuelCtrl); // gal
    final burn = _parse(_burnRateCtrl); // gph
    final reserveMin = _parse(_reserveCtrl) ?? 0; // min
    final gs = _parse(_groundSpeedCtrl); // kt
    final plannedMin = _parse(_plannedTimeCtrl); // min
    final plannedDist = _parse(_plannedDistCtrl); // nm

    final bool hasCore =
        totalFuel != null && totalFuel > 0 && burn != null && burn > 0;

    double enduranceMin = 0; // total endurance (min)
    double usableMin = 0; // endurance minus reserve (min)
    double reserveGal = 0;
    if (hasCore) {
      enduranceMin = (totalFuel / burn) * 60.0;
      reserveGal = (reserveMin / 60.0) * burn;
      usableMin = enduranceMin - reserveMin;
    }

    // Still-air range from usable (reserve-protected) endurance.
    double? usableRangeNm;
    if (hasCore && gs != null && gs > 0) {
      usableRangeNm = (usableMin.clamp(0, double.infinity) / 60.0) * gs;
    }

    // Fuel required for a planned time.
    double? fuelForTimeGal;
    if (hasCore && plannedMin != null && plannedMin > 0) {
      fuelForTimeGal = (plannedMin / 60.0) * burn;
    }

    // Fuel required for a planned distance (needs GS to convert to time).
    double? fuelForDistGal;
    double? timeForDistMin;
    if (hasCore &&
        plannedDist != null &&
        plannedDist > 0 &&
        gs != null &&
        gs > 0) {
      timeForDistMin = (plannedDist / gs) * 60.0;
      fuelForDistGal = (timeForDistMin / 60.0) * burn;
    }

    // Warn if the planned time exceeds usable endurance.
    final bool overUsable =
        hasCore && plannedMin != null && plannedMin > usableMin;
    final bool overTotal =
        hasCore && plannedMin != null && plannedMin > enduranceMin;

    // Reserve compliance: compare usable (endurance − reserve) headroom.
    // green  : comfortable margin (> 15 min above reserve)
    // amber  : thin margin (0–15 min above reserve)
    // red    : below reserve (usable <= 0)
    Color statusColor = Sky.muted;
    String statusLabel = 'ENTER FUEL & BURN';
    IconData statusIcon = Icons.help_outline;
    if (hasCore) {
      if (usableMin <= 0) {
        statusColor = _red;
        statusLabel = 'BELOW RESERVE';
        statusIcon = Icons.error_outline;
      } else if (usableMin <= 15) {
        statusColor = _amber;
        statusLabel = 'MARGINAL RESERVE';
        statusIcon = Icons.warning_amber_rounded;
      } else {
        statusColor = _green;
        statusLabel = 'RESERVE OK';
        statusIcon = Icons.check_circle_outline;
      }
    }

    return _sectionCard(
      icon: Icons.calculate_outlined,
      accent: _cyan,
      title: 'FUEL CALCULATOR',
      children: [
        _numField(_totalFuelCtrl, 'Total usable fuel', 'gal'),
        const SizedBox(height: 10),
        _numField(_burnRateCtrl, 'Fuel burn rate', 'gph'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _numField(_reserveCtrl, 'Reserve', 'min'),
            ),
            const SizedBox(width: 8),
            _reservePreset('30', 'VFR DAY'),
            const SizedBox(width: 6),
            _reservePreset('45', 'VFR NIGHT'),
          ],
        ),
        const SizedBox(height: 10),
        _numField(_groundSpeedCtrl, 'Ground speed (for range)', 'kt'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _numField(_plannedTimeCtrl, 'Planned time', 'min')),
            const SizedBox(width: 8),
            Expanded(child: _numField(_plannedDistCtrl, 'Planned dist', 'nm')),
          ],
        ),
        const SizedBox(height: 16),

        // Reserve compliance indicator
        Semantics(
          container: true,
          liveRegion: true,
          label: 'Reserve status: $statusLabel',
          excludeSemantics: true,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    statusLabel,
                    style: AppType.condensed(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Results
        _resultRow('Total endurance', hasCore ? _fmtHM(enduranceMin) : '--:--',
            _cyan),
        _resultRow(
          'Reserve ($reserveMin min)',
          hasCore ? '${reserveGal.toStringAsFixed(1)} gal' : '--',
          _amber,
        ),
        _resultRow(
          'Usable to reserve',
          hasCore ? _fmtHM(usableMin) : '--:--',
          usableMin <= 0 && hasCore ? _red : _green,
        ),
        if (usableRangeNm != null)
          _resultRow('Max range (still air)',
              '${usableRangeNm.toStringAsFixed(0)} nm', _cyan),
        if (fuelForTimeGal != null)
          _resultRow(
            'Fuel for planned time',
            '${fuelForTimeGal.toStringAsFixed(1)} gal',
            overUsable ? _red : Sky.ink,
          ),
        if (timeForDistMin != null && fuelForDistGal != null) ...[
          _resultRow('Time for planned dist', _fmtHM(timeForDistMin), _cyan),
          _resultRow('Fuel for planned dist',
              '${fuelForDistGal.toStringAsFixed(1)} gal', Sky.ink),
        ],
        if (plannedDist != null && plannedDist > 0 && (gs == null || gs <= 0))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Enter ground speed to compute distance-based fuel.',
              style: AppType.sans(color: Sky.muted, fontSize: 11),
            ),
          ),

        // Over-endurance warning
        if (overUsable) ...[
          const SizedBox(height: 12),
          Semantics(
            container: true,
            liveRegion: true,
            child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _red),
            ),
            child: Row(
              children: [
                const Icon(Icons.dangerous_outlined, color: _red, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    overTotal
                        ? 'PLANNED TIME EXCEEDS TOTAL ENDURANCE — flight not possible with this fuel.'
                        : 'PLANNED TIME EXCEEDS USABLE (reserve-protected) ENDURANCE — would dip into reserves.',
                    style: AppType.sans(
                      color: _red,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),
        ],
      ],
    );
  }

  Widget _reservePreset(String value, String label) {
    final selected = _reserveCtrl.text.trim() == value;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: '$label reserve, $value minutes',
      excludeSemantics: true,
      child: GestureDetector(
      onTap: () => setState(() => _reserveCtrl.text = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _cyan.withValues(alpha: 0.2) : _bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? _cyan : Sky.line),
        ),
        child: Text(
          label,
          style: AppType.condensed(
            fontSize: 8,
            color: selected ? _cyan : Sky.muted,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. Tank timer
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTankTimerCard() {
    final intervalSeconds = _switchIntervalMinutes * 60;
    final double progress = intervalSeconds > 0
        ? (_currentTankSeconds / intervalSeconds).clamp(0.0, 1.0)
        : 0.0;
    final Color timerColor =
        _alertActive ? _red : (progress > 0.8 ? _amber : _cyan);

    return _sectionCard(
      icon: Icons.timer_outlined,
      accent: _cyan,
      title: 'TANK TIMER',
      children: [
        // SWITCH TANKS alert banner
        if (_alertActive)
          Semantics(
            container: true,
            liveRegion: true,
            label: 'Switch tanks. Interval reached on the '
                '${_leftActive ? 'left' : 'right'} tank',
            excludeSemantics: true,
            child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: _red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _red, width: 2),
            ),
            child: Column(
              children: [
                const Icon(Icons.swap_horiz, color: _red, size: 30),
                const SizedBox(height: 6),
                Text(
                  'SWITCH TANKS',
                  style: AppType.condensed(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _red,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Interval reached on ${_leftActive ? 'LEFT' : 'RIGHT'} tank',
                  style: AppType.sans(color: Sky.inkSoft, fontSize: 12),
                ),
              ],
            ),
          ),
          ),

        // Active tank + current elapsed
        Semantics(
          container: true,
          label: 'Active tank ${_leftActive ? 'left' : 'right'}, '
              '${_speakClock(_currentTankSeconds)} elapsed, '
              'switch every $_switchIntervalMinutes minutes',
          excludeSemantics: true,
          child: Center(
            child: Column(
              children: [
                Text(
                  'ACTIVE TANK',
                  style: AppType.condensed(
                    fontSize: 10,
                    color: Sky.muted,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _leftActive ? 'LEFT' : 'RIGHT',
                  style: AppType.condensed(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _amber,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _fmtHMS(_currentTankSeconds),
                  style: AppType.condensed(
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    color: timerColor,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'switch every $_switchIntervalMinutes min',
                  style: AppType.sans(color: Sky.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Progress toward switch interval
        Semantics(
          container: true,
          label: 'Progress to next tank switch',
          value: '${(progress * 100).round()} percent',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Sky.line,
              valueColor: AlwaysStoppedAnimation<Color>(timerColor),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Controls
        Row(
          children: [
            Expanded(
              child: _timerButton(
                _running ? 'PAUSE' : 'START',
                _running ? Icons.pause : Icons.play_arrow,
                _running ? _amber : _green,
                _running ? _pauseTimer : _startTimer,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _timerButton(
                'RESET',
                Icons.refresh,
                Sky.muted,
                _resetTimer,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: _timerButton(
            'SWITCH TANK',
            Icons.swap_horiz,
            _cyan,
            _switchTank,
          ),
        ),
        const SizedBox(height: 16),

        // Per-tank running totals
        Row(
          children: [
            Expanded(
              child: _tankTotalTile(
                'LEFT',
                _leftTotalSeconds + (_leftActive ? _currentTankSeconds : 0),
                _leftActive,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _tankTotalTile(
                'RIGHT',
                _rightTotalSeconds + (!_leftActive ? _currentTankSeconds : 0),
                !_leftActive,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Switch-interval preference stepper
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Sky.line),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Switch interval',
                  style:
                      AppType.sans(color: Sky.inkSoft, fontSize: 13),
                ),
              ),
              _stepButton(Icons.remove, 'Decrease switch interval', () {
                if (_switchIntervalMinutes > 5) {
                  setState(() => _switchIntervalMinutes -= 5);
                  _saveSwitchInterval();
                }
              }),
              Semantics(
                container: true,
                label: 'Switch interval $_switchIntervalMinutes minutes',
                excludeSemantics: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '$_switchIntervalMinutes min',
                    style: AppType.condensed(
                      color: _cyan,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              _stepButton(Icons.add, 'Increase switch interval', () {
                if (_switchIntervalMinutes < 120) {
                  setState(() => _switchIntervalMinutes += 5);
                  _saveSwitchInterval();
                }
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tankTotalTile(String label, int seconds, bool active) {
    return Semantics(
      container: true,
      label: '${label.toLowerCase()} tank total, ${_speakClock(seconds)}'
          '${active ? ', active' : ''}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: active ? _amber.withValues(alpha: 0.12) : _bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? _amber : Sky.line),
        ),
        child: Column(
          children: [
            Text(
              '$label TOTAL',
              style: AppType.condensed(
                fontSize: 9,
                color: active ? _amber : Sky.muted,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _fmtHMS(seconds),
              style: AppType.condensed(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Sky.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Speak an elapsed-seconds count as hours/minutes/seconds.
  static String _speakClock(int totalSeconds) {
    if (totalSeconds < 0) totalSeconds = 0;
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    return '$h hours $m minutes $s seconds';
  }

  Widget _timerButton(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.18),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withValues(alpha: 0.5)),
        ),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: AppType.condensed(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _stepButton(IconData icon, String label, VoidCallback onTap) {
    return Semantics(
      container: true,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _cyan.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _cyan, size: 18),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. Fuel cost estimate (manual entry)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildCostCard() {
    // Manual entry only: no fuel-price feed is wired, and the card says so.
    final price = _parse(_priceCtrl);
    final gallons = _parse(_costGallonsCtrl);
    double? total;
    if (price != null && price >= 0 && gallons != null && gallons >= 0) {
      total = price * gallons;
    }

    return _sectionCard(
      icon: Icons.attach_money,
      accent: _green,
      title: 'FUEL COST ESTIMATE',
      children: [
        Text(
          'Manual entry — no live price lookup.',
          style: AppType.sans(color: Sky.muted, fontSize: 11),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _numField(_priceCtrl, 'Fuel price', '\$/gal')),
            const SizedBox(width: 8),
            Expanded(child: _numField(_costGallonsCtrl, 'Gallons', 'gal')),
          ],
        ),
        const SizedBox(height: 16),
        Semantics(
          container: true,
          label: 'Estimated total fuel cost, '
              '${total != null ? '\$${total.toStringAsFixed(2)}' : 'not available'}',
          excludeSemantics: true,
          child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _green.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              Text(
                'ESTIMATED TOTAL',
                style: AppType.condensed(
                  fontSize: 10,
                  color: Sky.muted,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                total != null ? '\$${total.toStringAsFixed(2)}' : '\$--',
                style: AppType.condensed(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: _green,
                ),
              ),
            ],
          ),
        ),
        ),
      ],
    );
  }

  // ── Shared building blocks ─────────────────────────────────────────────────
  Widget _sectionCard({
    required IconData icon,
    required Color accent,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Sky.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Semantics(
              container: true,
              header: true,
              label: title,
              excludeSemantics: true,
              child: Row(
                children: [
                  Icon(icon, color: accent, size: 22),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: AppType.condensed(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: accent,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _numField(TextEditingController ctrl, String label, String suffix) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: AppType.sans(color: Sky.ink, fontSize: 14),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        suffixStyle: AppType.sans(color: Sky.muted, fontSize: 12),
        labelStyle: AppType.sans(color: Sky.muted, fontSize: 12),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        filled: true,
        fillColor: _bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Sky.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Sky.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _cyan),
        ),
      ),
    );
  }

  Widget _resultRow(String label, String value, Color valueColor) {
    return Semantics(
      container: true,
      label: '$label: ${_speakValue(value)}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: AppType.sans(color: Sky.inkSoft, fontSize: 13),
              ),
            ),
            Text(
              value,
              style: AppType.condensed(
                color: valueColor,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Turn a display value into something a screen reader can say.
  ///
  /// `--:--` / `--` are placeholders for "not computed yet", and an HH:MM
  /// clock string is read as a duration rather than a time of day.
  static String _speakValue(String value) {
    if (value == '--:--' || value == '--') return 'not available';
    final hm = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value);
    if (hm != null) {
      final h = int.parse(hm.group(1)!);
      final m = int.parse(hm.group(2)!);
      return '$h hours $m minutes';
    }
    return value;
  }
}
