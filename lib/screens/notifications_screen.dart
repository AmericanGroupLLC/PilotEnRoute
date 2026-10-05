import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agl_i18n/agl_i18n.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  Map<String, bool> _settings = {};
  bool _loading = true;

  final List<Map<String, dynamic>> _notificationGroups = [
    {
      'group': 'CURRENCY & MEDICAL',
      'color': const Color(0xFFF44336),
      'items': [
        {'key': 'medical_reminder', 'title': 'FAA Medical Renewal', 'desc': 'Remind 60 days before expiration', 'icon': Icons.medical_services},
        {'key': 'bfr_reminder', 'title': 'Flight Review (BFR)', 'desc': 'Remind 30 days before 24-month expiry', 'icon': Icons.assignment_turned_in},
        {'key': 'ipc_reminder', 'title': 'IPC / IFR Currency', 'desc': 'Alert when IFR currency is lapsing', 'icon': Icons.cloud},
        {'key': 'passenger_currency', 'title': 'Passenger Currency', 'desc': 'Alert when 90-day currency is lapsing', 'icon': Icons.people},
        {'key': 'night_currency', 'title': 'Night Currency', 'desc': 'Alert when night passenger currency lapses', 'icon': Icons.nightlight_round},
      ],
    },
    {
      'group': 'FAA ALERTS',
      'color': const Color(0xFFFFB300),
      'items': [
        {'key': 'faa_notam', 'title': 'FAA NOTAMs', 'desc': 'New NOTAMs for saved airports', 'icon': Icons.warning_amber},
        {'key': 'faa_tfr', 'title': 'TFR Alerts', 'desc': 'New Temporary Flight Restrictions', 'icon': Icons.block},
        {'key': 'faa_airworthiness', 'title': 'Airworthiness Directives', 'desc': 'New ADs for your aircraft type', 'icon': Icons.build},
        {'key': 'faa_rule_changes', 'title': 'FAA Rule Changes', 'desc': 'New regulations and NPRM notices', 'icon': Icons.gavel},
      ],
    },
    {
      'group': 'WEATHER',
      'color': const Color(0xFF2196F3),
      'items': [
        {'key': 'wx_sigmet', 'title': 'SIGMETs', 'desc': 'Significant meteorological advisories', 'icon': Icons.thunderstorm},
        {'key': 'wx_airmet', 'title': 'AIRMETs', 'desc': 'Airmen meteorological information', 'icon': Icons.air},
        {'key': 'wx_pirep', 'title': 'PIREPs', 'desc': 'Pilot weather reports for your route', 'icon': Icons.report},
      ],
    },
    {
      'group': 'TRAINING REMINDERS',
      'color': const Color(0xFF4CAF50),
      'items': [
        {'key': 'daily_question', 'title': 'Daily Knowledge Question', 'desc': 'One FAA question every morning', 'icon': Icons.quiz},
        {'key': 'study_streak', 'title': 'Study Streak', 'desc': 'Keep your daily study streak alive', 'icon': Icons.local_fire_department},
        {'key': 'exam_prep', 'title': 'Exam Preparation', 'desc': 'Scheduled study session reminders', 'icon': Icons.school},
        {'key': 'flashcard_review', 'title': 'Flashcard Review', 'desc': 'Spaced repetition review reminders', 'icon': Icons.style},
      ],
    },
    {
      'group': 'PILOT LEVEL SPECIFIC',
      'color': const Color(0xFF9C27B0),
      'items': [
        {'key': 'student_solo', 'title': 'Solo Endorsement Expiry', 'desc': 'Student pilot 90-day solo endorsement', 'icon': Icons.flight_takeoff},
        {'key': 'ppl_milestones', 'title': 'PPL Milestones', 'desc': 'Hour milestones toward Private Pilot', 'icon': Icons.flag},
        {'key': 'instrument_currency', 'title': 'Instrument Approaches Due', 'desc': 'Track 6-approach IFR requirement', 'icon': Icons.radar},
        {'key': 'atp_hours', 'title': 'ATP Hour Milestones', 'desc': 'Progress toward 1,500h ATP minimum', 'icon': Icons.workspace_premium},
      ],
    },
    {
      'group': 'FLIGHT TRACKING',
      'color': const Color(0xFF00BCD4),
      'items': [
        {'key': 'tracked_flight', 'title': 'Tracked Flight Updates', 'desc': 'Status updates for tracked flights', 'icon': Icons.flight},
        {'key': 'airport_delays', 'title': 'Airport Delay Alerts', 'desc': 'Ground delay programs at saved airports', 'icon': Icons.access_time},
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = <String, bool>{};
    for (final group in _notificationGroups) {
      for (final item in group['items'] as List) {
        final key = item['key'] as String;
        settings[key] = prefs.getBool('notif_$key') ?? true;
      }
    }
    setState(() {
      _settings = settings;
      _loading = false;
    });
  }

  Future<void> _toggleSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_$key', value);
    setState(() => _settings[key] = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        title: Text((AglL10n.of(context)?.navNotifications ?? 'Notifications')),
        actions: [
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              final allOn = _settings.values.every((v) => v);
              for (final key in _settings.keys) {
                await prefs.setBool('notif_$key', !allOn);
              }
              setState(() {
                for (final key in _settings.keys) {
                  _settings[key] = !allOn;
                }
              });
            },
            child: Text(
              _settings.values.every((v) => v) ? 'DISABLE ALL' : 'ENABLE ALL',
              style: GoogleFonts.orbitron(
                fontSize: 9,
                color: const Color(0xFF00BCD4),
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A237E).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF3F51B5).withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active, color: Color(0xFF7986CB), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Stay current and safe with intelligent pilot notifications. '
                          'Customize alerts based on your certificate level.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white70,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ..._notificationGroups.map((group) => _buildGroup(group)),
              ],
            ),
    );
  }

  Widget _buildGroup(Map<String, dynamic> group) {
    final color = group['color'] as Color;
    final items = group['items'] as List;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF112240),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              group['group'] as String,
              style: GoogleFonts.orbitron(
                fontSize: 10,
                color: color,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value as Map<String, dynamic>;
            final key = item['key'] as String;
            return Column(
              children: [
                if (i > 0) const Divider(height: 1, color: Colors.white12),
                SwitchListTile(
                  value: _settings[key] ?? true,
                  onChanged: (v) => _toggleSetting(key, v),
                  activeThumbColor: color,
                  secondary: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(item['icon'] as IconData, color: color, size: 18),
                  ),
                  title: Text(
                    item['title'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    item['desc'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
        ),
      ),
    );
  }
}
