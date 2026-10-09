import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/notam_service.dart';

class NotamScreen extends StatefulWidget {
  const NotamScreen({super.key});

  @override
  State<NotamScreen> createState() => _NotamScreenState();
}

class _NotamScreenState extends State<NotamScreen> {
  final NotamService _service = NotamService();
  final TextEditingController _controller = TextEditingController();

  NotamCategory? _activeFilter;
  bool _hasSearched = false;

  static const List<String> _popularAirports = [
    'KJFK', 'KLAX', 'KORD', 'KATL', 'KDFW',
    'KSFO', 'KDEN', 'KLAS', 'KMIA', 'KBOS',
  ];

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceChanged);
    _restoreLast();
  }

  Future<void> _restoreLast() async {
    final last = await _service.loadLastIcao();
    if (!mounted) return;
    if (last != null && last.isNotEmpty) {
      _controller.text = last;
      _search(last);
    }
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    _service.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _hasSearched = true);
    await _service.fetchByAirport(trimmed);
  }

  Future<void> _refresh() async {
    if (_service.lastQuery.isEmpty) return;
    await _service.fetchByAirport(_service.lastQuery);
  }

  List<Notam> get _visibleNotams {
    final all = _service.notams;
    if (_activeFilter == null) return all;
    return all.where((n) => n.category == _activeFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(title: const Text('NOTAMS')),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildPopularAirports(),
          if (_hasSearched && _service.notams.isNotEmpty) _buildFilterChips(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF0D1B2A),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: GoogleFonts.orbitron(
                color: Colors.white,
                fontSize: 14,
                letterSpacing: 3,
              ),
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Airport ICAO (e.g. KJFK)',
                prefixIcon:
                    const Icon(Icons.campaign, color: Color(0xFF00BCD4)),
                hintStyle:
                    GoogleFonts.inter(color: Colors.white38, fontSize: 13),
              ),
              onSubmitted: _search,
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () => _search(_controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00BCD4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            child: const Icon(Icons.search, color: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularAirports() {
    return Container(
      height: 44,
      color: const Color(0xFF0D1B2A),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: _popularAirports.length,
        itemBuilder: (context, i) {
          return GestureDetector(
            onTap: () {
              _controller.text = _popularAirports[i];
              _search(_popularAirports[i]);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF112240),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                _popularAirports[i],
                style: GoogleFonts.orbitron(
                  fontSize: 10,
                  color: Colors.white70,
                  letterSpacing: 1,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    const categories = NotamCategory.values;
    return Container(
      height: 48,
      color: const Color(0xFF0A1628),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _filterChip('ALL', null),
          for (final c in categories) _filterChip(c.label, c),
        ],
      ),
    );
  }

  Widget _filterChip(String label, NotamCategory? category) {
    final selected = _activeFilter == category;
    final accent = category?.color ?? const Color(0xFF00BCD4);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _activeFilter = category),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.2)
                : const Color(0xFF112240),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? accent : Colors.white12,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.orbitron(
              fontSize: 10,
              color: selected ? accent : Colors.white54,
              letterSpacing: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_service.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00BCD4)),
      );
    }

    if (!_hasSearched) {
      return _buildPlaceholder(
        icon: Icons.campaign_outlined,
        title: 'Search NOTAMs',
        subtitle: 'Enter an airport ICAO code to view active notices.',
      );
    }

    if (_service.error != null) {
      return _buildPlaceholder(
        icon: Icons.error_outline,
        title: 'NOTAMs unavailable',
        subtitle: _service.error!,
        iconColor: const Color(0xFFF44336),
      );
    }

    final list = _visibleNotams;
    if (list.isEmpty) {
      return RefreshIndicator(
        color: const Color(0xFF00BCD4),
        backgroundColor: const Color(0xFF112240),
        onRefresh: _refresh,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            _buildPlaceholder(
              icon: Icons.check_circle_outline,
              title: 'No NOTAMs',
              subtitle: _activeFilter == null
                  ? 'No active notices for ${_service.lastQuery}.'
                  : 'No ${_activeFilter!.label} notices for ${_service.lastQuery}.',
              iconColor: const Color(0xFF4CAF50),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF00BCD4),
      backgroundColor: const Color(0xFF112240),
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (context, i) => _buildNotamCard(list[i]),
      ),
    );
  }

  Widget _buildPlaceholder({
    required IconData icon,
    required String title,
    required String subtitle,
    Color iconColor = Colors.white24,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: iconColor),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.orbitron(
                color: Colors.white,
                fontSize: 16,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotamCard(Notam notam) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF112240),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _categoryChip(notam.category),
              const Spacer(),
              Text(
                notam.id,
                style: GoogleFonts.orbitron(
                  color: Colors.white54,
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            notam.text,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.schedule, color: Colors.white38, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _dateRange(notam),
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ),
              if (notam.location.isNotEmpty) ...[
                const Icon(Icons.place, color: Colors.white38, size: 14),
                const SizedBox(width: 4),
                Text(
                  notam.location,
                  style: GoogleFonts.orbitron(
                    color: Colors.white54,
                    fontSize: 11,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(NotamCategory category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: category.color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: category.color.withValues(alpha: 0.6)),
      ),
      child: Text(
        category.label,
        style: GoogleFonts.orbitron(
          color: category.color,
          fontSize: 10,
          letterSpacing: 1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _dateRange(Notam notam) {
    final fmt = DateFormat('dd MMM HH:mm\'Z\'');
    final start = notam.effectiveStart != null
        ? fmt.format(notam.effectiveStart!)
        : 'N/A';
    final end = notam.isPermanent
        ? 'UFN'
        : fmt.format(notam.effectiveEnd!);
    return '$start  →  $end';
  }
}
