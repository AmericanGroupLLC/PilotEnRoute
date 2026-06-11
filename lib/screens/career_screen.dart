import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CareerScreen extends StatelessWidget {
  const CareerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(title: const Text('AVIATION CAREERS')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('CAREER OVERVIEW'),
            const SizedBox(height: 12),
            _careerCard(
              title: 'Airline Pilot',
              subtitle: 'Regional → Major Carrier',
              salary: '\$80K–\$350K+',
              hours: '1,500h ATP minimum',
              icon: Icons.flight,
              color: const Color(0xFF00BCD4),
              description: 'Fly scheduled passenger or cargo routes for Part 121 carriers. '
                  'Start at regional airlines and upgrade to major carriers.',
            ),
            _careerCard(
              title: 'Corporate / Charter Pilot',
              subtitle: 'Part 91 / 135 Operations',
              salary: '\$60K–\$200K+',
              hours: '500–1,000h typical',
              icon: Icons.business,
              color: const Color(0xFFFFB300),
              description: 'Fly executives, celebrities, or charter clients in business jets. '
                  'More flexibility, varied schedules.',
            ),
            _careerCard(
              title: 'Flight Instructor (CFI)',
              subtitle: 'Build Hours & Teach',
              salary: '\$40K–\$80K',
              hours: '250h CPL minimum',
              icon: Icons.school,
              color: const Color(0xFF4CAF50),
              description: 'Train the next generation of pilots. Excellent way to build '
                  'flight hours toward airline minimums.',
            ),
            _careerCard(
              title: 'Military Pilot',
              subtitle: 'Air Force, Navy, Army, Marines',
              salary: '\$50K–\$130K + benefits',
              hours: 'Military training pathway',
              icon: Icons.military_tech,
              color: const Color(0xFFF44336),
              description: 'Fly military aircraft with full training provided. '
                  'Excellent transition to civilian aviation.',
            ),
            _careerCard(
              title: 'UAS / Drone Pilot',
              subtitle: 'Part 107 Commercial',
              salary: '\$45K–\$120K',
              hours: 'Part 107 certificate only',
              icon: Icons.flight_takeoff,
              color: const Color(0xFF9C27B0),
              description: 'Growing field in photography, inspection, agriculture, '
                  'public safety, and delivery operations.',
            ),
            _careerCard(
              title: 'Air Traffic Controller',
              subtitle: 'FAA / TRACON / ARTCC',
              salary: '\$70K–\$180K',
              hours: 'No flight hours required',
              icon: Icons.radar,
              color: const Color(0xFFFF9800),
              description: 'Manage aircraft in controlled airspace. Requires FAA Academy '
                  'training and passing medical/aptitude tests.',
            ),
            const SizedBox(height: 20),
            _sectionHeader('SALARY COMPARISON'),
            const SizedBox(height: 12),
            _salaryChart(),
            const SizedBox(height: 20),
            _sectionHeader('TOP AVIATION EMPLOYERS'),
            const SizedBox(height: 12),
            _employerGrid(),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
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

  Widget _careerCard({
    required String title,
    required String subtitle,
    required String salary,
    required String hours,
    required IconData icon,
    required Color color,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF112240),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, height: 1.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _badge(Icons.attach_money, salary, const Color(0xFF4CAF50)),
              const SizedBox(width: 10),
              _badge(Icons.access_time, hours, const Color(0xFFFFB300)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(fontSize: 11, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _salaryChart() {
    final data = [
      ('Major Airline Capt.', 0.95, const Color(0xFF00BCD4)),
      ('Major Airline FO', 0.7, const Color(0xFF2196F3)),
      ('Corporate Capt.', 0.55, const Color(0xFFFFB300)),
      ('Regional Capt.', 0.45, const Color(0xFF4CAF50)),
      ('ATC', 0.4, const Color(0xFFFF9800)),
      ('Regional FO', 0.3, const Color(0xFF9C27B0)),
      ('CFI', 0.2, const Color(0xFF607D8B)),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF112240),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: data.map((d) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 130,
                  child: Text(
                    d.$1,
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.white70),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: d.$2,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation(d.$3),
                      minHeight: 8,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _employerGrid() {
    final employers = [
      'Delta Air Lines', 'United Airlines', 'American Airlines',
      'Southwest Airlines', 'FedEx', 'UPS Airlines',
      'NetJets', 'FlexJet', 'Atlas Air',
      'SkyWest Airlines', 'Endeavor Air', 'Republic Airways',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: employers.map((e) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF112240),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          e,
          style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
        ),
      )).toList(),
    );
  }
}
