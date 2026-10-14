import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/legality/date_text.dart';
import '../services/chart_service.dart';
import '../services/settings_store.dart';
import '../services/weather_service.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

// Field details come from the Aviation Weather Center airport endpoint
// (official NOAA/FAA data: tower, frequencies, runways with true alignment,
// elevation), with the latest METAR from the same service. Charts link out to
// the FAA's official d-TPP search for the airport — see chart_service.dart.

class AirportScreen extends StatefulWidget {
  const AirportScreen({super.key, this.initialIcao});

  final String? initialIcao;

  @override
  State<AirportScreen> createState() => _AirportScreenState();
}

class _AirportScreenState extends State<AirportScreen> {
  final _controller = TextEditingController();
  String? _ident;
  AirportReference? _detail;
  MetarObservation? _metar;
  bool _loading = false;
  String? _error;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    final start = widget.initialIcao ?? '';
    _controller.text = start;
    if (start.trim().length >= 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _lookup(start));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _lookup(String code) async {
    final id = code.trim().toUpperCase();
    if (id.isEmpty) return;
    final weather = context.read<WeatherService>();
    setState(() {
      _ident = id;
      _loading = true;
      _error = null;
      _notFound = false;
      _detail = null;
      _metar = null;
    });
    AirportReference? detail;
    String? error;
    try {
      detail = await weather.fetchAirportDetail(id);
    } catch (_) {
      error = 'Could not load field details from aviationweather.gov. '
          'Check your connection.';
    }
    final metar = await weather.fetchMetar(id);
    if (!mounted) return;
    setState(() {
      _detail = detail;
      _metar = metar.$2;
      _error = error;
      _notFound = error == null && detail == null;
      _loading = false;
    });
  }

  Future<void> _openDtpp(String ident) async {
    final uri = dtppSearchUri(ident);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Could not open faa.gov')));
      }
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not open faa.gov')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final home = context.watch<SettingsStore>().homeAirport;
    return Scaffold(
      appBar: AppBar(title: const Text('Airport')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Expanded(
              child: TextField(
                key: const Key('airport-ident'),
                controller: _controller,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(fontFamily: AppFonts.mono),
                decoration: const InputDecoration(
                  labelText: 'Airport (ICAO)',
                  hintText: 'e.g. KPAO',
                ),
                onSubmitted: _lookup,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const Key('airport-lookup'),
              onPressed: () => _lookup(_controller.text),
              child: const Text('Look up'),
            ),
          ]),
          if (home.isNotEmpty && _ident == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(children: [
                ActionChip(
                  avatar: const Icon(Icons.home_outlined, size: 18),
                  label: Text(home),
                  onPressed: () {
                    _controller.text = home;
                    _lookup(home);
                  },
                ),
              ]),
            ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_ident != null) ..._content(context),
        ],
      ),
    );
  }

  List<Widget> _content(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = _detail;
    String orDash(String s) => s.isEmpty ? '—' : s;
    final out = <Widget>[const SectionHeader('Field details')];
    if (_error != null) {
      out.add(NoticeLine(icon: Icons.cloud_off, text: _error!));
    } else if (_notFound || d == null) {
      out.add(NoticeLine(
          icon: Icons.public,
          text: 'aviationweather.gov has no field details for $_ident. Use '
              'the ICAO identifier (KLAX, not LAX).'));
    } else {
      out.addAll([
        Text(orDash(d.name), style: Theme.of(context).textTheme.titleLarge),
        _row('Control tower', d.towered ? 'Yes' : 'None listed'),
        _row('Frequencies',
            d.frequencies.isEmpty ? 'None listed' : d.frequencies.join('\n')),
        _row(
            'Elevation',
            d.elevationM == null
                ? '—'
                : '${d.elevationFt} ft (${d.elevationM} m) MSL'),
        _row('Magnetic var.', orDash(d.magneticVariation)),
        _row(
          'Runways',
          d.runwayInfo.isEmpty
              ? (d.runways.isEmpty ? '—' : d.runways.join('\n'))
              : d.runwayInfo
                  .map((r) =>
                      '${r.id}${r.dimension.isEmpty ? '' : ' ${r.dimension} ft'}'
                      '${r.alignmentTrue == null ? '' : ' · ${r.alignmentTrue}° true'}')
                  .join('\n'),
        ),
        const SizedBox(height: 6),
        Text(
          d.source == 'FAA'
              ? 'Source: FAA data via aviationweather.gov'
              : 'Source: aviationweather.gov',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ]);
    }

    if (_metar != null) {
      out.addAll([
        const SizedBox(height: 16),
        const SectionHeader('Latest METAR'),
        MonoBlock(_metar!.raw),
        if (_metar!.observedUtc != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Observed ${zuluTime(_metar!.observedUtc!)}',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ),
      ]);
    }

    // Charts are FAA (US) only. When the lookup failed we cannot tell, so the
    // link is offered and labelled US-only.
    if (d == null ? _error != null : d.isUs) {
      out.addAll([
        const SizedBox(height: 16),
        const SectionHeader('Charts & plates'),
        Text(
          'Airport diagram, approaches, departures, arrivals and minimums for '
          '$_ident are published by the FAA in the d-TPP (cycle '
          '${dtppCycleFor(DateTime.now())}, US airports only). Opens faa.gov '
          'in your browser.',
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => _openDtpp(_ident!),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Open FAA terminal procedures'),
          ),
        ),
      ]);
    }
    return out;
  }

  Widget _row(String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: scheme.outlineVariant))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(
                    fontFamily: AppFonts.heading, fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontFamily: AppFonts.mono, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
