import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class IcaraScreen extends StatelessWidget {
  const IcaraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(title: const Text('INTERNATIONAL STUDENTS')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A237E), Color(0xFF0D47A1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.public, color: Color(0xFF00BCD4), size: 28),
                      const SizedBox(width: 12),
                      Text(
                        'ICARA & TSA REQUIREMENTS',
                        style: GoogleFonts.orbitron(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'International students must comply with TSA security requirements '
                    'before receiving flight training in the United States. '
                    'This includes ICARA (International Civil Aviation Requirements Act) compliance.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _sectionTitle('TSA ALIEN FLIGHT STUDENT PROGRAM (AFSP)'),
            const SizedBox(height: 12),
            _infoCard(
              title: 'Who Must Apply?',
              icon: Icons.person_search,
              color: const Color(0xFFF44336),
              content: 'All non-US citizens and non-US nationals seeking flight training '
                  'at an FAA-certificated flight school (Part 141 or 61) must obtain '
                  'TSA approval BEFORE beginning flight training.',
            ),
            _infoCard(
              title: 'Application Process',
              icon: Icons.assignment,
              color: const Color(0xFF2196F3),
              content: '1. Create account at flightschoolcandidates.gov\n'
                  '2. Submit biometric information (fingerprints)\n'
                  '3. Pay \$130 fee per training event\n'
                  '4. Wait for TSA approval (typically 30-45 days)\n'
                  '5. Flight school receives approval notification',
            ),
            _infoCard(
              title: 'Required Documents',
              icon: Icons.folder,
              color: const Color(0xFFFFB300),
              content: '• Valid passport\n'
                  '• Visa documentation (if applicable)\n'
                  '• I-20 or DS-2019 (if on student visa)\n'
                  '• Proof of English proficiency\n'
                  '• Completed AFSP application',
            ),
            const SizedBox(height: 20),

            _sectionTitle('FAA MEDICAL CERTIFICATE FOR INTERNATIONAL STUDENTS'),
            const SizedBox(height: 12),
            _infoCard(
              title: 'FAA Medical Requirements',
              icon: Icons.medical_services,
              color: const Color(0xFF4CAF50),
              content: '• 3rd Class Medical required for Private Pilot training\n'
                  '• 2nd Class Medical required for Commercial Pilot\n'
                  '• 1st Class Medical required for ATP\n'
                  '• Must be obtained from FAA Aviation Medical Examiner (AME)\n'
                  '• Foreign medical certificates may be accepted for certain operations',
            ),
            _infoCard(
              title: 'ICAO Language Proficiency',
              icon: Icons.language,
              color: const Color(0xFF9C27B0),
              content: 'ICAO requires pilots to demonstrate English language proficiency '
                  'at Level 4 (Operational) or higher for international operations.\n\n'
                  'Levels: 1 (Pre-Elementary) to 6 (Expert)\n'
                  'Level 4 minimum for international flying\n'
                  'Level 6 = no re-test required',
            ),
            const SizedBox(height: 20),

            _sectionTitle('VISA CATEGORIES FOR FLIGHT TRAINING'),
            const SizedBox(height: 12),
            _visaTable(),
            const SizedBox(height: 20),

            _sectionTitle('ICAO STANDARDS & BILATERAL AGREEMENTS'),
            const SizedBox(height: 12),
            _infoCard(
              title: 'License Validation & Conversion',
              icon: Icons.swap_horiz,
              color: const Color(0xFF00BCD4),
              content: 'Foreign pilot licenses may be converted to FAA certificates under '
                  '14 CFR 61.75 if the country has a bilateral aviation safety agreement (BASA) with the US.\n\n'
                  'Countries with BASA: Canada, UK, EU members, Australia, Japan, Brazil, and others.\n\n'
                  'Process: Submit foreign license, medical, logbook, and pass written knowledge test.',
            ),
            _infoCard(
              title: 'ICAO Annex 1 — Personnel Licensing',
              icon: Icons.book,
              color: const Color(0xFFFF9800),
              content: 'ICAO Annex 1 sets international standards for:\n'
                  '• Student Pilot Licence (SPL)\n'
                  '• Private Pilot Licence (PPL)\n'
                  '• Commercial Pilot Licence (CPL)\n'
                  '• Multi-Crew Pilot Licence (MPL)\n'
                  '• Airline Transport Pilot Licence (ATPL)\n'
                  '• Instrument Rating (IR)\n'
                  '• Type Ratings\n\n'
                  'FAA certificates are ICAO-compliant.',
            ),
            const SizedBox(height: 20),

            _sectionTitle('IMPORTANT RESOURCES'),
            const SizedBox(height: 12),
            _linkCard('TSA Alien Flight Student Program', 'https://www.flightschoolcandidates.gov', Icons.security, const Color(0xFFF44336)),
            _linkCard('FAA International Aviation', 'https://www.faa.gov/about/initiatives/international_aviation', Icons.flight, const Color(0xFF2196F3)),
            _linkCard('ICAO Official Website', 'https://www.icao.int', Icons.public, const Color(0xFF4CAF50)),
            _linkCard('FAA Aviation Medical Examiners', 'https://www.faa.gov/pilots/amelocator', Icons.medical_services, const Color(0xFFFFB300)),
            _linkCard('SEVIS (Student Visa)', 'https://www.ice.gov/sevis', Icons.school, const Color(0xFF9C27B0)),
            const SizedBox(height: 20),

            _sectionTitle('COUNTRY-SPECIFIC NOTES'),
            const SizedBox(height: 12),
            _countryNote('Canada', 'Transport Canada ATPL holders can convert to FAA ATP via §61.75. Strong bilateral agreement.'),
            _countryNote('European Union', 'EASA licenses recognized. BASA with US. JAA-to-FAA conversion available.'),
            _countryNote('United Kingdom', 'CAA licenses recognized post-Brexit. Bilateral agreement maintained.'),
            _countryNote('Australia', 'CASA licenses recognized. Strong bilateral agreement with FAA.'),
            _countryNote('India', 'DGCA licenses. No full BASA — must meet FAA requirements independently.'),
            _countryNote('China', 'CAAC licenses. Limited bilateral — full FAA training typically required.'),
            _countryNote('Middle East', 'GCAA (UAE), GACA (Saudi) — check individual country BASA status.'),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.orbitron(
        fontSize: 11,
        color: const Color(0xFF00BCD4),
        letterSpacing: 2,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _infoCard({
    required String title,
    required IconData icon,
    required Color color,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF112240),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white70,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _visaTable() {
    final rows = [
      ['M-1', 'Vocational/Non-Academic', 'Flight training at Part 141 only', 'Allowed with TSA approval'],
      ['F-1', 'Academic Student', 'Flight training at accredited school', 'Allowed with TSA approval'],
      ['B-1/B-2', 'Visitor/Business', 'Recreational only, limited', 'Restricted — consult TSA'],
      ['J-1', 'Exchange Visitor', 'Exchange program training', 'Allowed with TSA approval'],
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF112240),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF1A237E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: ['Visa', 'Type', 'Training', 'TSA'].map((h) => Expanded(
                    child: Text(
                      h,
                      style: GoogleFonts.orbitron(
                        fontSize: 9,
                        color: const Color(0xFF00BCD4),
                        letterSpacing: 1,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )).toList(),
            ),
          ),
          ...rows.map((row) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.white12)),
                ),
                child: Row(
                  children: row.map((cell) => Expanded(
                        child: Text(
                          cell,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.white70,
                            height: 1.4,
                          ),
                        ),
                      )).toList(),
                ),
              )),
        ],
      ),
    );
  }

  Widget _linkCard(String title, String url, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        tileColor: const Color(0xFF112240),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
        ),
        subtitle: Text(
          url,
          style: GoogleFonts.inter(fontSize: 10, color: Colors.white38),
        ),
        trailing: const Icon(Icons.open_in_new, color: Colors.white38, size: 16),
        onTap: () async {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
      ),
    );
  }

  Widget _countryNote(String country, String note) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF112240),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            country,
            style: GoogleFonts.orbitron(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFFFB300),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              note,
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
}
