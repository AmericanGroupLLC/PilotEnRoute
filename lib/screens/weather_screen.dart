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
        toolbarHeight: 78,
        titleSpacing: 20,
        title: const PageTitle('Weather',
            subtitle: 'Live from aviationweather.gov'),
        bottom: SegmentedTabBar(
          controller: _tabs,
          isScrollable: true,
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
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('weather-station'),
                    controller: _station,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(
                        fontFamily: AppFonts.mono, fontWeight: FontWeight.w500),
                    decoration: const InputDecoration(
                      labelText: 'Station (ICAO)',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    onSubmitted: (_) => _fetch(),
                  ),
                ),
                const SizedBox(width: 10),
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
      final stale = m.isStale(DateTime.now());
      children.add(SkyCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const IconTile(Icons.cell_tower_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.icao,
                          style: const TextStyle(
                              fontFamily: AppFonts.heading,
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                              letterSpacing: 0.4)),
                      if (m.name.isNotEmpty)
                        Text(m.name,
                            style: TextStyle(
                                fontSize: 13.5,
                                color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                _CategoryTag(cat),
              ],
            ),
            const SizedBox(height: 10),
            Row(children: [
              Icon(stale ? Icons.timer_off_outlined : Icons.schedule_rounded,
                  size: 15,
                  color: stale
                      ? toneColor(context, Tone.caution)
                      : scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Observed ${m.observedUtc == null ? 'time unknown' : zuluTime(m.observedUtc!)}'
                  '${age == null ? '' : ' · $age min ago'}'
                  '${stale ? ' · STALE (over 90 min)' : ''}',
                  style: TextStyle(
                      fontSize: 12.5, color: scheme.onSurfaceVariant),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            MonoBlock(m.raw),
            const SizedBox(height: 12),
            _grid([
              _stat(Icons.air_rounded, 'Wind (true)',
                  m.wind?.text ?? 'Not reported'),
              _stat(Icons.visibility_outlined, 'Visibility',
                  m.visibility?.text ?? 'Not reported'),
              _stat(Icons.cloud_outlined, 'Ceiling',
                  m.ceilingFt == null ? 'None reported' : '${m.ceilingFt} ft AGL'),
              if (m.tempC != null)
                _stat(Icons.thermostat_rounded, 'Temp / dew point',
                    '${m.tempC!.toStringAsFixed(0)} / ${m.dewpointC?.toStringAsFixed(0) ?? '—'} °C'),
              if (m.altimeterInHg != null)
                _stat(Icons.speed_rounded, 'Altimeter',
                    '${m.altimeterInHg!.toStringAsFixed(2)} inHg'),
            ]),
            const SizedBox(height: 10),
            _kv('Clouds', m.clouds.isEmpty
                ? 'None reported'
                : m.clouds.map((c) => '${c.cover} ${c.baseFt ?? ''}').join('  ')),
          ],
        ),
      ));
    }
    children.add(const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: AdBannerWidget(),
    ));
    children.add(const SectionHeader('TAF'));
    final t = s.taf;
    if (t == null) {
      children.add(SkyCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: NoticeLine(
          icon: Icons.info_outline,
          text: switch (s.tafStatus) {
            FetchStatus.noData => 'No TAF is issued for ${s.station}.',
            FetchStatus.offline => 'TAF not fetched: offline.',
            _ => 'TAF not available from aviationweather.gov right now.',
          },
        ),
      ));
    } else {
      children.add(SkyCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MonoBlock(t.raw),
            for (final g in t.groups)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(color: scheme.outlineVariant))),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: ShapeDecoration(
                          color: scheme.primaryContainer,
                          shape: const StadiumBorder()),
                      child: Text(g.label,
                          style: TextStyle(
                              fontFamily: AppFonts.heading,
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5,
                              color: scheme.onPrimaryContainer)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${zuluTime(g.fromUtc)}–${zuluTime(g.toUtc)}  '
                        '${g.wind?.text ?? ''}  ${g.visibility?.text ?? ''}  '
                        '${g.ceilingFt == null ? '' : 'CIG ${g.ceilingFt}'}',
                        style: const TextStyle(
                            fontFamily: AppFonts.mono, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ));
    }
    children.add(const SizedBox(height: 12));
    children.add(OutlinedButton.icon(
      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AirportScreen(initialIcao: s.station))),
      icon: const Icon(Icons.local_airport_rounded),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.filter_drama_outlined, size: 16, color: scheme.secondary),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: Text(k,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant)),
        ),
        Expanded(
            child: Text(v,
                style: const TextStyle(fontFamily: AppFonts.mono, fontSize: 13))),
      ],
    );
  }

  Widget _stat(IconData icon, String label, String value) =>
      _WxStat(icon: icon, label: label, value: value);

  /// Two-up grid of read-outs that wraps to one column on narrow widths.
  Widget _grid(List<Widget> tiles) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth < 300 ? 1 : 2;
      final w = (c.maxWidth - 10 * (cols - 1)) / cols;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [for (final t in tiles) SizedBox(width: w, child: t)],
      );
    });
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
        return SkyCard(padding: const EdgeInsets.all(10), child: MonoBlock(text));
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
      separatorBuilder: (_, __) => const SizedBox(height: 8),
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
        return NavRowCard(
          icon: Icons.warning_amber_rounded,
          title: hazard,
          subtitle: due,
          trailing: const SizedBox.shrink(),
        );
      },
    );
  }
}

class _WxStat extends StatelessWidget {
  const _WxStat({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: Sky.cornersM,
      ),
      child: Row(
        children: [
          IconTile(icon, size: 34, background: scheme.surfaceContainerLowest),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: scheme.onSurface)),
              ],
            ),
          ),
        ],
      ),
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
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: ShapeDecoration(color: color, shape: const StadiumBorder()),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 5),
          Text(category,
              style: const TextStyle(
                  fontFamily: AppFonts.heading,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: Colors.white)),
        ]),
      ),
    );
  }
}
