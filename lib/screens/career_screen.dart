import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

/// A national annual median wage published by the U.S. Bureau of Labor
/// Statistics (Occupational Employment and Wage Statistics).
class BlsMedianPay {
  final String occupation;
  final int annualUsd;
  final String year;

  const BlsMedianPay({
    required this.occupation,
    required this.annualUsd,
    required this.year,
  });
}

/// OEWS series: national, all industries, annual median wage (datatype 13).
const Map<String, String> _blsSeries = {
  'OEUN000000000000053201113': 'Airline pilots, copilots & flight engineers',
  'OEUN000000000000053201213': 'Commercial pilots',
  'OEUN000000000000053202113': 'Air traffic controllers',
};

/// Fetches the latest median pay from the free, keyless BLS Public Data API.
/// Throws on any failure; the caller shows an error rather than a number.
Future<List<BlsMedianPay>> fetchBlsMedianPay() async {
  final response = await http
      .post(
        Uri.parse('https://api.bls.gov/publicAPI/v2/timeseries/data/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'seriesid': _blsSeries.keys.toList()}),
      )
      .timeout(const Duration(seconds: 15));
  if (response.statusCode != 200) {
    throw http.ClientException('BLS ${response.statusCode}');
  }
  final decoded = jsonDecode(response.body);
  final series = (decoded is Map && decoded['Results'] is Map)
      ? (decoded['Results'] as Map)['series']
      : null;
  if (series is! List) throw const FormatException('BLS: no series');

  final out = <BlsMedianPay>[];
  for (final s in series) {
    if (s is! Map) continue;
    final label = _blsSeries[s['seriesID']];
    final data = s['data'];
    if (label == null || data is! List || data.isEmpty) continue;
    final latest = data.first;
    if (latest is! Map) continue;
    final value = int.tryParse('${latest['value']}');
    final year = latest['year'];
    if (value == null || year is! String) continue;
    out.add(BlsMedianPay(occupation: label, annualUsd: value, year: year));
  }
  if (out.isEmpty) throw const FormatException('BLS: no data');
  return out;
}

class CareerScreen extends StatefulWidget {
  const CareerScreen({super.key});

  @override
  State<CareerScreen> createState() => _CareerScreenState();
}

class _CareerScreenState extends State<CareerScreen> {
  late Future<List<BlsMedianPay>> _pay = fetchBlsMedianPay();

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
              hours: '1,500h ATP minimum',
              icon: Icons.flight,
              color: const Color(0xFF00BCD4),
              description: 'Fly scheduled passenger or cargo routes for Part 121 carriers. '
                  'Start at regional airlines and upgrade to major carriers.',
            ),
            _careerCard(
              title: 'Corporate / Charter Pilot',
              subtitle: 'Part 91 / 135 Operations',
              hours: '500–1,000h typical',
              icon: Icons.business,
              color: const Color(0xFFFFB300),
              description: 'Fly executives, celebrities, or charter clients in business jets. '
                  'More flexibility, varied schedules.',
            ),
            _careerCard(
              title: 'Flight Instructor (CFI)',
              subtitle: 'Build Hours & Teach',
              hours: '250h CPL minimum',
              icon: Icons.school,
              color: const Color(0xFF4CAF50),
              description: 'Train the next generation of pilots. Excellent way to build '
                  'flight hours toward airline minimums.',
            ),
            _careerCard(
              title: 'Military Pilot',
              subtitle: 'Air Force, Navy, Army, Marines',
              hours: 'Military training pathway',
              icon: Icons.military_tech,
              color: const Color(0xFFF44336),
              description: 'Fly military aircraft with full training provided. '
                  'Excellent transition to civilian aviation.',
            ),
            _careerCard(
              title: 'UAS / Drone Pilot',
              subtitle: 'Part 107 Commercial',
              hours: 'Part 107 certificate only',
              icon: Icons.flight_takeoff,
              color: const Color(0xFF9C27B0),
              description: 'Growing field in photography, inspection, agriculture, '
                  'public safety, and delivery operations.',
            ),
            _careerCard(
              title: 'Air Traffic Controller',
              subtitle: 'FAA / TRACON / ARTCC',
              hours: 'No flight hours required',
              icon: Icons.radar,
              color: const Color(0xFFFF9800),
              description: 'Manage aircraft in controlled airspace. Requires FAA Academy '
                  'training and passing medical/aptitude tests.',
            ),
            const SizedBox(height: 20),
            _sectionHeader('MEDIAN PAY (U.S. BLS)'),
            const SizedBox(height: 12),
            _medianPay(),
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
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
                  color: color.withValues(alpha: 0.15),
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
          // Wrap, not Row: on a folded cover display (and at a large text
          // scale) a badge may not fit, so it wraps instead of overflowing.
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.inter(fontSize: 11, color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _medianPay() {
    final money = NumberFormat.currency(
        locale: 'en_US', symbol: '\$', decimalDigits: 0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF112240),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: FutureBuilder<List<BlsMedianPay>>(
        future: _pay,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00BCD4)),
            );
          }
          if (snap.hasError || !snap.hasData) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pay data unavailable right now (BLS).',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => _pay = fetchBlsMedianPay()),
                  child: const Text('Retry'),
                ),
              ],
            );
          }
          final rows = snap.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.occupation,
                          style: GoogleFonts.inter(
                              fontSize: 12, color: Colors.white70),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${money.format(r.annualUsd)}/yr',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF4CAF50),
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                'National annual median wage, U.S. Bureau of Labor '
                'Statistics OEWS, ${rows.first.year}. Pay varies widely by '
                'employer, seniority and region.',
                style: GoogleFonts.inter(fontSize: 10, color: Colors.white38),
              ),
            ],
          );
        },
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
