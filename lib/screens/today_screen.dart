import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/legality/date_text.dart';
import '../core/legality/legality_engine.dart';
import '../core/minimums/go_check.dart';
import '../core/minimums/go_record.dart';
import '../core/minimums/minimums_check.dart';
import '../services/logbook_service.dart';
import '../services/settings_store.dart';
import '../services/weather_service.dart';
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
  bool _autoChecked = false;
  DateTime? _checkedAt;

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
        _check();
      }
    });
  }

  @override
  void dispose() {
    _dep.dispose();
    _dest.dispose();
    super.dispose();
  }

  PlannedFlight get _flight => PlannedFlight(
        date: _departure,
        categoryClass: _categoryClass,
        tailwheel: _tailwheel,
        passengers: _passengers,
        night: _night,
        ifr: _ifr,
      );

  Future<void> _check() async {
    final station = _dep.text.trim().toUpperCase();
    if (station.length < 3) return;
    final weather = context.read<WeatherService>();
    final logbook = context.read<LogbookService>();
    final settings = context.read<SettingsStore>();
    setState(() => _loadingWeather = true);
    final snap = await weather.fetchSnapshot(station, clock: _now);
    if (!mounted) return;
    setState(() {
      _weather = snap;
      _loadingWeather = false;
      _checkedAt = _now();
    });
    final result = _result(logbook.entries, settings);
    await logbook.saveCheck(GoCheckRecord.fromResult(
      result: result,
      departure: station,
      destination: _dest.text.trim().toUpperCase(),
      plannedAt: _departure,
      createdAt: _now(),
    ));
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: [
          IconButton(
            tooltip: 'Check history',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GoHistoryScreen())),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _check,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            _inputs(context, settings),
            const SizedBox(height: 14),
            _verdict(context, result),
            const SizedBox(height: 16),
            _legal(context, result.legal, settings),
            const SizedBox(height: 16),
            _minimums(context, result, settings),
            const SizedBox(height: 14),
            Text(
              GoResult.disclaimer,
              style: TextStyle(
                fontSize: 12.5,
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _logThisFlight,
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Log this flight'),
                ),
                OutlinedButton.icon(
                  onPressed: _loadingWeather ? null : _check,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Check again'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputs(BuildContext context, SettingsStore settings) {
    final scheme = Theme.of(context).colorScheme;
    final classes = <String>{
      'ASEL', 'AMEL', 'ASES', 'AMES',
      if (settings.profile.homeCategoryClass.isNotEmpty)
        settings.profile.homeCategoryClass,
      if (_categoryClass.isNotEmpty) _categoryClass,
    }.toList();
    return PlacardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('go-departure'),
                  controller: _dep,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(fontFamily: AppFonts.mono),
                  decoration: const InputDecoration(
                    labelText: 'Departure',
                    hintText: 'ICAO',
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
                  style: const TextStyle(fontFamily: AppFonts.mono),
                  decoration: const InputDecoration(
                    labelText: 'Destination',
                    hintText: 'Optional',
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
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text(
                    '${dayMonthYear(_departure)} '
                    '${_departure.hour.toString().padLeft(2, '0')}:'
                    '${_departure.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontFamily: AppFonts.mono),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              DropdownButton<String>(
                value: _categoryClass.isEmpty ? null : _categoryClass,
                hint: const Text('Class'),
                items: [
                  for (final c in classes)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(() => _categoryClass = v ?? ''),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
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
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loadingWeather ? null : _check,
              child: Text(_loadingWeather ? 'Checking…' : 'Check this flight'),
            ),
          ),
          if (_checkedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Checked ${_checkedAt!.hour.toString().padLeft(2, '0')}:'
                '${_checkedAt!.minute.toString().padLeft(2, '0')} local · '
                'saved to history',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
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
    return Container(
      key: const Key('go-verdict'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: Rbf.corners,
        border: Border.all(color: toneColor(context, look.tone), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusTag(look),
          const SizedBox(height: 8),
          Text(
            headline,
            style: const TextStyle(
              fontFamily: AppFonts.heading,
              fontWeight: FontWeight.w700,
              fontSize: 21,
              height: 1.15,
            ),
          ),
          if (result.secondLine != null) ...[
            const SizedBox(height: 4),
            Text(result.secondLine!,
                style: const TextStyle(
                    fontFamily: AppFonts.heading, fontSize: 17)),
          ],
        ],
      ),
    );
  }

  Widget _legal(BuildContext context, LegalityReport report, SettingsStore s) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader('Legal',
            subtitle: 'From your logbook and profile · '
                '${_categoryClass.isEmpty ? 'no class chosen' : _categoryClass}'
                '${_tailwheel ? ' tailwheel' : ''}'),
        if (!report.hasEntries)
          const NoticeLine(
            icon: Icons.menu_book_outlined,
            text: "No flights logged yet. Log your recent flights and this "
                "shows what you're current for.",
          ),
        for (final r in report.rules) _ruleRow(context, r),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'Not checked here: type ratings, endorsements other than student '
            'solo, and the 61.57(e) exceptions.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _ruleRow(BuildContext context, RuleStatus r) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(TextSpan(children: [
                  TextSpan(
                    text: r.title,
                    style: const TextStyle(
                        fontFamily: AppFonts.heading,
                        fontWeight: FontWeight.w700,
                        fontSize: 16.5),
                  ),
                  TextSpan(
                    text: '  ${r.cite}',
                    style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontSize: 11,
                        color: scheme.onSurfaceVariant),
                  ),
                ])),
                const SizedBox(height: 2),
                Text(r.summary),
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
    final children = <Widget>[
      SectionHeader(
        'Minimums',
        subtitle: 'Your ${_night ? 'night' : 'day'} limits vs. live '
            'aviationweather.gov data',
      ),
    ];
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
        padding: EdgeInsets.all(12),
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
        MonoBlock(m.raw),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                '${m.icao}${m.name.isEmpty ? '' : ' · ${m.name}'}\n'
                'Observed ${m.observedUtc == null ? 'time unknown' : zuluTime(m.observedUtc!)}'
                '${age == null ? '' : ' · $age min ago'}',
                style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
              ),
            ),
            if (result.metarStale)
              const StatusTag(
                  StatusLook('STALE', Icons.timer_off_outlined, Tone.caution),
                  dense: true),
          ],
        ),
        const SizedBox(height: 6),
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
      children.add(const SizedBox(height: 12));
      children.add(const Text('TAF, departure ±1 h',
          style: TextStyle(
              fontFamily: AppFonts.heading,
              fontWeight: FontWeight.w700,
              fontSize: 15)));
      if (result.tafNote != null) {
        children.add(NoticeLine(icon: Icons.info_outline, text: result.tafNote!));
      }
      for (final t in result.tafChecks) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(t.source,
              style: const TextStyle(fontFamily: AppFonts.mono, fontSize: 12.5)),
        ));
        for (final l in t.lines) {
          children.add(_lineRow(context, l, compact: true));
        }
      }
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget _lineRow(BuildContext context, MinimumLine l, {bool compact = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(vertical: compact ? 5 : 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(l.label,
                style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.observed,
                    style: const TextStyle(fontFamily: AppFonts.mono, fontSize: 13)),
                Text('Your limit ${l.limit}',
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                if (l.detail != null)
                  Text(l.detail!,
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          StatusTag(lookForCheck(l.state), dense: true),
        ],
      ),
    );
  }
}
