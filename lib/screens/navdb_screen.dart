import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/navdb_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Navigation Database screen — search VOR/NDB/TACAN/DME navaids (free, open
// OurAirports data), plus favorites and user-defined waypoints.
//
// Owns its own [NavDbService] in State — no global provider needed.
// ─────────────────────────────────────────────────────────────────────────────

// Palette
const Color _bg = Color(0xFF0A1628);
const Color _card = Color(0xFF112240);
const Color _cyan = Color(0xFF00BCD4);
const Color _amber = Color(0xFFFFB300);
const Color _green = Color(0xFF4CAF50);

class NavDbScreen extends StatefulWidget {
  const NavDbScreen({super.key});

  @override
  State<NavDbScreen> createState() => _NavDbScreenState();
}

class _NavDbScreenState extends State<NavDbScreen>
    with SingleTickerProviderStateMixin {
  final NavDbService _service = NavDbService();
  final TextEditingController _searchController = TextEditingController();
  late final TabController _tabController;

  String _typeFilter = 'All';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _service.addListener(_onServiceChanged);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _service.loadPrefs();
    await _service.ensureLoaded();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    _service.dispose();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('NAV DATABASE'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _cyan,
          labelColor: _cyan,
          unselectedLabelColor: Colors.white54,
          labelStyle: GoogleFonts.orbitron(
            fontSize: 11,
            letterSpacing: 1,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'SEARCH'),
            Tab(text: 'FAVORITES'),
            Tab(text: 'WAYPOINTS'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSearchTab(),
                _buildFavoritesTab(),
                _buildWaypointsTab(),
              ],
            ),
          ),
          _buildSourceCaption(),
        ],
      ),
    );
  }

  Widget _buildSourceCaption() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0D1B2A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        'Navaid data: OurAirports (free/open).',
        style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
      ),
    );
  }

  // ── Search tab ───────────────────────────────────────────────────────────

  Widget _buildSearchTab() {
    return Column(
      children: [
        _buildSearchBar(),
        _buildFilterChips(),
        Expanded(child: _buildSearchResults()),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF0D1B2A),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.orbitron(
          color: Colors.white,
          fontSize: 14,
          letterSpacing: 2,
        ),
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          hintText: 'Search ident or name (e.g. JFK)',
          prefixIcon: const Icon(Icons.search, color: _cyan),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                tooltip: 'Clear',
                  icon: const Icon(Icons.clear, color: Colors.white38),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
          hintStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
          filled: true,
          fillColor: _card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _cyan),
          ),
        ),
        onChanged: (v) => setState(() => _query = v),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 48,
      color: const Color(0xFF0D1B2A),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          for (final t in NavDbService.typeFilters) _filterChip(t),
        ],
      ),
    );
  }

  Widget _filterChip(String label) {
    final selected = _typeFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _typeFilter = label),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? _cyan.withValues(alpha: 0.2) : _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? _cyan : Colors.white12),
          ),
          child: Text(
            label.toUpperCase(),
            style: GoogleFonts.orbitron(
              fontSize: 10,
              color: selected ? _cyan : Colors.white54,
              letterSpacing: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_service.isLoading) {
      return _buildLoading('Loading navaid database…');
    }

    if (_service.error != null && !_service.isLoaded) {
      return _buildError();
    }

    final results = _service.search(_query, typeFilter: _typeFilter);

    if (results.isEmpty) {
      return _buildPlaceholder(
        icon: Icons.explore_off,
        title: _query.isEmpty ? 'Search the database' : 'No matches',
        subtitle: _query.isEmpty
            ? 'Type a navaid ident or name to begin.\n'
                '${_service.navaidCount} navaids loaded.'
            : 'No navaids match "$_query".',
      );
    }

    return Column(
      children: [
        _buildResultCountBar(results.length),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: results.length,
            itemBuilder: (context, i) => _buildNavaidCard(results[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildResultCountBar(int count) {
    final capped = count >= kMaxSearchResults;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        capped
            ? 'Showing first $count results — refine your search'
            : '$count result${count == 1 ? '' : 's'}',
        style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
      ),
    );
  }

  // ── Favorites tab ────────────────────────────────────────────────────────

  Widget _buildFavoritesTab() {
    if (_service.isLoading) {
      return _buildLoading('Loading navaid database…');
    }

    final favIdents = _service.favorites;
    if (favIdents.isEmpty) {
      return _buildPlaceholder(
        icon: Icons.star_border,
        title: 'No favorites yet',
        subtitle: 'Tap the star on any navaid to save it here.',
      );
    }

    final favs = _service.byIdents(favIdents);
    // Show any favorites whose records could not be resolved (e.g. not loaded).
    final resolvedIdents = favs.map((n) => n.ident.toUpperCase()).toSet();
    final unresolved = favIdents
        .where((id) => !resolvedIdents.contains(id.toUpperCase()))
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final n in favs) _buildNavaidCard(n),
        for (final id in unresolved) _buildUnresolvedFavoriteCard(id),
      ],
    );
  }

  Widget _buildUnresolvedFavoriteCard(String ident) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              ident,
              style: GoogleFonts.orbitron(
                color: Colors.white,
                fontSize: 15,
                letterSpacing: 2,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Rate',
            icon: const Icon(Icons.star, color: _amber),
            onPressed: () => _service.toggleFavorite(ident),
          ),
        ],
      ),
    );
  }

  // ── Waypoints tab ────────────────────────────────────────────────────────

  Widget _buildWaypointsTab() {
    final waypoints = _service.userWaypoints;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showAddWaypointDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: _cyan,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add_location_alt, color: Colors.black),
              label: Text(
                'ADD WAYPOINT',
                style: GoogleFonts.orbitron(
                  color: Colors.black,
                  fontSize: 12,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: waypoints.isEmpty
              ? _buildPlaceholder(
                  icon: Icons.push_pin_outlined,
                  title: 'No waypoints',
                  subtitle: 'Create custom waypoints with a name and '
                      'latitude / longitude.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: waypoints.length,
                  itemBuilder: (context, i) =>
                      _buildWaypointCard(waypoints[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildWaypointCard(UserWaypoint wp) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const Icon(Icons.push_pin, color: _green, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wp.name.isEmpty ? 'Waypoint' : wp.name,
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 14,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatCoords(wp.lat, wp.lon),
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline, color: Colors.white38),
            onPressed: () => _service.removeUserWaypoint(wp.id),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddWaypointDialog() async {
    final nameController = TextEditingController();
    final latController = TextEditingController();
    final lonController = TextEditingController();
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            InputDecoration deco(String label) => InputDecoration(
                  labelText: label,
                  labelStyle:
                      GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _cyan),
                  ),
                );

            return AlertDialog(
              backgroundColor: _card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'New Waypoint',
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: 16,
                  letterSpacing: 1,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      style: GoogleFonts.inter(color: Colors.white),
                      decoration: deco('Name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: latController,
                      style: GoogleFonts.inter(color: Colors.white),
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                      decoration: deco('Latitude (-90 to 90)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: lonController,
                      style: GoogleFonts.inter(color: Colors.white),
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                      decoration: deco('Longitude (-180 to 180)'),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorText!,
                        style: GoogleFonts.inter(
                          color: const Color(0xFFF44336),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'CANCEL',
                    style: GoogleFonts.orbitron(
                      color: Colors.white54,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _cyan),
                  onPressed: () {
                    final name = nameController.text.trim();
                    final lat = double.tryParse(latController.text.trim());
                    final lon = double.tryParse(lonController.text.trim());
                    if (name.isEmpty) {
                      setDialogState(() => errorText = 'Name is required.');
                      return;
                    }
                    if (lat == null || lat < -90 || lat > 90) {
                      setDialogState(() =>
                          errorText = 'Latitude must be a number -90 to 90.');
                      return;
                    }
                    if (lon == null || lon < -180 || lon > 180) {
                      setDialogState(() => errorText =
                          'Longitude must be a number -180 to 180.');
                      return;
                    }
                    _service.addUserWaypoint(name, lat, lon);
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text(
                    'ADD',
                    style: GoogleFonts.orbitron(
                      color: Colors.black,
                      fontSize: 11,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    latController.dispose();
    lonController.dispose();
  }

  // ── Shared widgets ───────────────────────────────────────────────────────

  Widget _buildNavaidCard(Navaid navaid) {
    final isFav = _service.isFavorite(navaid.ident);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
              Text(
                navaid.ident,
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: 16,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(width: 10),
              _typeChip(navaid.type),
              const Spacer(),
              IconButton(
                tooltip: 'Rate',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  isFav ? Icons.star : Icons.star_border,
                  color: isFav ? _amber : Colors.white38,
                ),
                onPressed: () => _service.toggleFavorite(navaid.ident),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            navaid.name,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              if (navaid.frequencyMhz != null)
                _infoBit(
                  Icons.radio,
                  '${navaid.frequencyMhz!.toStringAsFixed(2)} MHz',
                ),
              _infoBit(Icons.place, _formatCoords(navaid.lat, navaid.lon)),
              if (navaid.elevationFt != null)
                _infoBit(
                  Icons.height,
                  '${navaid.elevationFt!.toStringAsFixed(0)} ft',
                ),
              if (navaid.country.isNotEmpty)
                _infoBit(Icons.flag, navaid.country),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoBit(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white38),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _typeChip(String type) {
    final color = _colorForType(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        type.toUpperCase(),
        style: GoogleFonts.orbitron(
          color: color,
          fontSize: 9,
          letterSpacing: 1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Color _colorForType(String type) {
    final t = type.toUpperCase();
    if (t.contains('NDB')) return _amber;
    if (t.contains('TACAN')) return _green;
    if (t.contains('DME')) return Colors.white70;
    return _cyan; // VOR and variants
  }

  Widget _buildLoading(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: _cyan),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 56, color: Color(0xFFF44336)),
            const SizedBox(height: 16),
            Text(
              'Data unavailable',
              style: GoogleFonts.orbitron(
                color: Colors.white,
                fontSize: 16,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _service.error ?? 'Could not load navaid data.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _cyan),
              onPressed: () => _service.reload(),
              child: Text(
                'RETRY',
                style: GoogleFonts.orbitron(
                  color: Colors.black,
                  fontSize: 11,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.orbitron(
                color: Colors.white,
                fontSize: 16,
                letterSpacing: 1,
              ),
              textAlign: TextAlign.center,
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

  String _formatCoords(double lat, double lon) {
    final latDir = lat >= 0 ? 'N' : 'S';
    final lonDir = lon >= 0 ? 'E' : 'W';
    return '${lat.abs().toStringAsFixed(4)}$latDir  '
        '${lon.abs().toStringAsFixed(4)}$lonDir';
  }
}
