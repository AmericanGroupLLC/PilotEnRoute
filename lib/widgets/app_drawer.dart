import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF0D1B2A),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildSection('TRAINING'),
                _buildItem(context, Icons.flight_takeoff, 'AI Flight Simulator', '/simulation', badge: 'NEW'),
                _buildItem(context, Icons.school, 'FAA Education Hub', '/education'),
                _buildItem(context, Icons.checklist_rtl, 'Smart Checklists', '/checklist'),
                _buildItem(context, Icons.warning_amber, 'Emergency Trainer', '/emergency', badge: 'SIM'),
                _buildItem(context, Icons.toys, 'Drone Education', '/drone'),
                _buildItem(context, Icons.quiz, 'ATPL Quiz Bank', '/quiz'),
                _buildSection('LIVE DATA'),
                _buildItem(context, Icons.cloud, 'Aviation Weather', '/weather', badge: 'LIVE'),
                _buildItem(context, Icons.local_airport, 'Airport Lookup', '/airport'),
                _buildItem(context, Icons.newspaper, 'Aviation News', '/news', badge: 'LIVE'),
                _buildSection('REFERENCE'),
                _buildItem(context, Icons.menu_book, 'Aviation Glossary', '/glossary'),
                _buildItem(context, Icons.watch, 'Garmin Connect', '/garmin', badge: 'GPS'),
                const Divider(color: Colors.white12),
                _buildItem(context, Icons.info_outline, 'About PilotEnRoute', null),
              ],
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1565C0), Color(0xFF0A1628)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF00BCD4).withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF00BCD4), width: 2),
            ),
            child: const Icon(Icons.flight, color: Color(0xFF00BCD4), size: 28),
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
