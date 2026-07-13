import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/integrations_service.dart';

/// Integrations hub screen.
///
/// Groups integrations by category, shows an honest connection status pill for
/// each, and offers real export actions for the Data Import/Export section.
/// The service is owned locally in State (no global provider registration
/// required).
class IntegrationsScreen extends StatefulWidget {
  const IntegrationsScreen({super.key});

  @override
  State<IntegrationsScreen> createState() => _IntegrationsScreenState();
}

class _IntegrationsScreenState extends State<IntegrationsScreen> {
  static const Color _bg = Color(0xFF0A1628);
  static const Color _card = Color(0xFF112240);
  static const Color _cyan = Color(0xFF00BCD4);
  static const Color _amber = Color(0xFFFFB300);
  static const Color _red = Color(0xFFF44336);
  static const Color _green = Color(0xFF4CAF50);

  final IntegrationsService _service = IntegrationsService();

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceChanged);
    _service.load();
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    _service.dispose();
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  IconData _categoryIcon(IntegrationCategory c) {
    switch (c) {
      case IntegrationCategory.adsbReceiver:
        return Icons.settings_input_antenna;
      case IntegrationCategory.avionics:
        return Icons.dashboard;
      case IntegrationCategory.simulator:
        return Icons.videogame_asset;
      case IntegrationCategory.wearable:
        return Icons.watch;
      case IntegrationCategory.dataImportExport:
        return Icons.import_export;
    }
  }

  Color _categoryColor(IntegrationCategory c) {
    switch (c) {
      case IntegrationCategory.adsbReceiver:
        return _cyan;
      case IntegrationCategory.avionics:
        return _amber;
      case IntegrationCategory.simulator:
        return const Color(0xFF9C27B0);
      case IntegrationCategory.wearable:
        return const Color(0xFF2196F3);
      case IntegrationCategory.dataImportExport:
        return _green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('INTEGRATIONS'),
        backgroundColor: _bg,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildIntro(),
          const SizedBox(height: 12),
          for (final category in IntegrationCategory.values)
            ..._buildCategorySection(category),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildIntro() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.hub, color: _cyan, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONNECTIONS HUB',
                  style: GoogleFonts.orbitron(
                    fontSize: 12,
                    color: _cyan,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Connect ADS-B receivers, avionics, simulators and wearables. '
                  'Hardware links are not wired yet — statuses shown here are '
                  'honest. Data export works today.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCategorySection(IntegrationCategory category) {
    final items = _service.byCategory(category);
    if (items.isEmpty) return const [];
    final color = _categoryColor(category);
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Row(
          children: [
            Icon(_categoryIcon(category), color: color, size: 16),
            const SizedBox(width: 8),
            Text(
              category.label.toUpperCase(),
              style: GoogleFonts.orbitron(
                fontSize: 11,
                color: color,
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      for (final item in items) _buildIntegrationCard(item),
    ];
  }

  Widget _buildIntegrationCard(Integration item) {
    final color = _categoryColor(item.category);
    final isData = item.category == IntegrationCategory.dataImportExport;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_categoryIcon(item.category), color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.vendor,
                      style: GoogleFonts.orbitron(
                        fontSize: 9,
                        color: Colors.white38,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusPill(item),
            ],
          ),
          const SizedBox(height: 12),
          if (isData)
            _buildDataActions(item)
          else
            _buildHardwareActions(item),
        ],
      ),
    );
  }

  Widget _buildStatusPill(Integration item) {
    final connected = item.connected;
    final color = connected ? _green : Colors.white38;
    final label = connected ? 'Connected' : 'Not configured';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: connected ? _green : Colors.white54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHardwareActions(Integration item) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showDetailsSheet(item),
            icon: const Icon(Icons.info_outline, size: 16),
            label: Text(
              'Details',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _attemptConnect(item),
            icon: const Icon(Icons.link, size: 16),
            label: Text(
              'Connect',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _categoryColor(item.category).withValues(alpha: 0.2),
              foregroundColor: _categoryColor(item.category),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataActions(Integration item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _exportText(item),
                icon: const Icon(Icons.description_outlined, size: 16),
                label: Text(
                  'Export plans',
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green.withValues(alpha: 0.2),
                  foregroundColor: _green,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _exportGpx(item),
                icon: const Icon(Icons.route, size: 16),
                label: Text(
                  'Export GPX',
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => _showDetailsSheet(item),
          icon: const Icon(Icons.info_outline, size: 14, color: Colors.white38),
          label: Text(
            'Import & live sync info',
            style: GoogleFonts.inter(fontSize: 11, color: Colors.white54),
          ),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
            minimumSize: const Size(0, 28),
          ),
        ),
      ],
    );
  }

  Future<void> _attemptConnect(Integration item) async {
    final ok = await _service.connect(item.id);
    if (!mounted) return;
    if (ok) {
      _showSnack('Connected to ${item.name}', _green);
    } else {
      // Honest: not a fake success. Explain why and how to enable.
      _showDetailsSheet(item, connectFailed: true);
    }
  }

  Future<void> _exportText(Integration item) async {
    final adapter = _service.dataAdapter;
    if (adapter == null) return;
    final result = await adapter.exportFlightPlans();
    if (!mounted) return;
    if (result.success && result.content != null) {
      _showExportResult('Flight Plan Export', result.content!, result.message);
    } else {
      _showSnack(result.message, _amber);
    }
  }

  Future<void> _exportGpx(Integration item) async {
    final adapter = _service.dataAdapter;
    if (adapter == null) return;
    final result = await adapter.exportGpxRoutes();
    if (!mounted) return;
    if (result.success && result.content != null) {
      _showExportResult('GPX Route Export', result.content!, result.message);
    } else {
      _showSnack(result.message, _amber);
    }
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(fontSize: 13)),
        backgroundColor: _card,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: color.withValues(alpha: 0.5)),
        ),
      ),
    );
  }

  void _showExportResult(String title, String content, String message) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.3,
          builder: (ctx, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: _green, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.orbitron(
                            fontSize: 13,
                            color: _green,
                            letterSpacing: 1,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).maybePop(),
                        icon: const Icon(Icons.close, color: Colors.white54),
                      ),
                    ],
                  ),
                  Text(
                    message,
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _bg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: SingleChildScrollView(
                        controller: scrollController,
                        child: SelectableText(
                          content,
                          style: GoogleFonts.robotoMono(
                            fontSize: 11,
                            color: Colors.white70,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final navigator = Navigator.of(ctx);
                        await Clipboard.setData(ClipboardData(text: content));
                        navigator.maybePop();
                        if (!mounted) return;
                        _showSnack('Copied to clipboard', _green);
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: Text(
                        'Copy to clipboard',
                        style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _cyan.withValues(alpha: 0.2),
                        foregroundColor: _cyan,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDetailsSheet(Integration item, {bool connectFailed = false}) {
    final color = _categoryColor(item.category);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_categoryIcon(item.category),
                          color: color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${item.vendor} · ${item.category.label}',
                            style: GoogleFonts.orbitron(
                              fontSize: 9,
                              color: Colors.white38,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (connectFailed)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: _red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _red.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline, color: _red, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Not connected. This integration is not wired up '
                            'yet — no fake connection was made.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white70,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(
                  'WHAT\'S NEEDED',
                  style: GoogleFonts.orbitron(
                    fontSize: 10,
                    color: _amber,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.requirement,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                if (item.vendorUrl != null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _launchVendor(item.vendorUrl!),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: Text(
                        'Learn more',
                        style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color.withValues(alpha: 0.2),
                        foregroundColor: color,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _launchVendor(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        _showSnack('Could not open link', _amber);
      }
    } catch (_) {
      if (!mounted) return;
      _showSnack('Could not open link', _amber);
    }
  }
}
