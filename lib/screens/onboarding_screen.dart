import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/legality/pilot_profile.dart';
import '../core/minimums/personal_minimums.dart';
import '../services/settings_store.dart';
import '../services/weather_service.dart';
import '../ui/status_tag.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'minimums_screen.dart';
import 'profile_screen.dart';

/// Three screens, no account: (1) home airport and what you fly, (2) medical
/// and flight review, (3) your personal minimums. Screens 2 and 3 can be
/// skipped. Nothing here depends on date, region or who is using the app.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  final _airport = TextEditingController();
  final _minimums = GlobalKey<MinimumsFormState>();
  int _page = 0;
  PilotProfile _profile = PilotProfile.empty;
  AirportReference? _found;
  String? _lookupNote;
  bool _looking = false;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsStore>();
    _airport.text = s.homeAirport;
    _profile = s.profile;
  }

  @override
  void dispose() {
    _pages.dispose();
    _airport.dispose();
    super.dispose();
  }

  bool get _page1Ready =>
      _airport.text.trim().length >= 3 && _profile.homeCategoryClass.isNotEmpty;

  Future<void> _lookup() async {
    final id = _airport.text.trim().toUpperCase();
    if (id.length < 3) return;
    setState(() {
      _looking = true;
      _lookupNote = null;
      _found = null;
    });
    try {
      final a = await context.read<WeatherService>().fetchAirportDetail(id);
      if (!mounted) return;
      setState(() {
        _found = a;
        _lookupNote = a == null
            ? 'aviationweather.gov does not know $id. Use the ICAO identifier '
                '(KPAO, not PAO).'
            : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _lookupNote =
          'Could not reach aviationweather.gov to check $id. You can carry on; '
          'it will be checked when you are online.');
    } finally {
      if (mounted) setState(() => _looking = false);
    }
  }

  void _go(int page) {
    FocusScope.of(context).unfocus();
    setState(() => _page = page);
    _pages.animateToPage(page,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Future<void> _finish({required bool saveMinimums}) async {
    final s = context.read<SettingsStore>();
    PersonalMinimums? m;
    if (saveMinimums) {
      m = _minimums.currentState?.read();
      if (m == null && _minimums.currentState != null) return; // invalid field
    }
    await s.setHomeAirport(_airport.text);
    await s.setProfile(_profile);
    if (m != null) await s.setMinimums(m);
    await s.completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: StatusTag(
                            StatusLook('PILOTENROUTE', Icons.check, Tone.stop)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${_page + 1} of 3',
                      style: const TextStyle(fontFamily: AppFonts.mono)),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                children: [_one(context), _two(context), _three(context)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _frame({
    required String title,
    required String lead,
    required List<Widget> body,
    required List<Widget> actions,
  }) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text(lead),
              const SizedBox(height: 18),
              ...body,
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: OverflowBar(
            alignment: MainAxisAlignment.end,
            overflowAlignment: OverflowBarAlignment.end,
            spacing: 8,
            overflowSpacing: 4,
            children: actions,
          ),
        ),
      ],
    );
  }

  Widget _one(BuildContext context) {
    return _frame(
      title: 'Am I legal, and inside my minimums?',
      lead: 'PilotEnRoute works that out for each flight from your own logbook '
          'and the live METAR/TAF. No account; everything stays on this '
          'phone. Start with your home airport and what you fly.',
      body: [
        Row(children: [
          Expanded(
            child: TextField(
              key: const Key('onboarding-airport'),
              controller: _airport,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontFamily: AppFonts.mono),
              decoration: const InputDecoration(
                labelText: 'Home airport (ICAO)',
                hintText: 'e.g. KPAO',
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _lookup(),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: _looking ? null : _lookup,
            child: Text(_looking ? 'Checking…' : 'Check'),
          ),
        ]),
        if (_found != null)
          NoticeLine(
            icon: Icons.check_circle_outline,
            text: '${_found!.icao} · ${_found!.name}'
                '${_found!.runwayInfo.isEmpty ? '' : ' · ${_found!.runwayInfo.length} runway(s)'}',
          ),
        if (_lookupNote != null)
          NoticeLine(icon: Icons.info_outline, text: _lookupNote!),
        const SizedBox(height: 14),
        AircraftClassPicker(
          value: _profile.homeCategoryClass,
          tailwheel: _profile.homeTailwheel,
          onChanged: (cc, tw) => setState(() => _profile =
              _profile.copyWith(homeCategoryClass: cc, homeTailwheel: tw)),
        ),
      ],
      actions: [
        FilledButton(
          key: const Key('onboarding-next-1'),
          onPressed: _page1Ready ? () => _go(1) : null,
          child: const Text('Continue'),
        ),
      ],
    );
  }

  Widget _two(BuildContext context) {
    return _frame(
      title: 'Medical and flight review',
      lead: 'The dates on your medical and your last flight review. The app '
          'works out when each one lapses under 14 CFR 61.23 and 61.56.',
      body: [
        MedicalForm(
          profile: _profile,
          onChanged: (p) => setState(() => _profile = p),
        ),
      ],
      actions: [
        TextButton(onPressed: () => _go(0), child: const Text('Back')),
        TextButton(
          key: const Key('onboarding-skip-2'),
          onPressed: () => _go(2),
          child: const Text('Skip'),
        ),
        FilledButton(
          key: const Key('onboarding-next-2'),
          onPressed: () => _go(2),
          child: const Text('Continue'),
        ),
      ],
    );
  }

  Widget _three(BuildContext context) {
    return _frame(
      title: 'Your personal minimums',
      lead: 'The limits you set for yourself. The Go Card compares the live '
          'weather with them. You can change them any time in Settings.',
      body: [MinimumsForm(key: _minimums)],
      actions: [
        TextButton(onPressed: () => _go(1), child: const Text('Back')),
        TextButton(
          key: const Key('onboarding-skip-3'),
          onPressed: () => _finish(saveMinimums: false),
          child: const Text('Skip'),
        ),
        FilledButton(
          key: const Key('onboarding-finish'),
          onPressed: () => _finish(saveMinimums: true),
          child: const Text('Finish'),
        ),
      ],
    );
  }
}
