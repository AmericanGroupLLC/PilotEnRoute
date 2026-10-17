import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/legality/date_text.dart';
import '../core/legality/legality_engine.dart';
import '../core/minimums/go_check.dart';
import '../core/minimums/go_record.dart';
import '../core/minimums/minimums_check.dart';
import '../core/minimums/solar.dart';
import '../services/error_reporter.dart';
import '../services/logbook_service.dart';
import '../services/settings_store.dart';
import '../services/weather_service.dart';
import '../ui/sky_scene.dart';
import '../ui/status_tag.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'go_history_screen.dart';
import 'logbook_entry_screen.dart';
import 'minimums_screen.dart';
import 'settings_screen.dart';

/// Today: the Go Card. One flight — departure, optional destination, time,
/// passengers / night / IFR — checked against the pilot's own logbook
/// (Legal) and the live METAR/TAF against their own minimums (Minimums).
///
/// No ad is ever shown on this screen or on the result.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key, this.clock});

  final DateTime Function()? clock;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  final _dep = TextEditingController();
  final _dest = TextEditingController();
  late DateTime _departure;
  String _categoryClass = '';
  bool _tailwheel = false;
  bool _passengers = false;
  bool _night = false;
  bool _ifr = false;

  WeatherSnapshot? _weather;
  bool _loadingWeather = false;
  String? _checkError;
  bool _autoChecked = false;
  DateTime? _checkedAt;

  /// The airports of the last check, for the result card: the fields can be
  /// edited after a check, and the card must name what was checked.
  String? _checkedDep, _checkedDest;

  DateTime _now() => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    final n = _now();
    // Default: the next quarter hour, local time.
    final q = (n.minute ~/ 15 + 1) * 15;
    _departure = DateTime(n.year, n.month, n.day, n.hour).add(Duration(minutes: q));
    final s = context.read<SettingsStore>();
    _dep.text = s.homeAirport;
    _categoryClass = s.profile.homeCategoryClass;
    _tailwheel = s.profile.homeTailwheel;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<LogbookService>().init();
      if (!mounted) return;
      if (!_autoChecked && _dep.text.trim().length >= 3) {
        _autoChecked = true;
        _check(auto: true);
      }
    });
  }

  @override
  void dispose() {
    _dep.dispose();
    _dest.dispose();
    super.dispose();
  }

  static bool _sameCheck(GoCheckRecord a, GoCheckRecord b) =>
      a.departure == b.departure &&
      a.destination == b.destination &&
      a.plannedAt.isAtSameMomentAs(b.plannedAt) &&
      a.passengers == b.passengers &&
      a.night == b.night &&
      a.ifr == b.ifr &&
      a.categoryClass == b.categoryClass &&
      a.verdict == b.verdict &&
      a.metarRaw == b.metarRaw;

  PlannedFlight get _flight => PlannedFlight(
        date: _departure,
        categoryClass: _categoryClass,
        tailwheel: _tailwheel,
        passengers: _passengers,
        night: _night,
        ifr: _ifr,
      );

  /// [auto]: the check made on opening the Go Card. It is not saved when
  /// history already holds the same plan against the same METAR with the
  /// same result, so opening the Go Card again adds nothing new. A check the
  /// pilot asks for is always saved.
  Future<void> _check({bool auto = false}) async {
    final station = _dep.text.trim().toUpperCase();
    if (station.length < 3) return;
    final weather = context.read<WeatherService>();
    final logbook = context.read<LogbookService>();
    final settings = context.read<SettingsStore>();
    setState(() {
      _loadingWeather = true;
      _checkError = null;
    });
    var fetched = false;
    try {
      final snap = await weather.fetchSnapshot(station, clock: _now);
      fetched = true;
      if (!mounted) return;
      setState(() {
        _weather = snap;
        _loadingWeather = false;
        _checkedAt = _now();
        _checkedDep = station;
        _checkedDest = _dest.text.trim().toUpperCase();
      });
      final result = _result(logbook.entries, settings);
      final record = GoCheckRecord.fromResult(
        result: result,
        departure: station,
        destination: _dest.text.trim().toUpperCase(),
        plannedAt: _departure,
        createdAt: _now(),
      );
      if (!auto || !logbook.checks.any((c) => _sameCheck(c, record))) {
        await logbook.saveCheck(record);
      }
    } catch (e, st) {
      // Shown on the card, and recorded: a failed check must never leave
      // Today on "Checking…".
      ErrorReporter.report(e, st, context: 'Go check');
      if (mounted) {
        setState(() => _checkError = fetched
            ? 'The check was not saved to history. Tap "Check again".'
            : 'The live weather could not be fetched. Tap "Check again".');
      }
    } finally {
      if (mounted && _loadingWeather) {
        setState(() => _loadingWeather = false);
      }
    }
  }

  GoResult _result(List<LogbookEntry> entries, SettingsStore s) {
    final legal = const LegalityEngine().evaluate(
      entries: entries,
      profile: s.profile,
      flight: _flight,
    );
    return evaluateGo(
      legal: legal,
      weather: _weather,
      minimums: s.minimums,
      departureLocal: _departure,
      now: _now(),
    );
  }

  Future<void> _pickDeparture() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _departure,
      firstDate: _now().subtract(const Duration(days: 365)),
      lastDate: _now().add(const Duration(days: 30)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_departure),
    );
    if (!mounted) return;
    setState(() {
      _departure = DateTime(d.year, d.month, d.day,
          t?.hour ?? _departure.hour, t?.minute ?? _departure.minute);
    });
  }

  void _logThisFlight() {
    final dep = _dep.text.trim().toUpperCase();
    final dest = _dest.text.trim().toUpperCase();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LogbookEntryScreen(
        prefill: LogbookEntry(
          date: _departure,
          aircraftType: '',
          tailNumber: '',
          from: dep,
          to: dest.isEmpty ? dep : dest,
          totalTime: 0,
          categoryClass: _categoryClass,
          tailwheel: _tailwheel,
          nightFlight: _night,
          conditions: _ifr ? 'IFR' : 'VFR',
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final logbook = context.watch<LogbookService>();
    final result = _result(logbook.entries, settings);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 78,
        titleSpacing: 20,
        title: PageTitle('Go Card',
            subtitle: 'Legal + minimums · ${dayMonthYear(_now())}'),
        actions: [
          _roundAction(
            tooltip: 'Check history',
            icon: Icons.history_rounded,
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GoHistoryScreen())),
          ),
          const SizedBox(width: 8),
          _roundAction(
            tooltip: 'Settings',
            icon: Icons.settings_outlined,
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _check,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            _verdict(context, result),
            const SizedBox(height: 16),
            _inputs(context, settings),
            const SizedBox(height: 22),
            _legal(context, result.legal, settings),
            const SizedBox(height: 22),
            _minimums(context, result, settings),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _logThisFlight,
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text('Log this flight'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loadingWeather ? null : _check,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Check again'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined,
                    size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    GoResult.disclaimer,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundAction({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: scheme.surfaceContainerLowest,
        side: BorderSide(color: scheme.outlineVariant),
        fixedSize: const Size(44, 44),
      ),
      icon: Icon(icon, size: 22),
    );
  }

  String get _timeText => '${dayMonthYear(_departure)} '
      '${_departure.hour.toString().padLeft(2, '0')}:'
      '${_departure.minute.toString().padLeft(2, '0')}';

  Widget _inputs(BuildContext context, SettingsStore settings) {
    final scheme = Theme.of(context).colorScheme;
    final classes = <String>{
      'ASEL', 'AMEL', 'ASES', 'AMES',
      if (settings.profile.homeCategoryClass.isNotEmpty)
        settings.profile.homeCategoryClass,
      if (_categoryClass.isNotEmpty) _categoryClass,
    }.toList();
    return SkyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconTile(Icons.flight_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your flight',
                        style: TextStyle(
                            fontFamily: AppFonts.heading,
                            fontWeight: FontWeight.w700,
                            fontSize: 18)),
                    Text('Where, when and what you will carry',
                        style: TextStyle(
                            fontSize: 13, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('go-departure'),
                  controller: _dep,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                      fontFamily: AppFonts.mono, fontWeight: FontWeight.w500),
                  decoration: const InputDecoration(
                    labelText: 'Departure',
                    hintText: 'ICAO',
                    prefixIcon: Icon(Icons.flight_takeoff_rounded, size: 20),
                  ),
                  onSubmitted: (_) => _check(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  key: const Key('go-destination'),
                  controller: _dest,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                      fontFamily: AppFonts.mono, fontWeight: FontWeight.w500),
                  decoration: const InputDecoration(
                    labelText: 'Destination',
                    hintText: 'Optional',
                    prefixIcon: Icon(Icons.flight_land_rounded, size: 20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDeparture,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.onSurface,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  icon: Icon(Icons.schedule_rounded,
                      size: 20, color: scheme.primary),
                  label: Text(
                    _timeText,
                    style: const TextStyle(
                        fontFamily: AppFonts.mono,
                        fontWeight: FontWeight.w500,
                        fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLowest,
                  borderRadius: const BorderRadius.all(Radius.circular(14)),
                  border: Border.all(
                      color: Theme.of(context).brightness == Brightness.light
                          ? Sky.lineStrong
                          : scheme.outlineVariant),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _categoryClass.isEmpty ? null : _categoryClass,
                    hint: const Text('Class'),
                    borderRadius: Sky.cornersM,
                    icon: const Icon(Icons.expand_more_rounded),
                    style: TextStyle(
                        fontFamily: AppFonts.heading,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: scheme.onSurface),
                    items: [
                      for (final c in classes)
                        DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (v) => setState(() => _categoryClass = v ?? ''),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                avatar: const Icon(Icons.groups_outlined, size: 18),
                label: const Text('Passengers'),
                selected: _passengers,
                onSelected: (v) => setState(() => _passengers = v),
              ),
              FilterChip(
                avatar: const Icon(Icons.nightlight_outlined, size: 18),
                label: const Text('Night'),
                selected: _night,
                onSelected: (v) => setState(() => _night = v),
              ),
              FilterChip(
                avatar: const Icon(Icons.cloud_outlined, size: 18),
                label: const Text('IFR'),
                selected: _ifr,
                onSelected: (v) => setState(() => _ifr = v),
              ),
              FilterChip(
                label: const Text('Tailwheel'),
                selected: _tailwheel,
                onSelected: (v) => setState(() => _tailwheel = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loadingWeather ? null : _check,
              child: Text(_loadingWeather ? 'Checking…' : 'Check this flight'),
            ),
          ),
          if (_checkError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: NoticeLine(
                key: const Key('go-check-error'),
                icon: Icons.report_problem_outlined,
                text: _checkError!,
              ),
            ),
          if (_checkedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Checked ${_checkedAt!.hour.toString().padLeft(2, '0')}:'
                      '${_checkedAt!.minute.toString().padLeft(2, '0')} local · '
                      'saved to history',
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _verdict(BuildContext context, GoResult result) {
    final scheme = Theme.of(context).colorScheme;
    final weatherPending = _loadingWeather;
    final look = weatherPending && result.verdict != GoVerdict.notLegal
        ? const StatusLook('CHECKING', Icons.hourglass_top, Tone.neutral)
        : lookForVerdict(result.verdict);
    final headline = weatherPending && result.verdict != GoVerdict.notLegal
        ? 'Legal for this flight. Fetching the latest METAR and TAF…'
        : result.headline;
    final mood = _night
        ? SkyMood.night
        : result.verdict == GoVerdict.outside
            ? SkyMood.overcast
            : SkyMood.day;
    final dep = _checkedDep ?? _dep.text.trim().toUpperCase();
    final dest = _checkedDest ?? _dest.text.trim().toUpperCase();
    final route = dep.isEmpty
        ? 'No departure yet'
        : dest.isEmpty || dest == dep
            ? dep
            : '$dep → $dest';
    return SkyCard(
      key: const Key('go-verdict'),
      padding: EdgeInsets.zero,
      radius: Sky.cornersL,
      borderColor:
          look.tone == Tone.neutral ? null : toneColor(context, look.tone),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              SkyScene(mood: mood, height: 150),
              Positioned(
                left: 14,
                top: 14,
                right: 14,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: ShapeDecoration(
                    color: scheme.surfaceContainerLowest.withValues(alpha: 0.92),
                    shape: const StadiumBorder(),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.near_me_rounded,
                          size: 15, color: scheme.primary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(route,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontFamily: AppFonts.mono,
                                fontWeight: FontWeight.w500,
                                fontSize: 12.5,
                                color: scheme.onSurface)),
                      ),
                    ],
                  ),
                ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusTag(look),
                const SizedBox(height: 10),
                Text(
                  headline,
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontWeight: FontWeight.w800,
                    fontSize: 21,
                    height: 1.2,
                    letterSpacing: -0.2,
                    color: scheme.onSurface,
                  ),
                ),
                if (result.secondLine != null) ...[
                  const SizedBox(height: 4),
                  Text(result.secondLine!,
                      style: TextStyle(
                          fontSize: 15,
                          height: 1.3,
                          color: scheme.onSurfaceVariant)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The 61.57(b) night window at the departure airport, worked out on the
  /// device from the airport position in the last check. Null until a check
  /// has returned a position.
  String? _nightLine() {
    final w = _weather;
    final lat = w?.airport?.lat ?? w?.metar?.lat;
    final lon = w?.airport?.lon ?? w?.metar?.lon;
    if (w == null || lat == null || lon == null) return null;
    String two(int v) => v.toString().padLeft(2, '0');
    return nightWindowLine(
      station: w.station,
      window:
          nightWindowForDeparture(departure: _departure, lat: lat, lon: lon),
      local: (u) {
        final l = u.toLocal();
        return '${two(l.hour)}:${two(l.minute)}';
      },
    );
  }

  Widget _legal(BuildContext context, LegalityReport report, SettingsStore s) {
    final scheme = Theme.of(context).colorScheme;
    final needed = report.rules.where((r) => r.required).toList();
    final met = needed
        .where((r) =>
            r.state == RuleState.valid || r.state == RuleState.exempt)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader('Legal',
            subtitle: 'From your logbook and profile · '
                '${_categoryClass.isEmpty ? 'no class chosen' : _categoryClass}'
                '${_tailwheel ? ' tailwheel' : ''}'),
        SkyCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (needed.isNotEmpty) ...[
                ProgressStrip(
                  label: 'Requirements met for this flight',
                  trailing: '$met of ${needed.length}',
                  value: met / needed.length,
                ),
                const SizedBox(height: 8),
              ],
              if (!report.hasEntries)
                const NoticeLine(
                  icon: Icons.menu_book_outlined,
                  text: "No flights logged yet. Log your recent flights and "
                      "this shows what you're current for.",
                ),
              for (var i = 0; i < report.rules.length; i++)
                _ruleRow(context, report.rules[i],
                    last: i == report.rules.length - 1),
            ],
          ),
        ),
        if (_night && _nightLine() != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: NoticeLine(
              key: const Key('go-night-window'),
              icon: Icons.nightlight_outlined,
              text: _nightLine()!,
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(
            'Not checked here: type ratings, endorsements other than student '
            'solo, and the 61.57(e) exceptions.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  static IconData _ruleIcon(RuleId id) {
    switch (id) {
      case RuleId.dayPassengers:
        return Icons.groups_outlined;
      case RuleId.nightPassengers:
        return Icons.nightlight_outlined;
      case RuleId.ifr:
        return Icons.cloud_outlined;
      case RuleId.flightReview:
        return Icons.verified_outlined;
      case RuleId.medical:
        return Icons.medical_services_outlined;
      case RuleId.studentSolo:
      case RuleId.studentPassengers:
        return Icons.school_outlined;
    }
  }

  Widget _ruleRow(BuildContext context, RuleStatus r, {bool last = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(_ruleIcon(r.id), size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(TextSpan(children: [
                  TextSpan(
                    text: r.title,
                    style: TextStyle(
                        fontFamily: AppFonts.heading,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: scheme.onSurface),
                  ),
                  TextSpan(
                    text: '  ${r.cite}',
                    style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontSize: 10.5,
                        color: scheme.onSurfaceVariant),
                  ),
                ])),
                const SizedBox(height: 3),
                Text(r.summary,
                    style: TextStyle(fontSize: 14, color: scheme.onSurface)),
                if (!r.required)
                  Text('Not needed for this flight',
                      style: TextStyle(
                          fontSize: 12.5, color: scheme.onSurfaceVariant)),
                if (r.shortfall != null && r.required)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(r.shortfall!,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                for (final n in r.notes)
                  Text(n,
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusTag(lookForRule(r), dense: true),
        ],
      ),
    );
  }

  Widget _minimums(BuildContext context, GoResult result, SettingsStore s) {
    final scheme = Theme.of(context).colorScheme;
    final set = s.minimums.forFlight(night: _night);
    final w = _weather;
    final children = <Widget>[];
    if (set.isEmpty) {
      children.add(NoticeLine(
        icon: Icons.tune,
        text: 'Your ${_night ? 'night' : 'day'} minimums are not set. The app '
            'never suggests numbers: they are yours to choose.',
        action: OutlinedButton(
          onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MinimumsScreen())),
          child: const Text('Set my minimums'),
        ),
      ));
    }
    if (_loadingWeather) {
      children.add(const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ));
    } else if (w == null) {
      children.add(const NoticeLine(
        icon: Icons.cloud_queue,
        text: 'Enter a departure airport and tap "Check this flight".',
      ));
    } else if (w.metar == null) {
      children.add(NoticeLine(
        icon: w.metarStatus == FetchStatus.offline
            ? Icons.cloud_off
            : Icons.report_problem_outlined,
        text: w.metarProblem ?? 'No METAR.',
      ));
    } else {
      final m = w.metar!;
      final age = m.ageMinutes(_now());
      children.addAll([
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const IconTile(Icons.cell_tower_rounded, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${m.icao}${m.name.isEmpty ? '' : ' · ${m.name}'}\n'
                'Observed ${m.observedUtc == null ? 'time unknown' : zuluTime(m.observedUtc!)}'
                '${age == null ? '' : ' · $age min ago'}',
                style: TextStyle(
                    fontSize: 13, height: 1.35, color: scheme.onSurfaceVariant),
              ),
            ),
            if (result.metarStale)
              const StatusTag(
                  StatusLook('STALE', Icons.timer_off_outlined, Tone.caution),
                  dense: true),
          ],
        ),
        const SizedBox(height: 10),
        MonoBlock(m.raw),
        const SizedBox(height: 4),
        if (result.metarCheck != null)
          for (final l in result.metarCheck!.lines) _lineRow(context, l),
        if (w.airportStatus != FetchStatus.ok)
          const NoticeLine(
            icon: Icons.info_outline,
            text: 'Runway data was not available, so crosswind could not be '
                'worked out.',
          ),
      ]);
    }

    if (w != null) {
      children.add(const SizedBox(height: 14));
      children.add(Row(children: [
        Icon(Icons.schedule_rounded, size: 18, color: scheme.secondary),
        const SizedBox(width: 6),
        const Flexible(
          child: Text('TAF, departure ±1 h',
              style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontWeight: FontWeight.w700,
                  fontSize: 15)),
        ),
      ]));
      if (result.tafNote != null) {
        children.add(NoticeLine(icon: Icons.info_outline, text: result.tafNote!));
      }
      for (final t in result.tafChecks) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 2),
          child: Text(t.source,
              style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 12,
                  color: scheme.onSurfaceVariant)),
        ));
        for (final l in t.lines) {
          children.add(_lineRow(context, l, compact: true));
        }
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          'Minimums',
          subtitle: 'Your ${_night ? 'night' : 'day'} limits vs. live '
              'aviationweather.gov data',
        ),
        SkyCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children),
        ),
      ],
    );
  }

  static IconData _lineIcon(String label) {
    final l = label.toLowerCase();
    if (l.contains('ceil')) return Icons.cloud_outlined;
    if (l.contains('vis')) return Icons.visibility_outlined;
    if (l.contains('cross')) return Icons.swap_horiz_rounded;
    if (l.contains('gust')) return Icons.storm_outlined;
    if (l.contains('wind')) return Icons.air_rounded;
    return Icons.tune_rounded;
  }

  Widget _lineRow(BuildContext context, MinimumLine l, {bool compact = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(vertical: compact ? 6 : 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(_lineIcon(l.label),
                size: compact ? 16 : 20, color: scheme.secondary),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 76,
            child: Text(l.label,
                style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 13.5 : 15)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.observed,
                    style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontWeight: FontWeight.w500,
                        fontSize: compact ? 12 : 13)),
                Text('Your limit ${l.limit}',
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                if (l.detail != null)
                  Text(l.detail!,
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          StatusTag(lookForCheck(l.state), dense: true),
        ],
      ),
    );
  }
}
