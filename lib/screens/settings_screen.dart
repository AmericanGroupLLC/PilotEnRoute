import 'package:agl_ads/agl_ads.dart';
import 'package:agl_i18n/agl_i18n.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/legality/date_text.dart';
import '../core/legality/pilot_profile.dart';
import '../services/settings_store.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'minimums_screen.dart';
import 'profile_screen.dart';
import 'reminders_screen.dart';

/// Settings: home airport, pilot profile, personal minimums, reminders,
/// Privacy choices (Google UMP, only where required), language, About.
/// There is no account: nothing here signs in or uploads anything.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.isPrivacyOptionsRequired = AglConsent.isPrivacyOptionsRequired,
    this.showPrivacyOptions = AglConsent.showPrivacyOptions,
  });

  /// Whether UMP requires an in-app way to change the ad-consent choice
  /// (EEA/UK/Switzerland). Injectable for tests.
  final Future<bool> Function() isPrivacyOptionsRequired;

  /// Opens Google's privacy-options form. Injectable for tests.
  final Future<void> Function() showPrivacyOptions;

  static const privacyUrl = String.fromEnvironment(
    'PRIVACY_URL',
    defaultValue: 'https://www.americangroup.ai/policy/pilotenroute/',
  );

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _privacyRequired = false;

  @override
  void initState() {
    super.initState();
    widget.isPrivacyOptionsRequired().then((r) {
      if (mounted && r) setState(() => _privacyRequired = true);
    }).catchError((_) {});
  }

  Future<void> _editHome(SettingsStore s) async {
    final ctrl = TextEditingController(text: s.homeAirport);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Home airport'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(fontFamily: AppFonts.mono),
          decoration: const InputDecoration(hintText: 'ICAO, e.g. KPAO'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Save')),
        ],
      ),
    );
    ctrl.dispose();
    if (v != null && v.trim().length >= 3) await s.setHomeAirport(v);
  }

  String _medicalLine(PilotProfile p) {
    switch (p.medicalKind) {
      case MedicalKind.none:
        return 'No medical on record';
      case MedicalKind.basicMed:
        return 'BasicMed';
      default:
        return '${p.medicalKind.label}'
            '${p.medicalExamDate == null ? '' : ', exam ${dayMonthYear(p.medicalExamDate!)}'}';
    }
  }

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: Icon(icon, color: scheme.primary),
        title: Text(title,
            style: const TextStyle(
                fontFamily: AppFonts.heading,
                fontWeight: FontWeight.w700,
                fontSize: 17)),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  void _push(Widget w) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsStore>();
    final locale = context.read<AglLocaleController?>();
    final m = s.minimums;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader('Flying'),
          _tile(
            icon: Icons.home_outlined,
            title: 'Home airport',
            subtitle: s.homeAirport.isEmpty ? 'Not set' : s.homeAirport,
            onTap: () => _editHome(s),
          ),
          _tile(
            icon: Icons.badge_outlined,
            title: 'Pilot profile',
            subtitle: '${s.profile.homeCategoryClass.isEmpty ? 'No class set' : s.profile.homeCategoryClass} · '
                '${_medicalLine(s.profile)}',
            onTap: () => _push(const ProfileScreen()),
          ),
          _tile(
            icon: Icons.tune,
            title: 'Personal minimums',
            subtitle: m.isEmpty
                ? 'Not set'
                : 'Day ${m.day.isEmpty ? 'not set' : 'set'} · Night '
                    '${m.night.isEmpty ? 'not set' : 'set'}',
            onTap: () => _push(const MinimumsScreen()),
          ),
          _tile(
            icon: Icons.notifications_outlined,
            title: 'Reminders',
            subtitle: '30 and 7 days before anything lapses',
            onTap: () => _push(const RemindersScreen()),
          ),
          const SizedBox(height: 16),
          const SectionHeader('App'),
          if (_privacyRequired)
            _tile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy choices',
              subtitle: 'Change your ad consent (Google)',
              onTap: () => widget.showPrivacyOptions(),
            ),
          if (locale != null)
            _tile(
              icon: Icons.language,
              title: AglL10n.of(context)?.miscLanguage ?? 'Language',
              onTap: () => _push(AglLanguageScreen(controller: locale)),
            ),
          _tile(
            icon: Icons.info_outline,
            title: 'About PilotEnRoute',
            onTap: () => _push(const AboutPilotEnRouteScreen()),
          ),
        ],
      ),
    );
  }
}

class AboutPilotEnRouteScreen extends StatelessWidget {
  const AboutPilotEnRouteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget p(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(t, style: const TextStyle(height: 1.35)),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('PilotEnRoute', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          p('A pilot logbook that works out your 14 CFR part 61 currency from '
              'your own entries, and checks the live METAR and TAF against '
              'your own personal minimums.'),
          const SectionHeader('Your data'),
          p('No account. Your logbook, profile, minimums and check history '
              'are stored only on this device. Nothing is uploaded.'),
          const SectionHeader('Sources'),
          p('Weather and airport data: Aviation Weather Center '
              '(aviationweather.gov, NOAA) public data API.'),
          p('Regulations: 14 CFR 61.23, 61.56, 61.57, 61.87 and 61.89 as '
              'published on ecfr.gov.'),
          p('Charts: links to the FAA d-TPP on faa.gov.'),
          const SectionHeader('Limits'),
          p('PilotEnRoute is a ground planning and record-keeping tool. It is '
              'not approved for navigation and does not replace an official '
              'weather briefing, your POH/AFM or your instructor. Every '
              'go/no-go decision is yours.'),
          p('Free, with ads from Google AdMob. Where consent is required you '
              'are asked first.'),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => launchUrl(Uri.parse(SettingsScreen.privacyUrl),
                  mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Privacy policy'),
            ),
          ),
          Text('Fonts: Sofia Sans, Sofia Sans Condensed and Fira Mono, SIL Open '
              'Font License 1.1.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
