import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/legality/date_text.dart';
import '../services/settings_store.dart';
import '../services/weather_service.dart';
import '../ui/status_tag.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../widgets/ad_banner_widget.dart';
import 'airport_screen.dart';

/// Weather: METAR and TAF for any station, plus PIREPs, SIGMETs, G-AIRMETs
/// and winds aloft. All straight from aviationweather.gov.
class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 5, vsync: this);
  final _station = TextEditingController();
  bool _loading = false;
  WeatherSnapshot? _snap;
  List<Map<String, dynamic>> _pireps = [];
  List<Map<String, dynamic>> _sigmets = [];
  List<Map<String, dynamic>> _airmets = [];
  List<Map<String, dynamic>> _winds = [];
  bool _advisoriesLoaded = false;

  @override
  void initState() {
    super.initState();
    _station.text = context.read<SettingsStore>().homeAirport;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _station.text.trim().length >= 3) _fetch();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _station.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final id = _station.text.trim().toUpperCase();
    if (id.length < 3) return;
    final svc = context.read<WeatherService>();
    setState(() => _loading = true);
    final snap = await svc.fetchSnapshot(id);
    if (!mounted) return;
    setState(() {
      _snap = snap;
      _loading = false;
    });
    if (!_advisoriesLoaded) _loadAdvisories(id);
  }

  Future<void> _loadAdvisories(String id) async {
    final svc = context.read<WeatherService>();
    final results = await Future.wait([
      svc.fetchPireps(icao: id),
      svc.fetchSigmets(),
      svc.fetchAirmets(),
      svc.fetchWindsAloft(),
    ]);
    if (!mounted) return;
    setState(() {
      _pireps = results[0];
      _sigmets = results[1];
      _airmets = results[2];
      _winds = results[3];
      _advisoriesLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weather'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'METAR / TAF'),
            Tab(text: 'PIREPs'),
            Tab(text: 'SIGMETs'),
            Tab(text: 'G-AIRMETs'),
            Tab(text: 'Winds aloft'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('weather-station'),
                    controller: _station,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(fontFamily: AppFonts.mono),
                    decoration: const InputDecoration(
                      labelText: 'Station (ICAO)',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    onSubmitted: (_) => _fetch(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _fetch,
                  child: const Text('Get'),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _metarTaf(context),
                _rawList(_pireps, 'rawOb', 'No PIREPs near this station in the '
                    'last 2 hours.'),
                _rawList(_sigmets, 'rawSigmet', 'No international SIGMETs '
                    'right now.'),
                _airmetList(),
                _rawList(_winds, 'raw', 'Winds aloft not available.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metarTaf(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) return const Center(child: CircularProgressIndicator());
    final s = _snap;
    if (s == null) {
      return ListView(padding: const EdgeInsets.all(16), children: const [
        NoticeLine(
            icon: Icons.cloud_queue,
            text: 'Enter a station, e.g. KPAO, and tap Get.'),
      ]);
    }
    final m = s.metar;
    final children = <Widget>[];
    if (m == null) {
      children.add(NoticeLine(
        icon: s.metarStatus == FetchStatus.offline
            ? Icons.cloud_off
            : Icons.report_problem_outlined,
        text: s.metarProblem ?? 'No METAR.',
      ));
    } else {
      final cat = m.flightCategory.isEmpty ? '—' : m.flightCategory;
      final age = m.ageMinutes(DateTime.now());
      children.addAll([
        Row(
          children: [
            Expanded(
              child: Text(
                '${m.icao}${m.name.isEmpty ? '' : '  ${m.name}'}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            _CategoryTag(cat),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Observed ${m.observedUtc == null ? 'time unknown' : zuluTime(m.observedUtc!)}'
          '${age == null ? '' : ' · $age min ago'}'
          '${m.isStale(DateTime.now()) ? ' · STALE (over 90 min)' : ''}',
          style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        MonoBlock(m.raw),
        const SizedBox(height: 10),
        _kv('Wind (true)', m.wind?.text ?? 'Not reported'),
        _kv('Visibility', m.visibility?.text ?? 'Not reported'),
        _kv('Ceiling',
            m.ceilingFt == null ? 'None reported' : '${m.ceilingFt} ft AGL'),
        _kv('Clouds', m.clouds.isEmpty
            ? 'None reported'
            : m.clouds.map((c) => '${c.cover} ${c.baseFt ?? ''}').join('  ')),
        if (m.tempC != null)
          _kv('Temp / dew point',
              '${m.tempC!.toStringAsFixed(0)} / ${m.dewpointC?.toStringAsFixed(0) ?? '—'} °C'),
        if (m.altimeterInHg != null)
          _kv('Altimeter', '${m.altimeterInHg!.toStringAsFixed(2)} inHg'),
      ]);
    }
    children.add(const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: AdBannerWidget(),
    ));
    children.add(const SectionHeader('TAF'));
    final t = s.taf;
    if (t == null) {
      children.add(NoticeLine(
        icon: Icons.info_outline,
        text: switch (s.tafStatus) {
          FetchStatus.noData => 'No TAF is issued for ${s.station}.',
          FetchStatus.offline => 'TAF not fetched: offline.',
          _ => 'TAF not available from aviationweather.gov right now.',
        },
      ));
    } else {
      children.add(MonoBlock(t.raw));
      for (final g in t.groups) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '${g.label.padRight(8)} ${zuluTime(g.fromUtc)}–${zuluTime(g.toUtc)}  '
            '${g.wind?.text ?? ''}  ${g.visibility?.text ?? ''}  '
            '${g.ceilingFt == null ? '' : 'CIG ${g.ceilingFt}'}',
            style: const TextStyle(fontFamily: AppFonts.mono, fontSize: 12),
          ),
        ));
      }
    }
    children.add(const SizedBox(height: 12));
    children.add(OutlinedButton.icon(
      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AirportScreen(initialIcao: s.station))),
      icon: const Icon(Icons.local_airport),
      label: Text('${s.station} airport details'),
    ));
    children.add(const SizedBox(height: 8));
    children.add(Text(
      'Source: aviationweather.gov (NOAA). Check an official briefing '
      '(1800wxbrief.com) before flight.',
      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
    ));
    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(padding: const EdgeInsets.all(16), children: children),
    );
  }

  Widget _kv(String k, String v) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: scheme.outlineVariant))),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(k,
                style: const TextStyle(
                    fontFamily: AppFonts.heading, fontWeight: FontWeight.w700)),
          ),
          Expanded(
              child: Text(v,
                  style: const TextStyle(fontFamily: AppFonts.mono, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _rawList(List<Map<String, dynamic>> items, String key, String empty) {
    if (!_advisoriesLoaded) {
      return _snap == null
          ? ListView(padding: const EdgeInsets.all(16), children: const [
              NoticeLine(icon: Icons.cloud_queue, text: 'Get a station first.')
            ])
          : const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        NoticeLine(icon: Icons.info_outline, text: empty),
      ]);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final m = items[i];
        final text = (m[key] ?? m['raw'] ?? m['rawOb'] ?? m.toString()).toString();
        return MonoBlock(text);
      },
    );
  }

  Widget _airmetList() {
    if (!_advisoriesLoaded) return _rawList(const [], '', '');
    if (_airmets.isEmpty) {
      return ListView(padding: const EdgeInsets.all(16), children: const [
        NoticeLine(icon: Icons.info_outline, text: 'No G-AIRMETs right now.'),
      ]);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _airmets.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (_, i) {
        final a = _airmets[i];
        final hazard = (a['hazard'] ?? a['airmetType'] ?? 'AIRMET').toString();
        final to = a['validTimeTo'];
        final valid = to is num
            ? 'valid to ${zuluTime(DateTime.fromMillisecondsSinceEpoch(to.toInt() * 1000, isUtc: true))}'
            : '';
        final region = a['region'] == null ? '' : 'region ${a['region']}';
        final levels = [
          if (a['base'] != null) 'base ${a['base']}',
          if (a['top'] != null) 'top ${a['top']}',
        ].join(', ');
        final due = [region, valid, levels].where((s) => s.isNotEmpty).join(' · ');
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.warning_amber_outlined),
          title: Text(hazard),
          subtitle: Text(due, style: const TextStyle(fontFamily: AppFonts.mono, fontSize: 12)),
        );
      },
    );
  }
}

class _CategoryTag extends StatelessWidget {
  const _CategoryTag(this.category);
  final String category;

  @override
  Widget build(BuildContext context) {
    final icon = switch (category) {
      'VFR' => Icons.wb_sunny_outlined,
      'MVFR' => Icons.cloud_outlined,
      'IFR' => Icons.cloud,
      'LIFR' => Icons.foggy,
      _ => Icons.help_outline,
    };
    final color = flightCategoryColor(category);
    return Semantics(
      label: 'Flight category $category',
      excludeSemantics: true,
      child: CustomPaint(
        painter: TagPainter(color: color, filled: true),
        child: Container(
          height: 28,
          padding: const EdgeInsets.only(left: 22, right: 9),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 4),
            Text(category,
                style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ]),
        ),
      ),
    );
  }
}
