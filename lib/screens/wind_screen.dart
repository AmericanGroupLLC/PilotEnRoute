import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// A Windy-style wind & weather visualization screen.
///
/// Loads the FREE Windy embed (embed.windy.com) inside an in-app WebView and
/// lets the user switch overlays (wind, gusts, radar, clouds, temperature,
/// isobars, waves) and altitude levels (surface up to 300hPa / ~30kft) by
/// rebuilding the embed URL and reloading the WebView.
class WindScreen extends StatefulWidget {
  const WindScreen({super.key});

  @override
  State<WindScreen> createState() => _WindScreenState();
}

class _WindScreenState extends State<WindScreen> {
  static const Color _bg = Color(0xFF0A1628);
  static const Color _cyan = Color(0xFF00BCD4);
  static const Color _chipUnselected = Color(0xFF112240);

  // Overlay options: label -> Windy `overlay=` value.
  static const List<_Option> _overlays = <_Option>[
    _Option('Wind', 'wind'),
    _Option('Gusts', 'gust'),
    _Option('Radar', 'radar'),
    _Option('Clouds', 'clouds'),
    _Option('Temperature', 'temp'),
    _Option('Pressure/Isobars', 'pressure'),
    _Option('Waves/Ocean', 'waves'),
  ];

  // Level options: label -> Windy `level=` value.
  static const List<_Option> _levels = <_Option>[
    _Option('Surface', 'surface'),
    _Option('850hPa (~5kft)', '850h'),
    _Option('700hPa (~10kft)', '700h'),
    _Option('500hPa (~18kft)', '500h'),
    _Option('300hPa (~30kft)', '300h'),
  ];

  late final WebViewController _controller;
  String _overlay = 'wind';
  String _level = 'surface';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(_buildUri());
  }

  Uri _buildUri() {
    return Uri.parse(
      'https://embed.windy.com/embed2.html'
      '?lat=37.5&lon=-122.3&detailLat=37.5&detailLon=-122.3'
      '&zoom=5&level=$_level&overlay=$_overlay&product=ecmwf'
      '&menu=&message=&marker=&calendar=&pressure=&type=map'
      '&location=coordinates&detail='
      '&metricWind=kt&metricTemp=%C2%B0F&radarRange=-1',
    );
  }

  void _reload() {
    if (!mounted) return;
    setState(() => _isLoading = true);
    _controller.loadRequest(_buildUri());
  }

  void _selectOverlay(String value) {
    if (_overlay == value) return;
    setState(() => _overlay = value);
    _reload();
  }

  void _selectLevel(String value) {
    if (_level == value) return;
    setState(() => _level = value);
    _reload();
  }

  Future<void> _openInWindy() async {
    final Uri uri = Uri.parse('https://www.windy.com');
    try {
      final bool ok =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Windy.com')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Windy.com')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        title: const Text('WIND & WEATHER'),
        titleTextStyle: GoogleFonts.orbitron(
          fontSize: 14,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Open in Windy',
            icon: const Icon(Icons.open_in_new, color: _cyan),
            onPressed: _openInWindy,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _buildControls(),
          Expanded(
            child: Stack(
              children: <Widget>[
                WebViewWidget(controller: _controller),
                if (_isLoading)
                  const ColoredBox(
                    color: _bg,
                    child: Center(
                      child: CircularProgressIndicator(color: _cyan),
                    ),
                  ),
              ],
            ),
          ),
          _buildCaption(),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      color: _bg,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildLabel('OVERLAY'),
          _buildChipRow(_overlays, _overlay, _selectOverlay),
          const SizedBox(height: 4),
          _buildLabel('WINDS ALOFT'),
          _buildChipRow(_levels, _level, _selectLevel),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
      child: Text(
        text,
        style: GoogleFonts.orbitron(
          fontSize: 9,
          letterSpacing: 1.5,
          color: _cyan,
        ),
      ),
    );
  }

  Widget _buildChipRow(
    List<_Option> options,
    String selected,
    void Function(String) onSelect,
  ) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final _Option option = options[index];
          final bool isSelected = option.value == selected;
          return GestureDetector(
            onTap: () => onSelect(option.value),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isSelected ? _cyan : _chipUnselected,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected ? _cyan : _cyan.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                option.label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? _bg : Colors.white70,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCaption() {
    return Container(
      width: double.infinity,
      color: _bg,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Text(
        'Live wind/weather via Windy.com embed (free) — animated winds, '
        'gusts, winds aloft, isobars, jet stream.',
        style: GoogleFonts.inter(
          fontSize: 10,
          color: Colors.white54,
          height: 1.3,
        ),
      ),
    );
  }
}

/// A simple label/value pair for a control chip.
class _Option {
  const _Option(this.label, this.value);

  final String label;
  final String value;
}
