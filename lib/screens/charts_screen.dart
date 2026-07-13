import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/chart_service.dart';

// Charts & Plates browser — free FAA plates via aviationapi.com (US only).
//
// TODO(charts): geo-referenced overlay on the moving map requires a licensed
// chart provider; this is the free PDF/plate viewer.

const _kBg = Color(0xFF0A1628);
const _kCard = Color(0xFF112240);
const _kCyan = Color(0xFF00BCD4);
const _kAmber = Color(0xFFFFB300);
const _kGreen = Color(0xFF4CAF50);

class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key});

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  final ChartService _service = ChartService();
  final TextEditingController _controller = TextEditingController();

  Map<String, List<ChartDoc>> _results = const {};
  String _resultsFor = '';

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceChanged);
    _service.loadRecent();
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    _service.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _search([String? icao]) async {
    final code = (icao ?? _controller.text).trim().toUpperCase();
    if (code.isEmpty) return;
    FocusScope.of(context).unfocus();
    _controller.text = code;
    final grouped = await _service.fetchCharts(code);
    if (!mounted) return;
    setState(() {
      _results = grouped;
      _resultsFor = grouped.isEmpty ? '' : code;
    });
  }

  void _openChart(ChartDoc doc) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ChartViewerScreen(doc: doc),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('CHARTS'),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildRecentChips(),
          Expanded(child: _buildBody()),
          _buildCaption(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Airport ICAO (e.g. KLAX)',
                hintStyle: GoogleFonts.inter(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white38),
                filled: true,
                fillColor: _kCard,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kCyan),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _service.isLoading ? null : () => _search(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kCyan,
                foregroundColor: _kBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'FIND',
                style: GoogleFonts.orbitron(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentChips() {
    final recent = _service.recent;
    if (recent.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: recent.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Center(
              child: Text(
                'RECENT',
                style: GoogleFonts.orbitron(
                  fontSize: 9,
                  color: Colors.white38,
                  letterSpacing: 1.5,
                ),
              ),
            );
          }
          final code = recent[i - 1];
          return Center(
            child: ActionChip(
              backgroundColor: _kCard,
              side: const BorderSide(color: Colors.white12),
              label: Text(
                code,
                style: GoogleFonts.orbitron(
                  fontSize: 10,
                  color: _kCyan,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () => _search(code),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_service.isLoading) {
      return const Center(child: CircularProgressIndicator(color: _kCyan));
    }

    final error = _service.error;
    if (error != null) {
      return _buildMessage(Icons.error_outline, error, _kAmber);
    }

    if (_results.isEmpty) {
      return _buildMessage(
        Icons.map_outlined,
        'Search an airport to browse its FAA charts and plates.',
        Colors.white38,
      );
    }

    final categories = _results.keys.toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      itemCount: categories.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) return _buildResultsHeader();
        final category = categories[i - 1];
        return _buildCategorySection(category, _results[category]!);
      },
    );
  }

  Widget _buildResultsHeader() {
    final total = _results.values.fold<int>(0, (sum, l) => sum + l.length);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        '$_resultsFor · $total CHARTS',
        style: GoogleFonts.orbitron(
          fontSize: 11,
          color: _kCyan,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildCategorySection(String category, List<ChartDoc> docs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ExpansionTile(
          initiallyExpanded: category == 'Airport Diagram',
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          iconColor: _kCyan,
          collapsedIconColor: Colors.white38,
          title: Text(
            category,
            style: GoogleFonts.orbitron(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          subtitle: Text(
            '${docs.length} chart${docs.length == 1 ? '' : 's'}',
            style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
          ),
          children: docs.map(_buildChartRow).toList(),
        ),
      ),
    );
  }

  Widget _buildChartRow(ChartDoc doc) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: const Icon(Icons.description, color: _kGreen, size: 20),
      title: Text(
        doc.name,
        style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
      ),
      subtitle: doc.code.isEmpty
          ? null
          : Text(
              doc.code,
              style: GoogleFonts.orbitron(
                fontSize: 9,
                color: Colors.white38,
                letterSpacing: 1,
              ),
            ),
      trailing: const Icon(Icons.chevron_right, color: Colors.white38),
      onTap: () => _openChart(doc),
    );
  }

  Widget _buildMessage(IconData icon, String message, Color color) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white54,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaption() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: _kBg,
      child: Text(
        'FAA charts via aviationapi.com (free) — US only.',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(fontSize: 10, color: Colors.white30),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// In-app PDF/plate viewer. Many FAA PDFs render directly in the WebView; when
// they do not, the user can fall back to the system browser via url_launcher.
// ─────────────────────────────────────────────────────────────────────────────

class _ChartViewerScreen extends StatefulWidget {
  const _ChartViewerScreen({required this.doc});

  final ChartDoc doc;

  @override
  State<_ChartViewerScreen> createState() => _ChartViewerScreenState();
}

class _ChartViewerScreenState extends State<_ChartViewerScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.doc.pdfUrl));
  }

  Future<void> _openInBrowser() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final uri = Uri.parse(widget.doc.pdfUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not open the chart.')),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the chart.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: Text(
          widget.doc.name,
          style: GoogleFonts.orbitron(fontSize: 13, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Open in browser',
            icon: const Icon(Icons.open_in_new),
            onPressed: _openInBrowser,
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(child: CircularProgressIndicator(color: _kCyan)),
        ],
      ),
    );
  }
}
