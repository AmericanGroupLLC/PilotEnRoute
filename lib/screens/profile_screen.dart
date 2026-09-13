import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _nameCtrl = TextEditingController();
  final _certCtrl = TextEditingController();
  String _pilotLevel = 'Student Pilot';
  String _medicalClass = '3rd Class';
  DateTime? _medicalExpiry;
  DateTime? _bfrExpiry;
  bool _loading = true;

  final List<String> _pilotLevels = [
    'Student Pilot',
    'Sport Pilot',
    'Recreational Pilot',
    'Private Pilot',
    'Commercial Pilot',
    'ATP',
    'Flight Instructor (CFI)',
    'Remote Pilot (Part 107)',
  ];

  final List<String> _medicalClasses = [
    '1st Class (12 months)',
    '2nd Class (12 months)',
    '3rd Class (24/60 months)',
    'BasicMed',
    'Sport Pilot (Driver\'s License)',
    'None Required',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _certCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameCtrl.text = prefs.getString('profile_name') ?? '';
      _certCtrl.text = prefs.getString('profile_cert') ?? '';
      _pilotLevel = prefs.getString('profile_level') ?? 'Student Pilot';
      _medicalClass = prefs.getString('profile_medical') ?? '3rd Class (24/60 months)';
      final medExp = prefs.getString('profile_medical_expiry');
      if (medExp != null) _medicalExpiry = DateTime.parse(medExp);
      final bfrExp = prefs.getString('profile_bfr_expiry');
      if (bfrExp != null) _bfrExpiry = DateTime.parse(bfrExp);
      _loading = false;
    });
  }

  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_name', _nameCtrl.text);
    await prefs.setString('profile_cert', _certCtrl.text);
    await prefs.setString('profile_level', _pilotLevel);
    await prefs.setString('profile_medical', _medicalClass);
    if (_medicalExpiry != null) {
      await prefs.setString('profile_medical_expiry', _medicalExpiry!.toIso8601String());
    }
    if (_bfrExpiry != null) {
      await prefs.setString('profile_bfr_expiry', _bfrExpiry!.toIso8601String());
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Profile saved', style: GoogleFonts.inter()),
        backgroundColor: const Color(0xFF4CAF50),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        title: const Text('PILOT PROFILE'),
        actions: [
          IconButton(
            tooltip: 'Save',
            icon: const Icon(Icons.save),
            onPressed: _saveProfile,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00BCD4),
          labelStyle: GoogleFonts.orbitron(fontSize: 9, letterSpacing: 1),
          tabs: const [
            Tab(text: 'PROFILE'),
            Tab(text: 'MEDICAL'),
            Tab(text: 'AME FINDER'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildProfileTab(),
                _buildMedicalTab(),
                _buildAmeFinderTab(),
              ],
            ),
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Center(
            child: Stack(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF00BCD4), Color(0xFF0097A7)],
                    ),
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 48),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFB300),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit, color: Colors.black, size: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _formField(_nameCtrl, 'Full Name', 'John Smith'),
          const SizedBox(height: 12),
          _formField(_certCtrl, 'Certificate Number', 'A1234567'),
          const SizedBox(height: 16),
          _sectionLabel('PILOT CERTIFICATE LEVEL'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _pilotLevel,
            dropdownColor: const Color(0xFF112240),
            style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(),
            items: _pilotLevels.map((level) => DropdownMenuItem(
              value: level,
              child: Text(level),
            )).toList(),
            onChanged: (v) => setState(() => _pilotLevel = v!),
          ),
          const SizedBox(height: 24),
          _sectionLabel('CERTIFICATE PRIVILEGES'),
          const SizedBox(height: 12),
          _privilegesCard(_pilotLevel),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveProfile,
              child: Text(
                'SAVE PROFILE',
                style: GoogleFonts.orbitron(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalTab() {
    final now = DateTime.now();
    final medDaysLeft = _medicalExpiry?.difference(now).inDays;
    final bfrDaysLeft = _bfrExpiry?.difference(now).inDays;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('MEDICAL CERTIFICATE CLASS'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _medicalClass,
            dropdownColor: const Color(0xFF112240),
            style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(),
            items: _medicalClasses.map((c) => DropdownMenuItem(
              value: c,
              child: Text(c),
            )).toList(),
            onChanged: (v) => setState(() => _medicalClass = v!),
          ),
          const SizedBox(height: 20),
          _sectionLabel('MEDICAL EXPIRATION DATE'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _medicalExpiry ?? DateTime.now().add(const Duration(days: 365)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 1825)),
                builder: (ctx, child) => Theme(
                  data: ThemeData.dark().copyWith(
                    colorScheme: const ColorScheme.dark(primary: Color(0xFF00BCD4)),
                  ),
                  child: child!,
                ),
              );
              if (date != null) setState(() => _medicalExpiry = date);
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF112240),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: Color(0xFF00BCD4), size: 18),
                  const SizedBox(width: 12),
                  Text(
                    _medicalExpiry != null
                        ? '${_medicalExpiry!.month}/${_medicalExpiry!.day}/${_medicalExpiry!.year}'
                        : 'Tap to set expiration date',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: _medicalExpiry != null ? Colors.white : Colors.white38,
                    ),
                  ),
                  const Spacer(),
                  if (medDaysLeft != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: medDaysLeft > 60
                            ? const Color(0xFF4CAF50).withValues(alpha: 0.15)
                            : medDaysLeft > 0
                                ? const Color(0xFFFFB300).withValues(alpha: 0.15)
                                : const Color(0xFFF44336).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        medDaysLeft > 0 ? '$medDaysLeft days' : 'EXPIRED',
                        style: GoogleFonts.orbitron(
                          fontSize: 9,
                          color: medDaysLeft > 60
                              ? const Color(0xFF4CAF50)
                              : medDaysLeft > 0
                                  ? const Color(0xFFFFB300)
                                  : const Color(0xFFF44336),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _sectionLabel('FLIGHT REVIEW (BFR) EXPIRATION'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _bfrExpiry ?? DateTime.now().add(const Duration(days: 730)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 1825)),
                builder: (ctx, child) => Theme(
                  data: ThemeData.dark().copyWith(
                    colorScheme: const ColorScheme.dark(primary: Color(0xFF00BCD4)),
                  ),
                  child: child!,
                ),
              );
              if (date != null) setState(() => _bfrExpiry = date);
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF112240),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  const Icon(Icons.assignment_turned_in, color: Color(0xFFFFB300), size: 18),
                  const SizedBox(width: 12),
                  Text(
                    _bfrExpiry != null
                        ? '${_bfrExpiry!.month}/${_bfrExpiry!.day}/${_bfrExpiry!.year}'
                        : 'Tap to set BFR date',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: _bfrExpiry != null ? Colors.white : Colors.white38,
                    ),
                  ),
                  const Spacer(),
                  if (bfrDaysLeft != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: bfrDaysLeft > 90
                            ? const Color(0xFF4CAF50).withValues(alpha: 0.15)
                            : bfrDaysLeft > 0
                                ? const Color(0xFFFFB300).withValues(alpha: 0.15)
                                : const Color(0xFFF44336).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        bfrDaysLeft > 0 ? '$bfrDaysLeft days' : 'EXPIRED',
                        style: GoogleFonts.orbitron(
                          fontSize: 9,
                          color: bfrDaysLeft > 90
                              ? const Color(0xFF4CAF50)
                              : bfrDaysLeft > 0
                                  ? const Color(0xFFFFB300)
                                  : const Color(0xFFF44336),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _medicalGuideCard(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveProfile,
              child: Text(
                'SAVE MEDICAL INFO',
                style: GoogleFonts.orbitron(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmeFinderTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF112240),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.medical_services, color: Color(0xFF4CAF50), size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'FIND AN FAA AME',
                      style: GoogleFonts.orbitron(
                        fontSize: 12,
                        color: const Color(0xFF4CAF50),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Aviation Medical Examiners (AMEs) are FAA-designated physicians '
                  'authorized to perform aviation medical exams.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _launchUrl('https://www.faa.gov/pilots/amelocator'),
                    icon: const Icon(Icons.search, size: 16),
                    label: Text(
                      'SEARCH FAA AME LOCATOR',
                      style: GoogleFonts.orbitron(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _sectionLabel('MEDICAL CERTIFICATE REQUIREMENTS'),
          const SizedBox(height: 12),
          _medicalClassCard(
            '1st Class',
            const Color(0xFFF44336),
            'Required for ATP operations',
            [
              'Under 40: Valid for 12 months',
              'Age 40+: Valid for 6 months',
              'Most stringent requirements',
              'Vision: 20/20 corrected, 20/100 uncorrected',
              'EKG required at first exam and age 35+',
            ],
          ),
          _medicalClassCard(
            '2nd Class',
            const Color(0xFFFFB300),
            'Required for Commercial Pilot operations',
            [
              'Valid for 12 months',
              'Vision: 20/20 corrected, 20/100 uncorrected',
              'Hearing: Conversational voice at 6 feet',
              'Blood pressure: 155/95 or less',
            ],
          ),
          _medicalClassCard(
            '3rd Class',
            const Color(0xFF4CAF50),
            'Required for Private Pilot operations',
            [
              'Under 40: Valid for 60 months (5 years)',
              'Age 40+: Valid for 24 months (2 years)',
              'Vision: 20/40 corrected',
              'Most accessible requirements',
            ],
          ),
          _medicalClassCard(
            'BasicMed',
            const Color(0xFF00BCD4),
            'Alternative to 3rd Class for private ops',
            [
              'Valid for 48 months',
              'Must hold valid US driver\'s license',
              'Online medical education course required',
              'Physician exam every 48 months',
              'Aircraft under 6,000 lbs, max 5 passengers',
              'Max 18,000 ft MSL, 250 KIAS',
            ],
          ),
          const SizedBox(height: 20),
          _sectionLabel('COMMON DISQUALIFYING CONDITIONS'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF112240),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                _conditionRow('Diabetes (insulin-treated)', 'Special Issuance possible'),
                _conditionRow('Heart conditions', 'Case-by-case evaluation'),
                _conditionRow('Epilepsy/Seizures', 'Generally disqualifying'),
                _conditionRow('Substance dependence', 'Recovery program required'),
                _conditionRow('Psychiatric conditions', 'HIMS AME evaluation'),
                _conditionRow('Vision below standards', 'Corrective lenses allowed'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _launchUrl('https://www.faa.gov/pilots/medical_certification'),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1A237E).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF3F51B5).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.open_in_new, color: Color(0xFF7986CB), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'FAA Medical Certification Information',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF7986CB),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _medicalClassCard(String cls, Color color, String subtitle, List<String> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF112240),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$cls Medical',
                  style: GoogleFonts.orbitron(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                subtitle,
                style: GoogleFonts.inter(fontSize: 11, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.circle, color: color, size: 5),
                    const SizedBox(width: 8),
                    Text(
                      item,
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _conditionRow(String condition, String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              condition,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB300).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: const Color(0xFFFFB300),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _medicalGuideCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF112240),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MEDICAL RENEWAL TIPS',
            style: GoogleFonts.orbitron(
              fontSize: 10,
              color: const Color(0xFF00BCD4),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          _tipItem('Schedule AME appointment 60 days before expiry'),
          _tipItem('Review AOPA\'s medical certification guide'),
          _tipItem('Disclose all medications honestly — omission is worse'),
          _tipItem('Use MedXPress to pre-fill FAA Form 8500-8'),
          _tipItem('Keep copies of all medical records'),
          _tipItem('Consider HIMS AME for complex medical histories'),
        ],
      ),
    );
  }

  Widget _tipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, color: Color(0xFF4CAF50), size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _privilegesCard(String level) {
    final privileges = {
      'Student Pilot': ['Solo flight with instructor endorsement', 'Cannot carry passengers', 'Cannot fly for compensation'],
      'Private Pilot': ['Carry passengers', 'Fly for personal/business use', 'Cannot fly for compensation'],
      'Commercial Pilot': ['Fly for compensation or hire', 'Carry passengers for hire', 'Requires 2nd Class medical'],
      'ATP': ['Serve as PIC of airline transport operations', 'Highest pilot certificate', 'Required for Part 121 operations'],
      'Flight Instructor (CFI)': ['Provide flight instruction', 'Sign off student endorsements', 'Conduct flight reviews'],
      'Remote Pilot (Part 107)': ['Fly UAS commercially', 'No medical certificate required', 'Must pass Part 107 knowledge test'],
    };

    final items = privileges[level] ?? ['Certificate privileges vary by operation'];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF112240),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF00BCD4).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.verified, color: Color(0xFF00BCD4), size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            )).toList(),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.orbitron(
        fontSize: 10,
        color: Colors.white54,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _formField(TextEditingController ctrl, String label, String hint) {
    return TextFormField(
      controller: ctrl,
      style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
