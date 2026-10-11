import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/radio_service.dart';

class RadioScreen extends StatefulWidget {
  const RadioScreen({super.key});

  @override
  State<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen>
    with SingleTickerProviderStateMixin {
  static const Color _bg = Color(0xFF0A1628);
  static const Color _card = Color(0xFF112240);
  static const Color _cyan = Color(0xFF00BCD4);
  static const Color _amber = Color(0xFFFFB300);
  static const Color _red = Color(0xFFF44336);
  static const Color _green = Color(0xFF4CAF50);

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Opens the airport's LiveATC page in the browser. The audio is not
  /// played inside the app.
  Future<void> _openFeed(AtcFeed feed) async {
    var ok = false;
    try {
      ok = await launchUrl(feed.liveAtcPage,
          mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (ok || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _red,
        content: Text(
          'Could not open liveatc.net.',
          style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('RADIO / ATC'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _cyan,
          labelStyle: GoogleFonts.orbitron(fontSize: 9, letterSpacing: 1),
          tabs: const [
            Tab(text: 'ATC FEEDS'),
            Tab(text: 'PHRASEOLOGY'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLiveTab(),
          _buildPhraseologyTab(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 1 — Live ATC
  // ---------------------------------------------------------------------------

  Widget _buildLiveTab() {
    return Column(
      children: [
        _buildBanner(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            itemCount: RadioService.feeds.length,
            itemBuilder: (context, i) => _buildFeedCard(RadioService.feeds[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: _amber, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Live ATC audio is not played in this app. Tap an airport to '
              'open its feeds on liveatc.net in your browser.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white70,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedCard(AtcFeed feed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
      color: _card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Colors.white12),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => _openFeed(feed),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _cyan.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.radio, color: _cyan, size: 22),
        ),
        title: Text(
          feed.airport,
          style: GoogleFonts.orbitron(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
        subtitle: Text(
          '${feed.name} · liveatc.net',
          style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
        ),
        trailing: Icon(Icons.open_in_new, color: _green,
            semanticLabel: 'Open ${feed.airport} on liveatc.net'),
      ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 2 — Phraseology
  // ---------------------------------------------------------------------------

  Widget _buildPhraseologyTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          'STANDARD RADIO PHRASEOLOGY',
          style: GoogleFonts.orbitron(
            fontSize: 11,
            color: _cyan,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Reference for common VFR/IFR exchanges (U.S. / FAA AIM Ch. 4).',
          style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
        ),
        const SizedBox(height: 14),
        ..._phraseologySections().map(_buildPhraseSection),
        const SizedBox(height: 4),
        _buildGlossaryButton(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPhraseSection(_PhraseSection section) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: section.color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: section.color.withValues(alpha: 0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(section.icon, color: section.color, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    section.title,
                    style: GoogleFonts.orbitron(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: section.color,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
            child: Column(
              children: section.calls
                  .map((c) => _buildCallRow(c, section.color))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallRow(_RadioCall call, Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            call.situation.toUpperCase(),
            style: GoogleFonts.orbitron(
              fontSize: 9,
              color: accent,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(
              '"${call.phrase}"',
              style: GoogleFonts.robotoMono(
                fontSize: 12,
                color: Colors.white,
                height: 1.5,
              ),
            ),
          ),
          if (call.note != null) ...[
            const SizedBox(height: 5),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline,
                    color: _amber, size: 13),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    call.note!,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.white54,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGlossaryButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _openGlossary,
        style: OutlinedButton.styleFrom(
          foregroundColor: _cyan,
          side: const BorderSide(color: _cyan),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.menu_book, size: 18),
        label: Text(
          'AIM PILOT/CONTROLLER GLOSSARY',
          style: GoogleFonts.orbitron(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Future<void> _openGlossary() async {
    final uri = Uri.parse(
      'https://www.faa.gov/air_traffic/publications/atpubs/pcg_html/',
    );
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _red,
            content: Text(
              'Could not open the glossary link.',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _red,
          content: Text(
            'Could not open the glossary link.',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
          ),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Static phraseology reference data
  // ---------------------------------------------------------------------------

  List<_PhraseSection> _phraseologySections() {
    return const [
      _PhraseSection(
        title: 'Ground Control',
        icon: Icons.local_taxi,
        color: _green,
        calls: [
          _RadioCall(
            situation: 'Requesting taxi (VFR)',
            phrase:
                'Palo Alto Ground, Cessna Three-Four-Five-Six-Whiskey, at the transient ramp with information Bravo, ready to taxi, VFR to the north.',
            note: 'State your position, ATIS code, and intentions.',
          ),
          _RadioCall(
            situation: 'Readback of taxi clearance',
            phrase:
                'Taxi to Runway Three-One via Alpha, hold short of Runway Two-Seven, Five-Six-Whiskey.',
            note: 'Always read back runway assignments and hold-short instructions.',
          ),
          _RadioCall(
            situation: 'Requesting progressive taxi',
            phrase:
                'Ground, Five-Six-Whiskey, request progressive taxi to Runway Three-One, unfamiliar with the field.',
          ),
        ],
      ),
      _PhraseSection(
        title: 'Tower',
        icon: Icons.control_camera,
        color: _cyan,
        calls: [
          _RadioCall(
            situation: 'Ready for departure',
            phrase:
                'Tower, Five-Six-Whiskey, holding short of Runway Three-One, ready for departure.',
          ),
          _RadioCall(
            situation: 'Takeoff clearance readback',
            phrase: 'Cleared for takeoff, Runway Three-One, Five-Six-Whiskey.',
          ),
          _RadioCall(
            situation: 'Inbound for landing (towered)',
            phrase:
                'Tower, Cessna Five-Six-Whiskey, ten miles south, inbound for landing with information Charlie.',
            note: 'Give distance, direction, and current ATIS.',
          ),
          _RadioCall(
            situation: 'Landing clearance readback',
            phrase: 'Cleared to land, Runway Three-One, Five-Six-Whiskey.',
          ),
          _RadioCall(
            situation: 'Going around',
            phrase: 'Going around, Five-Six-Whiskey.',
            note: 'Announce immediately, then follow tower instructions.',
          ),
        ],
      ),
      _PhraseSection(
        title: 'Departure / Center',
        icon: Icons.flight_takeoff,
        color: Color(0xFF2196F3),
        calls: [
          _RadioCall(
            situation: 'Initial contact with departure',
            phrase:
                'NorCal Departure, Cessna Five-Six-Whiskey, leaving one thousand five hundred, climbing four thousand five hundred.',
            note: 'Report current and assigned altitude on check-in.',
          ),
          _RadioCall(
            situation: 'VFR flight following request',
            phrase:
                'NorCal Approach, Cessna Five-Six-Whiskey, request VFR flight following, over Livermore at four thousand five hundred, destination Sacramento.',
          ),
          _RadioCall(
            situation: 'Frequency change readback',
            phrase: 'Contact Center on one-three-two point five, Five-Six-Whiskey.',
          ),
        ],
      ),
      _PhraseSection(
        title: 'Arrival / Approach',
        icon: Icons.flight_land,
        color: Color(0xFF9C27B0),
        calls: [
          _RadioCall(
            situation: 'Non-towered CTAF — inbound',
            phrase:
                'Watsonville traffic, Cessna Five-Six-Whiskey, ten miles north, inbound for left downwind Runway Two-Zero, Watsonville.',
            note: 'Begin and end self-announce calls with the field name.',
          ),
          _RadioCall(
            situation: 'Downwind position report',
            phrase:
                'Watsonville traffic, Five-Six-Whiskey, left downwind Runway Two-Zero, Watsonville.',
          ),
          _RadioCall(
            situation: 'Clearing the runway',
            phrase:
                'Watsonville traffic, Five-Six-Whiskey, clear of Runway Two-Zero, Watsonville.',
          ),
        ],
      ),
      _PhraseSection(
        title: 'Emergency',
        icon: Icons.warning_amber_rounded,
        color: _red,
        calls: [
          _RadioCall(
            situation: 'Distress (grave & imminent danger)',
            phrase:
                'Mayday, Mayday, Mayday, NorCal Approach, Cessna Five-Six-Whiskey, engine failure, four thousand feet, ten miles east of Livermore, three souls on board, attempting a forced landing.',
            note: 'Aviate, Navigate, Communicate. Say who, what, where, intentions, souls on board, fuel.',
          ),
          _RadioCall(
            situation: 'Urgency (safety concern, not distress)',
            phrase:
                'Pan-Pan, Pan-Pan, Pan-Pan, NorCal Approach, Cessna Five-Six-Whiskey, rough-running engine, requesting vectors to the nearest airport.',
          ),
          _RadioCall(
            situation: 'Lost communications / no radio',
            phrase:
                'Squawk 7600 (comm failure). For emergency squawk 7700; for hijack squawk 7500.',
            note: 'Transponder codes to memorize: 7500 hijack, 7600 comm loss, 7700 emergency.',
          ),
        ],
      ),
    ];
  }
}

class _PhraseSection {
  final String title;
  final IconData icon;
  final Color color;
  final List<_RadioCall> calls;

  const _PhraseSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.calls,
  });
}

class _RadioCall {
  final String situation;
  final String phrase;
  final String? note;

  const _RadioCall({
    required this.situation,
    required this.phrase,
    this.note,
  });
}
