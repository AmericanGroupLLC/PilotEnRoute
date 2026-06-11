import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/premium_service.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF0D1B2A),
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // ── Premium Banner ──────────────────────────────────────
                _buildPremiumBanner(context),
                // ── Training ────────────────────────────────────────────
                _buildSection('TRAINING'),
                _buildItem(context, Icons.flight_takeoff, 'AI Flight Simulator',
                    '/simulation', badge: 'NEW'),
                _buildItem(context, Icons.school, 'FAA Education Hub', '/education'),
                _buildItem(context, Icons.checklist_rtl, 'Smart Checklists', '/checklist'),
                _buildItem(context, Icons.warning_amber, 'Emergency Trainer',
                    '/emergency', badge: 'SIM'),
                _buildItem(context, Icons.toys, 'Drone Education', '/drone'),
                _buildItem(context, Icons.quiz, 'ATPL Quiz Bank', '/quiz'),
                _buildItem(context, Icons.style, 'Flashcards', '/flashcards'),
                _buildItem(context, Icons.assignment, 'FAA Exam Tests', '/exam',
                    badge: 'PREP'),
                // ── Live Data ───────────────────────────────────────────
                _buildSection('LIVE DATA'),
                _buildItem(context, Icons.cloud, 'Aviation Weather', '/weather',
                    badge: 'LIVE'),
                _buildItem(context, Icons.local_airport, 'Airport Lookup', '/airport'),
                _buildItem(context, Icons.newspaper, 'Aviation News', '/news',
                    badge: 'LIVE'),
                _buildItem(context, Icons.radar, 'Flight Tracker', '/flight-tracker',
                    badge: 'ADS-B'),
                // ── Pilot Tools ─────────────────────────────────────────
                _buildSection('PILOT TOOLS'),
                _buildItem(context, Icons.book, 'Digital Logbook', '/logbook'),
                _buildItem(context, Icons.map, 'Flight Planner', '/flight-plan'),
                _buildItem(context, Icons.verified, 'Endorsements', '/endorsements'),
                _buildItem(context, Icons.trending_up, 'Career Pathways', '/career'),
                _buildItem(context, Icons.public, 'ICARA (Intl Students)', '/icara'),
                // ── Reference ───────────────────────────────────────────
                _buildSection('REFERENCE'),
                _buildItem(context, Icons.menu_book, 'Aviation Glossary', '/glossary'),
                _buildItem(context, Icons.watch, 'Garmin Connect', '/garmin',
                    badge: 'GPS'),
                // ── Store ───────────────────────────────────────────────
                _buildSection('PILOT STORE'),
                _buildStoreItem(context),
                const Divider(color: Colors.white12),
                // ── Account ─────────────────────────────────────────────
                _buildItem(context, Icons.person, 'Pilot Profile', '/profile'),
                _buildItem(context, Icons.notifications, 'Notifications', '/notifications'),
                _buildItem(context, Icons.info_outline, 'About PilotEnRoute', null),
              ],
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Consumer<PremiumService>(
      builder: (context, premium, _) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: premium.isPremium
                  ? [const Color(0xFF7B5E00), const Color(0xFF0A1628)]
                  : [const Color(0xFF1565C0), const Color(0xFF0A1628)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00BCD4).withAlpha(50),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: const Color(0xFF00BCD4), width: 2),
                    ),
                    child: const Icon(Icons.flight,
                        color: Color(0xFF00BCD4), size: 28),
                  ),
                  const Spacer(),
                  if (premium.isPremium)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.workspace_premium,
                              color: Colors.black, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            'PREMIUM',
                            style: GoogleFonts.orbitron(
                              color: Colors.black,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'PilotEnRoute',
                style: GoogleFonts.orbitron(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'Aviation Training Platform',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPremiumBanner(BuildContext context) {
    return Consumer<PremiumService>(
      builder: (context, premium, _) {
        if (premium.isPremium) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/premium');
          },
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7B5E00), Color(0xFF4A3800)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFFFFD700).withAlpha(80)),
            ),
            child: Row(
              children: [
                const Icon(Icons.workspace_premium,
                    color: Color(0xFFFFD700), size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upgrade to Premium',
                        style: GoogleFonts.orbitron(
                          color: const Color(0xFFFFD700),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Remove ads • Unlock all features',
                        style: GoogleFonts.inter(
                          color: Colors.white60,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: Color(0xFFFFD700), size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStoreItem(BuildContext context) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.storefront,
          color: Color(0xFFFFD700), size: 20),
      title: Text(
        'Pilot Gear Store',
        style: GoogleFonts.inter(
          fontSize: 13,
          color: const Color(0xFFFFD700),
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD700),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'SHOP',
          style: GoogleFonts.orbitron(
            fontSize: 7,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        Navigator.pushNamed(context, '/store');
      },
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: GoogleFonts.orbitron(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF00BCD4),
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    IconData icon,
    String title,
    String? route, {
    String? badge,
  }) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: Colors.white70, size: 20),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: badge != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB300),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge,
                style: GoogleFonts.orbitron(
                  fontSize: 7,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            )
          : null,
      onTap: () {
        Navigator.pop(context);
        if (route != null) Navigator.pushNamed(context, route);
      },
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Text(
        'Powered by Rotate Pilot API\nOpenSky Network • Aviation Weather Center\nFAA Public Data',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 9,
          color: Colors.white30,
          height: 1.6,
        ),
      ),
    );
  }
}
