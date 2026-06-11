import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EndorsementsScreen extends StatefulWidget {
  const EndorsementsScreen({super.key});

  @override
  State<EndorsementsScreen> createState() => _EndorsementsScreenState();
}

class _EndorsementsScreenState extends State<EndorsementsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        title: const Text('ENDORSEMENTS & CAREERS'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00BCD4),
          labelStyle: GoogleFonts.orbitron(fontSize: 9, letterSpacing: 1),
          tabs: const [
            Tab(text: 'ENDORSEMENTS'),
            Tab(text: 'CAREER PATHS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEndorsementsTab(),
          _buildCareerPathsTab(),
        ],
      ),
    );
  }

  Widget _buildEndorsementsTab() {
    final endorsements = _getEndorsements();
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: endorsements.length,
      itemBuilder: (context, i) {
        final e = endorsements[i];
        return _buildEndorsementCard(e);
      },
    );
  }

  Widget _buildEndorsementCard(Map<String, dynamic> e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF112240),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (e['color'] as Color).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(e['icon'] as IconData, color: e['color'] as Color, size: 20),
        ),
        title: Text(
          e['title'] as String,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          e['regulation'] as String,
          style: GoogleFonts.orbitron(
            fontSize: 9,
            color: Colors.white38,
            letterSpacing: 1,
          ),
        ),
        iconColor: const Color(0xFF00BCD4),
        collapsedIconColor: Colors.white38,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(color: Colors.white12),
              const SizedBox(height: 8),
              Text(
                'REQUIREMENTS',
                style: GoogleFonts.orbitron(
                  fontSize: 9,
                  color: const Color(0xFF00BCD4),
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              ...(e['requirements'] as List<String>).map((req) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline,
                            color: Color(0xFF4CAF50), size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            req,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white70,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
              if (e['sampleText'] != null) ...[
                const SizedBox(height: 12),
                Text(
                  'SAMPLE ENDORSEMENT TEXT',
                  style: GoogleFonts.orbitron(
                    fontSize: 9,
                    color: const Color(0xFFFFB300),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A1628),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFFFFB300).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    e['sampleText'] as String,
                    style: GoogleFonts.robotoMono(
                      fontSize: 11,
                      color: const Color(0xFFFFB300),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCareerPathsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AVIATION CAREER ROADMAP',
            style: GoogleFonts.orbitron(
              fontSize: 11,
              color: const Color(0xFF00BCD4),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          _buildCareerPath(
            title: 'Airline Transport Pilot (ATP)',
            color: const Color(0xFFFFB300),
            icon: Icons.workspace_premium,
            steps: [
              _CareerStep('Student Pilot', 'Age 16 · 3rd Class Medical · Solo endorsement', const Color(0xFF4CAF50), '0h'),
              _CareerStep('Private Pilot (PPL)', '40h total · 20h dual · 10h solo · Written test · Checkride', const Color(0xFF2196F3), '40h'),
              _CareerStep('Instrument Rating (IR)', '50h XC PIC · 40h instrument · Written · Checkride', const Color(0xFF9C27B0), '125h'),
              _CareerStep('Commercial Pilot (CPL)', '250h total · 100h PIC · 50h XC · Written · Checkride', const Color(0xFFFF9800), '250h'),
              _CareerStep('CFI / CFII (Optional)', 'Build hours as instructor · FOI + FIA written · Checkride', const Color(0xFF00BCD4), '250h+'),
              _CareerStep('ATP Certificate', '1,500h total (1,000h R-ATP with degree) · Written · Checkride', const Color(0xFFFFB300), '1,500h'),
              _CareerStep('Regional Airline FO', 'Type rating · CTP course · ATP mins met', const Color(0xFFF44336), '1,500h+'),
              _CareerStep('Major Airline Captain', '3,000-5,000h+ · Upgrade from FO', const Color(0xFFE91E63), '5,000h+'),
            ],
          ),
          const SizedBox(height: 24),
          _buildCareerPath(
            title: 'Military Aviation',
            color: const Color(0xFF4CAF50),
            icon: Icons.military_tech,
            steps: [
              _CareerStep('ROTC / Academy / OCS', 'College degree + officer commission', const Color(0xFF4CAF50), 'Pre-flight'),
              _CareerStep('Primary Flight Training', 'T-6 Texan II · IFS selection', const Color(0xFF2196F3), '~100h'),
              _CareerStep('Advanced Training', 'T-38 (fighter/bomber) or C-17/KC-135 track', const Color(0xFFFF9800), '~250h'),
              _CareerStep('Operational Squadron', 'Mission qualification · Combat deployments', const Color(0xFFF44336), '500h+'),
              _CareerStep('Civilian Transition', 'ATP credit · Airline hiring preference', const Color(0xFFFFB300), '1,000h+'),
            ],
          ),
          const SizedBox(height: 24),
          _buildCareerPath(
            title: 'Corporate / Charter Aviation',
            color: const Color(0xFF9C27B0),
            icon: Icons.business,
            steps: [
              _CareerStep('PPL + IR + CPL', 'Foundation certificates', const Color(0xFF4CAF50), '250h'),
              _CareerStep('Multi-Engine Rating', 'MEI preferred for charter work', const Color(0xFF2196F3), '250h+'),
              _CareerStep('Part 135 Charter', 'Instrument currency · 500h XC · IFR mins', const Color(0xFFFF9800), '500h'),
              _CareerStep('Type Rating', 'Citation, Phenom, King Air, etc.', const Color(0xFF9C27B0), '1,000h+'),
              _CareerStep('Corporate Captain', 'Part 91/135 · International ops', const Color(0xFFFFB300), '2,500h+'),
            ],
          ),
          const SizedBox(height: 24),
          _buildCareerPath(
            title: 'UAS / Drone Operations',
            color: const Color(0xFF009688),
            icon: Icons.flight_takeoff,
            steps: [
              _CareerStep('Part 107 Remote Pilot', 'Written test only · No medical required', const Color(0xFF4CAF50), '0h'),
              _CareerStep('Commercial Drone Ops', 'Photography, inspection, mapping', const Color(0xFF2196F3), '0h'),
              _CareerStep('Advanced Operations', 'BVLOS waiver · Night ops · Controlled airspace', const Color(0xFFFF9800), '100h UAS'),
              _CareerStep('Enterprise UAS', 'Public safety · Agriculture · Infrastructure', const Color(0xFF009688), '500h UAS'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCareerPath({
    required String title,
    required Color color,
    required IconData icon,
    required List<_CareerStep> steps,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF112240),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.orbitron(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: steps.asMap().entries.map((entry) {
                final i = entry.key;
                final step = entry.value;
                final isLast = i == steps.length - 1;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: step.color.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: step.color, width: 2),
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: GoogleFonts.orbitron(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: step.color,
                              ),
                            ),
                          ),
                        ),
                        if (!isLast)
                          Container(
                            width: 2,
                            height: 40,
                            color: Colors.white12,
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    step.title,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: step.color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    step.hours,
                                    style: GoogleFonts.orbitron(
                                      fontSize: 9,
                                      color: step.color,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              step.description,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.white54,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getEndorsements() {
    return [
      {
        'title': 'Pre-Solo Flight Training',
        'regulation': '14 CFR 61.87(n)',
        'icon': Icons.flight_takeoff,
        'color': const Color(0xFF4CAF50),
        'requirements': [
          'Student must demonstrate satisfactory aeronautical knowledge',
          'Must include stall awareness, spin entry, spins, and spin recovery',
          'Emergency procedures and equipment malfunctions',
          'Ground operations and runway incursion avoidance',
          'Traffic patterns, takeoffs, landings, and go-arounds',
        ],
        'sampleText':
            'I certify that [First name, MI, Last name] has received the training required by §61.87(n). I have determined that [he/she/they] is prepared for solo flight in a [make and model aircraft].\n\n/s/ [Instructor name]\nCFI Certificate #: ______\nExpiration: ______\nDate: ______',
      },
      {
        'title': 'Pre-Solo Aeronautical Knowledge',
        'regulation': '14 CFR 61.87(b)',
        'icon': Icons.menu_book,
        'color': const Color(0xFF2196F3),
        'requirements': [
          'Applicable sections of 14 CFR Parts 61 and 91',
          'Airspace rules and procedures for the airport where solo flight is to be performed',
          'Flight characteristics and operational limitations for the make and model of aircraft',
        ],
        'sampleText':
            'I certify that [First name, MI, Last name] has demonstrated satisfactory aeronautical knowledge for solo flight in a [make and model aircraft] as required by §61.87(b).\n\n/s/ [Instructor name]\nCFI Certificate #: ______\nDate: ______',
      },
      {
        'title': 'Solo Flight in Class B Airspace',
        'regulation': '14 CFR 61.95',
        'icon': Icons.layers,
        'color': const Color(0xFF9C27B0),
        'requirements': [
          'Student must have received ground and flight training in the Class B airspace',
          'Must be familiar with Class B airspace operations',
          'Endorsement must be for specific Class B airspace',
          'Valid for 90 days',
        ],
        'sampleText':
            'I certify that [First name, MI, Last name] has received the required training in accordance with §61.95(a) and has met the applicable requirements of §91.131(b)(1). I have determined that [he/she/they] is proficient to conduct solo flight in [specific Class B airspace].\n\n/s/ [Instructor name]\nDate: ______',
      },
      {
        'title': 'Private Pilot Practical Test',
        'regulation': '14 CFR 61.39, 61.107',
        'icon': Icons.verified,
        'color': const Color(0xFFFFB300),
        'requirements': [
          'Completed aeronautical experience requirements of §61.109',
          'Received flight training and logbook endorsement from authorized instructor',
          'Passed the required knowledge test within 24 calendar months',
          'Completed a solo cross-country flight of at least 150 nm',
          'Completed 3 hours of night flight including a cross-country of 100 nm',
        ],
        'sampleText':
            'I certify that [First name, MI, Last name] has received the required training of §61.107(b). I have determined that [he/she/they] is prepared for the private pilot practical test.\n\n/s/ [Instructor name]\nCFI Certificate #: ______\nDate: ______',
      },
      {
        'title': 'Instrument Rating Practical Test',
        'regulation': '14 CFR 61.39, 61.65',
        'icon': Icons.cloud,
        'color': const Color(0xFF00BCD4),
        'requirements': [
          'Hold at least a private pilot certificate',
          'Logged 50 hours of cross-country flight time as PIC',
          'Logged 40 hours of actual or simulated instrument time',
          'Received 15 hours of instrument flight training from CFII',
          'Passed the instrument rating knowledge test',
        ],
        'sampleText':
            'I certify that [First name, MI, Last name] has received the required training of §61.65(c) and (d). I have determined that [he/she/they] is prepared for the instrument rating practical test.\n\n/s/ [CFII name]\nCFII Certificate #: ______\nDate: ______',
      },
      {
        'title': 'Complex Aircraft',
        'regulation': '14 CFR 61.31(e)',
        'icon': Icons.settings,
        'color': const Color(0xFFFF9800),
        'requirements': [
          'Received ground and flight training from authorized instructor',
          'Training in a complex airplane (retractable gear, flaps, controllable pitch propeller)',
          'Demonstrated proficiency in the complex airplane',
        ],
        'sampleText':
            'I certify that [First name, MI, Last name] has received the required training in a complex airplane as required by §61.31(e)(1). I have determined that [he/she/they] is proficient to act as PIC of a complex airplane.\n\n/s/ [Instructor name]\nDate: ______',
      },
      {
        'title': 'High-Performance Aircraft',
        'regulation': '14 CFR 61.31(f)',
        'icon': Icons.speed,
        'color': const Color(0xFFF44336),
        'requirements': [
          'Received ground and flight training from authorized instructor',
          'Training in a high-performance airplane (more than 200 horsepower)',
          'Demonstrated proficiency in the high-performance airplane',
        ],
        'sampleText':
            'I certify that [First name, MI, Last name] has received the required training in a high-performance airplane as required by §61.31(f)(1). I have determined that [he/she/they] is proficient to act as PIC of a high-performance airplane.\n\n/s/ [Instructor name]\nDate: ______',
      },
      {
        'title': 'Tailwheel Aircraft',
        'regulation': '14 CFR 61.31(i)',
        'icon': Icons.airline_seat_recline_normal,
        'color': const Color(0xFF8BC34A),
        'requirements': [
          'Received ground and flight training from authorized instructor',
          'Training must include normal and crosswind takeoffs and landings',
          'Wheel landings (unless the airplane is not capable of wheel landings)',
          'Go-around procedures',
        ],
        'sampleText':
            'I certify that [First name, MI, Last name] has received the required training in a tailwheel airplane as required by §61.31(i)(1). I have determined that [he/she/they] is proficient to act as PIC of a tailwheel airplane.\n\n/s/ [Instructor name]\nDate: ______',
      },
    ];
  }
}

class _CareerStep {
  final String title;
  final String description;
  final Color color;
  final String hours;

  _CareerStep(this.title, this.description, this.color, this.hours);
}
