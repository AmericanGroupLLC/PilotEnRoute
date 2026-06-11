import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class EducationScreen extends StatelessWidget {
  const EducationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(title: const Text('FAA EDUCATION HUB')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildCertificatePathway(context),
            const SizedBox(height: 20),
            _buildHandbooks(),
            const SizedBox(height: 20),
            _buildAirspaceGuide(),
            const SizedBox(height: 20),
            _buildRegulations(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00695C), Color(0xFF004D40)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FAA EDUCATION HUB',
            style: GoogleFonts.orbitron(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'From Student Pilot to ATP — complete FAA knowledge base, '
            'handbooks, regulations, and certification pathways.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificatePathway(BuildContext context) {
    final certs = [
      {'title': 'Student Pilot', 'hours': '0 hrs', 'color': const Color(0xFF4CAF50), 'icon': Icons.school},
      {'title': 'Sport Pilot', 'hours': '20 hrs', 'color': const Color(0xFF8BC34A), 'icon': Icons.flight},
      {'title': 'Private Pilot (PPL)', 'hours': '40 hrs', 'color': const Color(0xFF00BCD4), 'icon': Icons.flight_takeoff},
      {'title': 'Instrument Rating', 'hours': '50 hrs XC', 'color': const Color(0xFF2196F3), 'icon': Icons.cloud},
      {'title': 'Commercial Pilot', 'hours': '250 hrs', 'color': const Color(0xFFFFB300), 'icon': Icons.star},
      {'title': 'CFI / CFII', 'hours': '250+ hrs', 'color': const Color(0xFFFF9800), 'icon': Icons.person_pin},
      {'title': 'ATP Certificate', 'hours': '1,500 hrs', 'color': const Color(0xFFF44336), 'icon': Icons.workspace_premium},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CERTIFICATION PATHWAY',
          style: GoogleFonts.orbitron(
            fontSize: 11,
            color: const Color(0xFF00BCD4),
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        ...certs.asMap().entries.map((entry) {
          final i = entry.key;
          final cert = entry.value;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: (cert['color'] as Color).withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: cert['color'] as Color, width: 2),
                    ),
                    child: Icon(cert['icon'] as IconData, color: cert['color'] as Color, size: 16),
                  ),
                  if (i < certs.length - 1)
                    Container(
                      width: 2,
                      height: 40,
                      color: Colors.white12,
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF112240),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: (cert['color'] as Color).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          cert['title'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (cert['color'] as Color).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          cert['hours'] as String,
                          style: GoogleFonts.orbitron(
                            fontSize: 9,
                            color: cert['color'] as Color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildHandbooks() {
    final books = [
      {
        'title': 'Pilot\'s Handbook of Aeronautical Knowledge',
        'abbr': 'PHAK',
        'url': 'https://www.faa.gov/regulations_policies/handbooks_manuals/aviation/phak',
        'color': const Color(0xFF1565C0),
      },
      {
        'title': 'Airplane Flying Handbook',
        'abbr': 'AFH',
        'url': 'https://www.faa.gov/regulations_policies/handbooks_manuals/aviation/airplane_handbook',
        'color': const Color(0xFF00695C),
      },
      {
        'title': 'Instrument Flying Handbook',
        'abbr': 'IFH',
        'url': 'https://www.faa.gov/regulations_policies/handbooks_manuals/aviation/instrument_flying_handbook',
        'color': const Color(0xFF6A1B9A),
      },
      {
        'title': 'Aeronautical Information Manual',
        'abbr': 'AIM',
        'url': 'https://www.faa.gov/air_traffic/publications/atpubs/aim_html/',
        'color': const Color(0xFFE65100),
      },
      {
        'title': 'Aviation Weather Handbook',
        'abbr': 'AWH',
        'url': 'https://www.faa.gov/regulations_policies/handbooks_manuals/aviation/faa-h-8083-28',
        'color': const Color(0xFF1B5E20),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FAA HANDBOOKS',
          style: GoogleFonts.orbitron(
            fontSize: 11,
            color: const Color(0xFF00BCD4),
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 10),
        ...books.map((b) => GestureDetector(
              onTap: () async {
                final uri = Uri.parse(b['url'] as String);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF112240),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: (b['color'] as Color).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (b['color'] as Color).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          b['abbr'] as String,
                          style: GoogleFonts.orbitron(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: b['color'] as Color,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        b['title'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const Icon(Icons.open_in_new, color: Colors.white38, size: 16),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildAirspaceGuide() {
    final classes = [
      {'class': 'A', 'alt': '18,000 ft MSL – FL600', 'req': 'IFR only, ATC clearance', 'color': const Color(0xFFF44336)},
      {'class': 'B', 'alt': 'Surface – 10,000 ft MSL', 'req': 'ATC clearance, Mode C transponder', 'color': const Color(0xFF2196F3)},
      {'class': 'C', 'alt': 'Surface – 4,000 ft AGL', 'req': 'Two-way radio, Mode C transponder', 'color': const Color(0xFF9C27B0)},
      {'class': 'D', 'alt': 'Surface – 2,500 ft AGL', 'req': 'Two-way radio communication', 'color': const Color(0xFF00BCD4)},
      {'class': 'E', 'alt': 'Various', 'req': 'VFR: no clearance; IFR: clearance', 'color': const Color(0xFF4CAF50)},
      {'class': 'G', 'alt': 'Surface – Class E floor', 'req': 'No ATC clearance required', 'color': const Color(0xFF9E9E9E)},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AIRSPACE CLASSES',
          style: GoogleFonts.orbitron(
            fontSize: 11,
            color: const Color(0xFF00BCD4),
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 10),
        ...classes.map((c) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF112240),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: (c['color'] as Color).withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c['color'] as Color,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        'Class\n${c['class']}',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.orbitron(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c['alt'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          c['req'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.white54,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildRegulations() {
    final regs = [
      {'title': '14 CFR Part 61 — Certification: Pilots', 'url': 'https://www.ecfr.gov/current/title-14/chapter-I/subchapter-D/part-61'},
      {'title': '14 CFR Part 91 — General Operating Rules', 'url': 'https://www.ecfr.gov/current/title-14/chapter-I/subchapter-F/part-91'},
      {'title': '14 CFR Part 107 — Small UAS (Drones)', 'url': 'https://www.ecfr.gov/current/title-14/chapter-I/subchapter-F/part-107'},
      {'title': '14 CFR Part 135 — Air Carrier Operations', 'url': 'https://www.ecfr.gov/current/title-14/chapter-I/subchapter-G/part-135'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FAA REGULATIONS (CFR)',
          style: GoogleFonts.orbitron(
            fontSize: 11,
            color: const Color(0xFF00BCD4),
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 10),
        ...regs.map((r) => GestureDetector(
              onTap: () async {
                final uri = Uri.parse(r['url']!);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF112240),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.gavel, color: Color(0xFF00BCD4), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        r['title']!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Icon(Icons.open_in_new, color: Colors.white38, size: 14),
                  ],
                ),
              ),
            )),
      ],
    );
  }
}
