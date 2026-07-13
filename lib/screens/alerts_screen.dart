import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../services/alert_service.dart';

/// PilotEnRoute — Alerts Center screen.
///
/// Two tabs: a colour-coded alert **Feed** (acknowledge / clear / filter) and a
/// **Rules** editor (per-category enable + threshold inputs). Owns its own
/// [AlertService] in State, so no provider registration or main.dart changes
/// are required.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with SingleTickerProviderStateMixin {
  // ── Palette (matches app conventions) ──────────────────────────────────────
  static const Color _bg = Color(0xFF0A1628);
  static const Color _card = Color(0xFF112240);
  static const Color _cyan = Color(0xFF00BCD4);
  static const Color _amber = Color(0xFFFFB300);
  static const Color _red = Color(0xFFF44336);
  static const Color _green = Color(0xFF4CAF50);

  late final TabController _tabController;
  final AlertService _service = AlertService();

  AlertCategory? _filter; // null = All

  // Threshold editors, keyed by category (only for rules with thresholds).
  final Map<AlertCategory, TextEditingController> _thresholdCtrls = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _service.addListener(_onServiceChanged);
    _service.init();
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    _service.dispose();
    _tabController.dispose();
    for (final c in _thresholdCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  // ── Severity styling ────────────────────────────────────────────────────────
  Color _severityColor(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.info:
        return _cyan;
      case AlertSeverity.caution:
        return _amber;
      case AlertSeverity.warning:
        return _red;
    }
  }

  IconData _severityIcon(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.info:
        return Icons.info_outline;
      case AlertSeverity.caution:
        return Icons.warning_amber_rounded;
      case AlertSeverity.warning:
        return Icons.error_outline;
    }
  }

  IconData _categoryIcon(AlertCategory c) {
    switch (c) {
      case AlertCategory.weather:
        return Icons.cloud_outlined;
      case AlertCategory.crosswind:
        return Icons.air;
      case AlertCategory.fuel:
        return Icons.local_gas_station_outlined;
      case AlertCategory.currency:
        return Icons.event_repeat;
      case AlertCategory.medical:
        return Icons.medical_services_outlined;
      case AlertCategory.notam:
        return Icons.campaign_outlined;
      case AlertCategory.checklist:
        return Icons.checklist_rtl;
      case AlertCategory.terrain:
        return Icons.terrain_outlined;
      case AlertCategory.traffic:
        return Icons.flight_outlined;
      case AlertCategory.airspace:
        return Icons.travel_explore_outlined;
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('ALERTS'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _cyan,
          labelStyle: GoogleFonts.orbitron(fontSize: 10, letterSpacing: 1),
          tabs: const [
            Tab(text: 'FEED'),
            Tab(text: 'RULES'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFeedTab(),
          _buildRulesTab(),
        ],
      ),
    );
  }

  // ── Feed tab ─────────────────────────────────────────────────────────────────
  Widget _buildFeedTab() {
    final items = _filter == null
        ? _service.feed
        : _service.feed.where((a) => a.category == _filter).toList();

    return Column(
      children: [
        _buildFeedToolbar(),
        Expanded(
          child: items.isEmpty
              ? _buildEmptyFeed()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  itemCount: items.length,
                  itemBuilder: (context, i) => _buildAlertCard(items[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildFeedToolbar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _runChecks,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: Text(
                    'RUN CHECKS NOW',
                    style: GoogleFonts.orbitron(
                        fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _cyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _toolbarIconButton(
                icon: Icons.done_all,
                tooltip: 'Acknowledge all',
                onPressed: _service.feed.isEmpty ? null : _service.acknowledgeAll,
              ),
              const SizedBox(width: 8),
              _toolbarIconButton(
                icon: Icons.delete_sweep_outlined,
                tooltip: 'Clear feed',
                onPressed: _service.feed.isEmpty ? null : _confirmClear,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildFilterChips(),
        ],
      ),
    );
  }

  Widget _toolbarIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, size: 20),
        color: Colors.white70,
        disabledColor: Colors.white24,
      ),
    );
  }

  Widget _buildFilterChips() {
    final chips = <Widget>[
      _filterChip('ALL', _filter == null, () => setState(() => _filter = null)),
    ];
    for (final c in AlertCategory.values) {
      chips.add(_filterChip(
        c.label.toUpperCase(),
        _filter == c,
        () => setState(() => _filter = c),
      ));
    }
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? _cyan.withValues(alpha: 0.18) : _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? _cyan : Colors.white12),
        ),
        child: Text(
          label,
          style: GoogleFonts.orbitron(
            fontSize: 9,
            letterSpacing: 1,
            color: selected ? _cyan : Colors.white54,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyFeed() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.notifications_off_outlined,
              color: Colors.white24, size: 48),
          const SizedBox(height: 12),
          Text(
            _filter == null
                ? 'No alerts yet'
                : 'No ${_filter!.label} alerts',
            style: GoogleFonts.orbitron(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap "Run checks now" to evaluate alerts',
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(AlertItem item) {
    final color = _severityColor(item.severity);
    final dimmed = item.acknowledged;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: dimmed ? Colors.white12 : color.withValues(alpha: 0.5),
        ),
      ),
      child: Opacity(
        opacity: dimmed ? 0.55 : 1,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_severityIcon(item.severity), color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _severityBadge(item.severity, color),
                        const SizedBox(width: 6),
                        Icon(_categoryIcon(item.category),
                            color: Colors.white38, size: 12),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.category.label.toUpperCase(),
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.orbitron(
                              fontSize: 8,
                              color: Colors.white38,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.title,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.message,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.white70, height: 1.3),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.schedule,
                            color: Colors.white38, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          _formatTime(item.timestamp),
                          style: GoogleFonts.inter(
                              fontSize: 10, color: Colors.white38),
                        ),
                        const Spacer(),
                        if (!item.acknowledged)
                          _cardAction(
                            icon: Icons.check,
                            color: _green,
                            tooltip: 'Acknowledge',
                            onTap: () => _service.acknowledge(item.id),
                          ),
                        if (item.acknowledged)
                          Text(
                            'ACK',
                            style: GoogleFonts.orbitron(
                                fontSize: 8,
                                color: _green,
                                letterSpacing: 1),
                          ),
                        const SizedBox(width: 4),
                        _cardAction(
                          icon: Icons.close,
                          color: Colors.white38,
                          tooltip: 'Dismiss',
                          onTap: () => _service.removeAlert(item.id),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _severityBadge(AlertSeverity severity, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        severity.label,
        style: GoogleFonts.orbitron(
            fontSize: 8, color: color, letterSpacing: 1, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _cardAction({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  // ── Rules tab ────────────────────────────────────────────────────────────────
  Widget _buildRulesTab() {
    final rules = _service.rules;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              const Icon(Icons.tune, color: _cyan, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Enable categories and set thresholds. Warning-severity alerts '
                  'also fire a device notification.',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
        ...rules.map(_buildRuleCard),
      ],
    );
  }

  Widget _buildRuleCard(AlertRule rule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
        child: Column(
          children: [
            Row(
              children: [
                Icon(_categoryIcon(rule.category),
                    color: rule.enabled ? _cyan : Colors.white38, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    rule.category.label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: rule.enabled ? Colors.white : Colors.white54,
                    ),
                  ),
                ),
                Switch(
                  value: rule.enabled,
                  activeThumbColor: _cyan,
                  onChanged: (v) =>
                      _service.setRuleEnabled(rule.category, v),
                ),
              ],
            ),
            if (rule.enabled && rule.hasThreshold) _buildThresholdEditor(rule),
          ],
        ),
      ),
    );
  }

  Widget _buildThresholdEditor(AlertRule rule) {
    final String label;
    final String suffix;
    final String current;
    switch (rule.category) {
      case AlertCategory.crosswind:
        label = 'Crosswind limit';
        suffix = 'kt';
        current = (rule.crosswindLimitKts ?? 20).toStringAsFixed(0);
      case AlertCategory.fuel:
        label = 'Reserve fuel';
        suffix = 'min';
        current = (rule.fuelReserveMinutes ?? 45).toString();
      case AlertCategory.currency:
      case AlertCategory.medical:
        label = 'Alert before expiry';
        suffix = 'days';
        current = (rule.daysBeforeExpiry ?? 30).toString();
      default:
        return const SizedBox.shrink();
    }

    final ctrl = _thresholdCtrls.putIfAbsent(
      rule.category,
      () => TextEditingController(text: current),
    );
    // Keep controller in sync if it lost focus and the value changed elsewhere.
    if (ctrl.text.isEmpty) ctrl.text = current;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 8, 10),
      child: Row(
        children: [
          const SizedBox(width: 32),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
            ),
          ),
          SizedBox(
            width: 76,
            child: TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                filled: true,
                fillColor: _bg,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _cyan),
                ),
              ),
              onSubmitted: (v) => _commitThreshold(rule, v),
              onEditingComplete: () => _commitThreshold(rule, ctrl.text),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 32,
            child: Text(
              suffix,
              style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
            ),
          ),
        ],
      ),
    );
  }

  void _commitThreshold(AlertRule rule, String raw) {
    final value = double.tryParse(raw.trim());
    if (value == null || value < 0) {
      _snack('Enter a valid number');
      return;
    }
    switch (rule.category) {
      case AlertCategory.crosswind:
        _service.updateRule(rule.copyWith(crosswindLimitKts: value));
      case AlertCategory.fuel:
        _service.updateRule(rule.copyWith(fuelReserveMinutes: value.round()));
      case AlertCategory.currency:
      case AlertCategory.medical:
        _service.updateRule(rule.copyWith(daysBeforeExpiry: value.round()));
      default:
        break;
    }
    FocusScope.of(context).unfocus();
  }

  // ── Actions ──────────────────────────────────────────────────────────────────
  Future<void> _runChecks() async {
    final count = await _service.runChecksNow();
    if (!mounted) return;
    _snack(count == 0
        ? 'No alerts raised (all categories disabled?)'
        : '$count alert${count == 1 ? '' : 's'} added to feed');
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: Text('Clear feed?',
            style: GoogleFonts.orbitron(color: Colors.white, fontSize: 14)),
        content: Text('This removes all alerts from the feed.',
            style: GoogleFonts.inter(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('CANCEL',
                style: GoogleFonts.orbitron(color: Colors.white54, fontSize: 10)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('CLEAR',
                style: GoogleFonts.orbitron(color: _red, fontSize: 10)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.clearFeed();
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: _card,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    try {
      return DateFormat('MMM d, HH:mm').format(t);
    } catch (_) {
      return t.toIso8601String();
    }
  }
}
