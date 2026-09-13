import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RegulationsScreen — free, official FAR (14 CFR) & AIM browser.
//
// Everything is served live from eCFR.gov and FAA.gov (both free & official)
// inside an in-app WebView. No API keys, no paywall, no bundled copyright text.
//
// TODO(regs): add offline caching of fetched regulation text for offline study.
// ─────────────────────────────────────────────────────────────────────────────

const _kBg = Color(0xFF0A1628);
const _kCard = Color(0xFF112240);
const _kCyan = Color(0xFF00BCD4);
const _kAmber = Color(0xFFFFB300);

/// A single regulation quick-link / bookmark entry.
class _RegLink {
  const _RegLink({
    required this.title,
    required this.subtitle,
    required this.url,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final String url;
  final IconData icon;
  final Color color;
}

const List<_RegLink> _kQuickLinks = [
  _RegLink(
    title: 'FAR Part 61',
    subtitle: 'Certification: Pilots, Instructors',
    url:
        'https://www.ecfr.gov/current/title-14/chapter-I/subchapter-D/part-61',
    icon: Icons.badge,
    color: _kCyan,
  ),
  _RegLink(
    title: 'FAR Part 91',
    subtitle: 'General Operating & Flight Rules',
    url:
        'https://www.ecfr.gov/current/title-14/chapter-I/subchapter-F/part-91',
    icon: Icons.flight,
    color: Color(0xFF4CAF50),
  ),
  _RegLink(
    title: 'FAR Part 141',
    subtitle: 'Pilot Schools',
    url:
        'https://www.ecfr.gov/current/title-14/chapter-I/subchapter-H/part-141',
    icon: Icons.school,
    color: Color(0xFF9C27B0),
  ),
  _RegLink(
    title: 'FAR Part 107',
    subtitle: 'Small Unmanned Aircraft (Drones)',
    url:
        'https://www.ecfr.gov/current/title-14/chapter-I/subchapter-F/part-107',
    icon: Icons.flight_takeoff,
    color: Color(0xFFFF9800),
  ),
  _RegLink(
    title: 'Full Title 14',
    subtitle: 'Aeronautics & Space (all parts)',
    url: 'https://www.ecfr.gov/current/title-14',
    icon: Icons.menu_book,
    color: _kAmber,
  ),
  _RegLink(
    title: 'AIM',
    subtitle: 'Aeronautical Information Manual',
    url:
        'https://www.faa.gov/air_traffic/publications/atpubs/aim_html/',
    icon: Icons.import_contacts,
    color: Color(0xFF2196F3),
  ),
];

class RegulationsScreen extends StatefulWidget {
  const RegulationsScreen({super.key});

  @override
  State<RegulationsScreen> createState() => _RegulationsScreenState();
}

class _RegulationsScreenState extends State<RegulationsScreen> {
  static const String _kBookmarksKey = 'far_bookmarks';

  final TextEditingController _searchController = TextEditingController();
  List<_RegLink> _bookmarks = [];
  bool _loadingBookmarks = true;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_kBookmarksKey) ?? const [];
      final parsed = <_RegLink>[];
      for (final entry in raw) {
        try {
          final map = jsonDecode(entry) as Map<String, dynamic>;
          final title = (map['title'] as String?)?.trim() ?? '';
          final url = (map['url'] as String?)?.trim() ?? '';
          if (title.isEmpty || url.isEmpty) continue;
          parsed.add(_RegLink(
            title: title,
            subtitle: (map['subtitle'] as String?) ?? url,
            url: url,
            icon: Icons.bookmark,
            color: _kAmber,
          ));
        } catch (_) {
          // Skip malformed entries — never crash on bad stored data.
        }
      }
      if (!mounted) return;
      setState(() {
        _bookmarks = parsed;
        _loadingBookmarks = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingBookmarks = false);
    }
  }

