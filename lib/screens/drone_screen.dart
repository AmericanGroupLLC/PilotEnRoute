import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class DroneScreen extends StatefulWidget {
  const DroneScreen({super.key});

  @override
  State<DroneScreen> createState() => _DroneScreenState();
}

class _DroneScreenState extends State<DroneScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _quizIndex = 0;
  int? _selectedAnswer;
  bool _answered = false;
  int _score = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─── FAA Part 107 Quiz Questions ─────────────────────────────────────────────
  static const List<Map<String, dynamic>> _quizQuestions = [
    {
      'q': 'Under FAA Part 107, what is the maximum altitude for sUAS operations without a waiver?',
      'options': ['200 ft AGL', '400 ft AGL', '500 ft AGL', '1,000 ft AGL'],
      'correct': 1,
      'explanation': 'Part 107 limits sUAS operations to 400 ft AGL, or within 400 ft of a structure.',
    },
    {
      'q': 'What is the maximum groundspeed for a small UAS under Part 107?',
      'options': ['55 mph (87 km/h)', '87 mph (140 km/h)', '100 mph (161 km/h)', '45 mph (72 km/h)'],
      'correct': 0,
      'explanation': 'Part 107 limits sUAS to a maximum groundspeed of 100 mph (87 knots / 55 mph).',
    },
    {
      'q': 'Under Part 107, can you fly a drone over moving vehicles on a public road?',
      'options': [
        'Yes, always',
        'Only with a waiver',
        'Only if below 100 ft',
        'Yes, if in a rural area'
      ],
      'correct': 1,
      'explanation': 'Flying over moving vehicles requires a Part 107 waiver for operations over people.',
    },
    {
      'q': 'What minimum visibility is required for Part 107 drone operations?',
      'options': ['1 statute mile', '3 statute miles', '5 statute miles', '2 statute miles'],
      'correct': 1,
      'explanation': 'Part 107 requires a minimum flight visibility of 3 statute miles from the control station.',
    },
    {
      'q': 'What is required to fly a drone in Class B airspace under Part 107?',
      'options': [
        'No authorization needed',
        'LAANC or FAA authorization',
        'Only a Part 107 certificate',
        'ATC radio communication'
      ],
      'correct': 1,
      'explanation': 'Operations in Class B, C, D, and E airspace require authorization via LAANC or DrC.',
    },
    {
      'q': 'How must a drone be registered with the FAA?',
      'options': [
        'Only drones over 55 lbs',
        'All drones regardless of weight',
        'Drones between 0.55 lbs and 55 lbs',
        'Only commercial drones'
      ],
      'correct': 2,
      'explanation': 'Drones weighing between 0.55 lbs (250g) and 55 lbs must be registered with the FAA.',
    },
    {
      'q': 'Under Part 107, when can you fly at night?',
      'options': [
        'Never',
        'Only with a waiver',
        'With anti-collision lighting visible for 3 statute miles',
        'Only in rural areas'
      ],
      'correct': 2,
      'explanation': 'Night operations are allowed under Part 107 with anti-collision lighting visible for 3 statute miles.',
    },
    {
      'q': 'What does LAANC stand for?',
      'options': [
        'Low Altitude Authorization and Notification Capability',
        'Licensed Airspace Access and Navigation Control',
        'Low Altitude Aircraft Navigation Center',
        'Licensed Authorization for Aerial Navigation and Control'
      ],
      'correct': 0,
      'explanation': 'LAANC is the Low Altitude Authorization and Notification Capability system for drone airspace authorization.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        title: const Text('DRONE EDUCATION'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00BCD4),
          labelStyle: GoogleFonts.orbitron(fontSize: 9, letterSpacing: 1),
          unselectedLabelStyle: GoogleFonts.orbitron(fontSize: 9),
          tabs: const [
            Tab(text: 'OVERVIEW'),
            Tab(text: 'PART 107'),
            Tab(text: 'QUIZ'),
            Tab(text: 'RESOURCES'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildPart107Tab(),
          _buildQuizTab(),
          _buildResourcesTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildHeroBanner(),
          const SizedBox(height: 16),
          _buildCategoryGrid(),
          const SizedBox(height: 16),
          _buildDroneTypes(),
        ],
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00838F), Color(0xFF006064)],
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
              const Icon(Icons.toys, color: Colors.white, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DRONE PILOT EDUCATION',
                      style: GoogleFonts.orbitron(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      'FAA Part 107 | sUAS Operations | Safety',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Everything you need to become a certified Remote Pilot. '
            'Study FAA Part 107 regulations, airspace rules, weather, '
            'and drone operations safety.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid() {
    final categories = [
      {'icon': Icons.gavel, 'title': 'Regulations', 'subtitle': 'FAA Part 107'},
      {'icon': Icons.map, 'title': 'Airspace', 'subtitle': 'Class A-G'},
      {'icon': Icons.cloud, 'title': 'Weather', 'subtitle': 'Drone ops wx'},
      {'icon': Icons.security, 'title': 'Safety', 'subtitle': 'Pre-flight checks'},
      {'icon': Icons.battery_charging_full, 'title': 'Battery', 'subtitle': 'LiPo safety'},
      {'icon': Icons.wifi, 'title': 'RF & Links', 'subtitle': 'Signal management'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: categories.length,
      itemBuilder: (context, i) {
        final cat = categories[i];
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF112240),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF00838F).withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(cat['icon'] as IconData, color: const Color(0xFF00BCD4), size: 28),
              const SizedBox(height: 6),
              Text(
                cat['title'] as String,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                cat['subtitle'] as String,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDroneTypes() {
    final types = [
      {
        'name': 'Multirotor',
        'examples': 'DJI Phantom, Mavic, Mini',
        'use': 'Photography, inspection, delivery',
        'color': const Color(0xFF1565C0),
      },
      {
        'name': 'Fixed Wing',
        'examples': 'Parrot Disco, WingtraOne',
        'use': 'Mapping, surveying, long range',
        'color': const Color(0xFF00695C),
      },
      {
        'name': 'Hybrid VTOL',
        'examples': 'Wingcopter, Quantum-Systems',
        'use': 'Delivery, emergency services',
        'color': const Color(0xFF6A1B9A),
      },
      {
        'name': 'Racing FPV',
        'examples': 'TinyWhoop, 5" freestyle',
        'use': 'Racing, freestyle, FPV sport',
        'color': const Color(0xFFE65100),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DRONE TYPES',
          style: GoogleFonts.orbitron(
            fontSize: 11,
            color: const Color(0xFF00BCD4),
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 10),
        ...types.map((t) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF112240),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (t['color'] as Color).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 50,
                    decoration: BoxDecoration(
                      color: t['color'] as Color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t['name'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          t['examples'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.white60,
                          ),
                        ),
                        Text(
                          t['use'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF00BCD4),
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

  Widget _buildPart107Tab() {
    final rules = [
      {
        'title': 'Maximum Altitude',
        'detail': '400 ft AGL (or within 400 ft of a structure)',
        'icon': Icons.height,
        'color': const Color(0xFF1565C0),
      },
      {
        'title': 'Maximum Groundspeed',
        'detail': '100 mph (87 knots)',
        'icon': Icons.speed,
        'color': const Color(0xFF00695C),
      },
      {
        'title': 'Minimum Visibility',
        'detail': '3 statute miles from control station',
        'icon': Icons.visibility,
        'color': const Color(0xFF6A1B9A),
      },
      {
        'title': 'Cloud Clearance',
        'detail': '500 ft below, 2,000 ft horizontal',
        'icon': Icons.cloud,
        'color': const Color(0xFF37474F),
      },
      {
        'title': 'Daylight Operations',
        'detail': 'Civil twilight with anti-collision lighting',
        'icon': Icons.wb_sunny,
        'color': const Color(0xFFE65100),
      },
      {
        'title': 'Visual Line of Sight',
        'detail': 'Must maintain unaided VLOS at all times',
        'icon': Icons.remove_red_eye,
        'color': const Color(0xFFB71C1C),
      },
      {
        'title': 'Airspace Authorization',
        'detail': 'LAANC or DrC required for controlled airspace',
        'icon': Icons.map,
        'color': const Color(0xFF1B5E20),
      },
      {
        'title': 'Remote ID',
        'detail': 'Broadcast Remote ID required since Sep 2023',
        'icon': Icons.wifi_tethering,
        'color': const Color(0xFF4A148C),
      },
      {
        'title': 'Registration',
        'detail': 'Required for drones 0.55–55 lbs',
        'icon': Icons.assignment,
        'color': const Color(0xFF1A237E),
      },
      {
        'title': 'Certificate Renewal',
        'detail': 'Part 107 certificate valid for 24 months',
        'icon': Icons.card_membership,
        'color': const Color(0xFF004D40),
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rules.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB300).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFFFFB300), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'FAA Part 107 — Small Unmanned Aircraft Systems Rule\n'
                    'Effective August 29, 2016 | Updated 2021 & 2023',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFFFFB300),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        final rule = rules[i - 1];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF112240),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (rule['color'] as Color).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (rule['color'] as Color).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  rule['icon'] as IconData,
                  color: rule['color'] as Color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rule['title'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      rule['detail'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white60,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuizTab() {
    if (_quizIndex >= _quizQuestions.length) {
      return _buildQuizResult();
    }

    final q = _quizQuestions[_quizIndex];
    final options = q['options'] as List<String>;
    final correct = q['correct'] as int;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${_quizIndex + 1} of ${_quizQuestions.length}',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
              ),
              Text(
                'Score: $_score/$_total',
                style: GoogleFonts.orbitron(
                  fontSize: 12,
                  color: const Color(0xFFFFB300),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _quizIndex / _quizQuestions.length,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF00838F)),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 20),
          // Question
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00838F), Color(0xFF006064)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'FAA PART 107',
                    style: GoogleFonts.orbitron(
                      fontSize: 8,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  q['q'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Options
          ...options.asMap().entries.map((entry) {
            final i = entry.key;
            final opt = entry.value;
            Color? bg;
            Color border = Colors.white24;
            Color text = Colors.white;

            if (_answered) {
              if (i == correct) {
                bg = const Color(0xFF4CAF50).withValues(alpha: 0.2);
                border = const Color(0xFF4CAF50);
                text = const Color(0xFF4CAF50);
              } else if (i == _selectedAnswer) {
                bg = const Color(0xFFF44336).withValues(alpha: 0.2);
                border = const Color(0xFFF44336);
                text = const Color(0xFFF44336);
              }
            } else if (i == _selectedAnswer) {
              bg = const Color(0xFF00838F).withValues(alpha: 0.3);
              border = const Color(0xFF00838F);
            }

            return GestureDetector(
              onTap: _answered
                  ? null
                  : () {
                      setState(() {
                        _selectedAnswer = i;
                        _answered = true;
                        _total++;
                        if (i == correct) _score++;
                      });
                    },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: bg ?? const Color(0xFF112240),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        opt,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: text,
                          height: 1.4,
                        ),
                      ),
                    ),
                    if (_answered && i == correct)
                      const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 20),
                    if (_answered && i == _selectedAnswer && i != correct)
                      const Icon(Icons.cancel, color: Color(0xFFF44336), size: 20),
                  ],
                ),
              ),
            );
          }),
          if (_answered) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF112240),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFFB300).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lightbulb, color: Color(0xFFFFB300), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'EXPLANATION',
                        style: GoogleFonts.orbitron(
                          fontSize: 9,
                          color: const Color(0xFFFFB300),
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    q['explanation'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _quizIndex++;
                    _selectedAnswer = null;
                    _answered = false;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00838F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  _quizIndex >= _quizQuestions.length - 1
                      ? 'SEE RESULTS'
                      : 'NEXT QUESTION',
                  style: GoogleFonts.orbitron(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuizResult() {
    final pct = _total > 0 ? (_score / _total * 100).round() : 0;
    final passed = pct >= 70;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (passed ? const Color(0xFF4CAF50) : const Color(0xFFF44336))
                    .withValues(alpha: 0.2),
                border: Border.all(
                  color: passed ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
                  width: 3,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$pct%',
                    style: GoogleFonts.orbitron(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: passed ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
                    ),
                  ),
                  Text(
                    passed ? 'PASS' : 'STUDY',
                    style: GoogleFonts.orbitron(
                      fontSize: 12,
                      color: passed ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              passed ? 'Ready for Part 107!' : 'Keep Studying!',
              style: GoogleFonts.orbitron(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You scored $_score out of $_total correctly.',
              style: GoogleFonts.inter(fontSize: 14, color: Colors.white60),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _quizIndex = 0;
                    _selectedAnswer = null;
                    _answered = false;
                    _score = 0;
                    _total = 0;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00838F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  'RETAKE QUIZ',
                  style: GoogleFonts.orbitron(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResourcesTab() {
    final resources = [
      {
        'title': 'FAA DroneZone',
        'desc': 'Official FAA drone registration and certification portal',
        'url': 'https://faadronezone.faa.gov',
        'icon': Icons.open_in_new,
        'color': const Color(0xFF1B5E20),
      },
      {
        'title': 'B4UFLY App',
        'desc': 'FAA app to check airspace before flying',
        'url': 'https://www.faa.gov/uas/recreational_fliers/where_can_i_fly/b4ufly',
        'icon': Icons.map,
        'color': const Color(0xFF1565C0),
      },
      {
        'title': 'LAANC Authorization',
        'desc': 'Low Altitude Authorization and Notification Capability',
        'url': 'https://www.faa.gov/uas/programs_partnerships/data_exchange',
        'icon': Icons.wifi_tethering,
        'color': const Color(0xFF6A1B9A),
      },
      {
        'title': 'Part 107 Study Guide',
        'desc': 'FAA Remote Pilot Airman Certification Standards',
        'url': 'https://www.faa.gov/training_testing/testing/acs/media/uas_acs.pdf',
        'icon': Icons.menu_book,
        'color': const Color(0xFF00695C),
      },
      {
        'title': 'UAS Data Exchange',
        'desc': 'FAA UAS facility maps and airspace data',
        'url': 'https://udds-faa.opendata.arcgis.com',
        'icon': Icons.data_usage,
        'color': const Color(0xFFE65100),
      },
      {
        'title': 'Remote ID Rule',
        'desc': 'FAA Remote ID requirements effective Sep 2023',
        'url': 'https://www.faa.gov/uas/getting_started/remote_id',
        'icon': Icons.broadcast_on_personal,
        'color': const Color(0xFF37474F),
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: resources.length,
      itemBuilder: (context, i) {
        final r = resources[i];
        return GestureDetector(
          onTap: () async {
            final uri = Uri.parse(r['url'] as String);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF112240),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (r['color'] as Color).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (r['color'] as Color).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    r['icon'] as IconData,
                    color: r['color'] as Color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r['title'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        r['desc'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white54,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.open_in_new, color: Colors.white38, size: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}
