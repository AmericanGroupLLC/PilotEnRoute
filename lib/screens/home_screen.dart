import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/aviation_api_service.dart';
import '../services/news_service.dart';
import '../widgets/ad_banner_widget.dart';
import '../widgets/adaptive_grid.dart';
import '../widgets/app_drawer.dart';
import '../widgets/news_ticker.dart';
import '../widgets/module_card.dart';
import '../widgets/daily_quote_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AviationApiService>().fetchDailyQuote();
      context.read<AviationApiService>().fetchQuizOfDay();
      context.read<NewsService>().fetchAllNews();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      drawer: const AppDrawer(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(),
            SliverToBoxAdapter(child: _buildHeroSection()),
            SliverToBoxAdapter(child: _buildQuoteSection()),
            const SliverToBoxAdapter(child: AdBannerWidget()),
            SliverToBoxAdapter(child: _buildModulesGrid()),
            SliverToBoxAdapter(child: _buildLiveDataSection()),
            SliverToBoxAdapter(child: _buildNewsSection()),
            SliverToBoxAdapter(child: _buildStorePromo()),
            const SliverToBoxAdapter(child: AdBannerWidget()),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      pinned: true,
      backgroundColor: const Color(0xFF0A1628),
      elevation: 0,
      leading: Builder(
        builder: (ctx) => IconButton(
          tooltip: 'Menu',
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      titleSpacing: 0,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.flight, color: Color(0xFF00BCD4), size: 20),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'PILOT EN ROUTE',
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: GoogleFonts.orbitron(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.storefront, color: Color(0xFFFFD700)),
          tooltip: 'Pilot Store',
          onPressed: () => Navigator.pushNamed(context, '/store'),
        ),
        IconButton(
          tooltip: 'Notifications',
          icon: const Icon(Icons.notifications_outlined, color: Colors.white70),
          onPressed: () => Navigator.pushNamed(context, '/notifications'),
        ),
        IconButton(
          tooltip: 'Profile',
          icon: const Icon(Icons.person_outline, color: Colors.white70),
          onPressed: () => Navigator.pushNamed(context, '/profile'),
        ),
      ],
    );
  }

  Widget _buildHeroSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1), Color(0xFF0A1628)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00BCD4).withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The pill hugs its text, so it has to be allowed to shrink: on a
          // folded cover display at a large text scale the caption is wider
          // than the hero card.
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF00BCD4).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF00BCD4), width: 1),
              ),
              child: Text(
                'AVIATION TRAINING PLATFORM',
                style: GoogleFonts.orbitron(
                  fontSize: 9,
                  color: const Color(0xFF00BCD4),
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            container: true,
            header: true,
            label: 'Your complete pilot training hub',
            excludeSemantics: true,
            child: Text(
              'Your Complete\nPilot Training Hub',
              style: GoogleFonts.orbitron(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'From Student Pilot to ATP — FAA Education, AI Simulation, Live Weather & More',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          // Wrap, not Row: three badges do not fit across a folded cover
          // display once the text scale goes up, and they should stack rather
          // than run off the card.
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildStatBadge('Live', 'FAA Q-Bank'),
              _buildStatBadge('500+', 'Airports'),
              _buildStatBadge('13', 'Subjects'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String value, String label) {
    return Semantics(
      container: true,
      label: '$value $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.orbitron(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFFFB300),
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuoteSection() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: DailyQuoteCard(),
    );
  }

  Widget _buildModulesGrid() {
    final modules = [
      const ModuleData(
        title: 'AI Flight\nSimulator',
        icon: Icons.flight_takeoff,
        color: Color(0xFF1565C0),
        route: '/simulation',
        badge: 'NEW',
      ),
      const ModuleData(
        title: 'FAA\nEducation',
        icon: Icons.school,
        color: Color(0xFF00695C),
        route: '/education',
      ),
      const ModuleData(
        title: 'Smart\nChecklists',
        icon: Icons.checklist_rtl,
        color: Color(0xFF6A1B9A),
        route: '/checklist',
      ),
      const ModuleData(
        title: 'Emergency\nTrainer',
        icon: Icons.warning_amber,
        color: Color(0xFFB71C1C),
        route: '/emergency',
        badge: 'SIM',
      ),
      const ModuleData(
        title: 'Drone\nEducation',
        icon: Icons.toys,
        color: Color(0xFF00838F),
        route: '/drone',
      ),
      const ModuleData(
        title: 'Live\nWeather',
        icon: Icons.cloud,
        color: Color(0xFF1565C0),
        route: '/weather',
        badge: 'LIVE',
      ),
      const ModuleData(
        title: 'Aviation\nNews',
        icon: Icons.newspaper,
        color: Color(0xFF4E342E),
        route: '/news',
        badge: 'LIVE',
      ),
      const ModuleData(
        title: 'Airport\nLookup',
        icon: Icons.local_airport,
        color: Color(0xFF1B5E20),
        route: '/airport',
      ),
      const ModuleData(
        title: 'ATPL\nQuiz',
        icon: Icons.quiz,
        color: Color(0xFFE65100),
        route: '/quiz',
      ),
      const ModuleData(
        title: 'Aviation\nGlossary',
        icon: Icons.menu_book,
        color: Color(0xFF37474F),
        route: '/glossary',
      ),
      const ModuleData(
        title: 'Garmin\nConnect',
        icon: Icons.watch,
        color: Color(0xFF1A237E),
        route: '/garmin',
        badge: 'GPS',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            container: true,
            header: true,
            child: Text(
              'TRAINING MODULES',
              style: GoogleFonts.orbitron(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF00BCD4),
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // The column count comes from the live constraints, so unfolding the
          // device widens the grid instead of stretching three tiles across a
          // near-square window.
          LayoutBuilder(
            builder: (context, constraints) => GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: adaptiveTileColumns(constraints.maxWidth),
                childAspectRatio: 0.9,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: modules.length,
              itemBuilder: (context, index) => ModuleCard(data: modules[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveDataSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            container: true,
            header: true,
            label: 'Live data',
            excludeSemantics: true,
            child: Row(
              children: [
                Text(
                  'LIVE DATA',
                  style: GoogleFonts.orbitron(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF00BCD4),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'LIVE',
                  style: GoogleFonts.orbitron(
                    fontSize: 9,
                    color: const Color(0xFF4CAF50),
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildLiveCard(
                  icon: Icons.cloud,
                  title: 'METAR',
                  subtitle: 'Live airport weather',
                  color: const Color(0xFF1565C0),
                  onTap: () => Navigator.pushNamed(context, '/weather'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildLiveCard(
                  icon: Icons.radar,
                  title: 'Live Traffic',
                  subtitle: 'OpenSky Network',
                  color: const Color(0xFF00695C),
                  onTap: () => Navigator.pushNamed(context, '/weather'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Semantics(
      container: true,
      button: true,
      label: '$title, $subtitle',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.orbitron(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  color: Colors.white54, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Semantics(
                container: true,
                header: true,
                child: Text(
                  'AVIATION NEWS',
                  style: GoogleFonts.orbitron(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF00BCD4),
                    letterSpacing: 2,
                  ),
                ),
              ),
              Semantics(
                container: true,
                button: true,
                label: 'See all aviation news',
                excludeSemantics: true,
                child: TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/news'),
                  child: Text(
                    'See All',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF00BCD4),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const NewsTicker(),
        ],
      ),
    );
  }

  Widget _buildStorePromo() {
    return Semantics(
      container: true,
      button: true,
      label: 'Pilot Gear Store. Headsets, GPS, charts and more, curated by '
          'pilots',
      excludeSemantics: true,
      child: GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/store'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 24, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7B5E00), Color(0xFF4A3800)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFD700).withAlpha(80)),
        ),
        child: Row(
          children: [
            const Icon(Icons.storefront, color: Color(0xFFFFD700), size: 36),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pilot Gear Store', style: GoogleFonts.orbitron(color: const Color(0xFFFFD700), fontSize: 14, fontWeight: FontWeight.bold)),
                  Text('Headsets, GPS, Charts & More — Curated by Pilots', style: GoogleFonts.inter(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Color(0xFFFFD700), size: 16),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (index) {
        setState(() => _selectedIndex = index);
        switch (index) {
          case 0:
            break;
          case 1:
            Navigator.pushNamed(context, '/quiz');
            break;
          case 2:
            Navigator.pushNamed(context, '/weather');
            break;
          case 3:
            Navigator.pushNamed(context, '/store');
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.quiz), label: 'Quiz'),
        BottomNavigationBarItem(icon: Icon(Icons.cloud), label: 'Weather'),
        BottomNavigationBarItem(icon: Icon(Icons.storefront), label: 'Store'),
      ],
    );
  }
}

class ModuleData {
  final String title;
  final IconData icon;
  final Color color;
  final String route;
  final String? badge;

  const ModuleData({
    required this.title,
    required this.icon,
    required this.color,
    required this.route,
    this.badge,
  });
}