  Future<void> _persistBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = _bookmarks
          .map((b) => jsonEncode({
                'title': b.title,
                'subtitle': b.subtitle,
                'url': b.url,
              }))
          .toList();
      await prefs.setStringList(_kBookmarksKey, raw);
    } catch (_) {
      // Best-effort persistence; a failed write should never crash the UI.
    }
  }

  Future<void> _addBookmark(String title, String subtitle, String url) async {
    if (url.trim().isEmpty) return;
    if (_bookmarks.any((b) => b.url == url)) {
      _showSnack('Already bookmarked');
      return;
    }
    setState(() {
      _bookmarks = [
        ..._bookmarks,
        _RegLink(
          title: title.isEmpty ? url : title,
          subtitle: subtitle.isEmpty ? url : subtitle,
          url: url,
          icon: Icons.bookmark,
          color: _kAmber,
        ),
      ];
    });
    await _persistBookmarks();
    _showSnack('Bookmarked');
  }

  Future<void> _removeBookmark(_RegLink bookmark) async {
    setState(() {
      _bookmarks = _bookmarks.where((b) => b.url != bookmark.url).toList();
    });
    await _persistBookmarks();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(fontSize: 13)),
        backgroundColor: _kCard,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openViewer(String title, String url) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _RegulationViewer(
          title: title,
          url: url,
          onBookmark: (t, u) => _addBookmark(t, t, u),
        ),
      ),
    );
  }

  void _runSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    final encoded = Uri.encodeQueryComponent(query);
    final url =
        'https://www.ecfr.gov/search?query=$encoded&date=current&hierarchy%5Btitle%5D=14';
    FocusScope.of(context).unfocus();
    _openViewer('Search: $query', url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('REGULATIONS'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildSearchBox(),
          const SizedBox(height: 16),
          _buildSectionHeader('QUICK JUMP', _kCyan),
          const SizedBox(height: 10),
          ..._kQuickLinks.map((link) => _buildLinkCard(
                link,
                onTap: () => _openViewer(link.title, link.url),
                onBookmark: () =>
                    _addBookmark(link.title, link.subtitle, link.url),
              )),
          const SizedBox(height: 20),
          _buildSectionHeader('BOOKMARKS', _kAmber),
          const SizedBox(height: 10),
          _buildBookmarks(),
          const SizedBox(height: 20),
          _buildDisclaimer(),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.search, color: _kCyan, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _runSearch(),
              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
              cursorColor: _kCyan,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Search 14 CFR on eCFR.gov…',
                hintStyle:
                    GoogleFonts.inter(color: Colors.white38, fontSize: 14),
              ),
            ),
          ),
          TextButton(
            onPressed: _runSearch,
            child: Text(
              'GO',
              style: GoogleFonts.orbitron(
                color: _kCyan,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String text, Color color) {
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

  Widget _buildLinkCard(
    _RegLink link, {
    required VoidCallback onTap,
    required VoidCallback onBookmark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: link.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(link.icon, color: link.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        link.title,
                        style: GoogleFonts.orbitron(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        link.subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white54,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Bookmark',
                  onPressed: onBookmark,
                  icon: const Icon(Icons.bookmark_add_outlined,
                      color: Colors.white38, size: 20),
                ),
                const Icon(Icons.chevron_right, color: Colors.white24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookmarks() {
    if (_loadingBookmarks) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(color: _kAmber)),
      );
    }
    if (_bookmarks.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          children: [
            const Icon(Icons.bookmark_border, color: Colors.white24, size: 28),
            const SizedBox(height: 8),
            Text(
              'No bookmarks yet',
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap the bookmark icon on any regulation, or use the bookmark button while reading.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      );
    }
    return Column(
      children: _bookmarks
          .map((b) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _openViewer(b.title, b.url),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.bookmark, color: _kAmber, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  b.url,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: Colors.white38,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Delete bookmark',
                            onPressed: () => _removeBookmark(b),
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.white38, size: 20),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kAmber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kAmber.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: _kAmber, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Live from eCFR.gov / FAA.gov (free, official). An internet '
              'connection is required — regulation text is not stored on '
              'the device for offline study.',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.white70,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RegulationViewer — in-app WebView showing one regulation / search result.
// ─────────────────────────────────────────────────────────────────────────────

class _RegulationViewer extends StatefulWidget {
  const _RegulationViewer({
    required this.title,
    required this.url,
    required this.onBookmark,
  });

  final String title;
  final String url;
  final void Function(String title, String url) onBookmark;

  @override
  State<_RegulationViewer> createState() => _RegulationViewerState();
}

class _RegulationViewerState extends State<_RegulationViewer> {
  late final WebViewController _controller;
  bool _loading = true;
  String _currentUrl = '';

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(_kBg)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _currentUrl = url;
            });
          },
          onPageFinished: (url) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _currentUrl = url;
            });
          },
          onWebResourceError: (_) {
            if (!mounted) return;
            setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _openInBrowser() async {
    final target = _currentUrl.isNotEmpty ? _currentUrl : widget.url;
    final uri = Uri.tryParse(target);
    if (uri == null) {
      _showSnack('Invalid URL');
      return;
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) _showSnack('Could not open browser');
    } catch (_) {
      _showSnack('Could not open browser');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(fontSize: 13)),
        backgroundColor: _kCard,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.orbitron(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Bookmark this page',
            icon: const Icon(Icons.bookmark_add_outlined),
            onPressed: () {
              final target =
                  _currentUrl.isNotEmpty ? _currentUrl : widget.url;
              widget.onBookmark(widget.title, target);
              _showSnack('Bookmarked');
            },
          ),
          IconButton(
            tooltip: 'Reload',
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
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
