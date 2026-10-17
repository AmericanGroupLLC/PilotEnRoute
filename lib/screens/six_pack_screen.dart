import 'package:flutter/material.dart';

import '../content/instruments.g.dart';
import '../content/sourced.dart';
import '../ui/instruments.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// The six primary flight instruments. Tap one to read about it, and move
/// the slider to see how it responds. Every sentence is from the PHAK,
/// chapter 8, with its page.
class SixPackScreen extends StatefulWidget {
  const SixPackScreen({super.key});

  @override
  State<SixPackScreen> createState() => _SixPackScreenState();
}

class _SixPackScreenState extends State<SixPackScreen> {
  String _selected = 'asi';
  double _kt = 100, _pitch = 0, _bank = 0, _ft = 3500, _rate = 0, _hdg = 90,
      _fpm = 0;

  /// Short labels under each dial, in panel order.
  static const _labels = {
    'asi': 'Airspeed',
    'ai': 'Attitude',
    'alt': 'Altimeter',
    'tc': 'Turn coord.',
    'hi': 'Heading',
    'vsi': 'Vertical speed',
  };

  /// What the dial shows, for screen readers.
  String _reading(String id) {
    switch (id) {
      case 'asi':
        return '${_kt.round()} knots';
      case 'ai':
        return 'pitch ${_pitch.round()} degrees, bank ${_bank.round()} degrees';
      case 'alt':
        return '${_ft.round()} feet';
      case 'tc':
        return '${(_rate / 5).toStringAsFixed(1)} degrees per second';
      case 'hi':
        return 'heading ${_hdg.round().toString().padLeft(3, '0')}';
      default:
        return '${_fpm.round()} feet per minute';
    }
  }

  CustomPainter _painter(String id) {
    switch (id) {
      case 'asi':
        return AsiPainter(kt: _kt);
      case 'ai':
        return AttitudeIndicatorPainter(pitchDeg: _pitch, bankDeg: _bank);
      case 'alt':
        return AltimeterPainter(ft: _ft);
      case 'tc':
        return TurnCoordinatorPainter(rateDeg: _rate);
      case 'hi':
        return HeadingPainter(hdg: _hdg);
      default:
        return VsiPainter(fpm: _fpm);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lesson = instrumentLessons.firstWhere((l) => l.id == _selected);
    final ids = _labels.keys.toList();
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 0,
        title: const PageTitle('Six-pack trainer',
            subtitle: 'The six primary flight instruments'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
                color: Color(0xFF1E2A35), borderRadius: Sky.cornersL),
            child: Column(children: [
              for (var r = 0; r < 2; r++)
                Padding(
                  padding: EdgeInsets.only(bottom: r == 0 ? 10 : 0),
                  child: Row(children: [
                    for (var c = 0; c < 3; c++) ...[
                      if (c > 0) const SizedBox(width: 10),
                      Expanded(child: _dial(ids[r * 3 + c])),
                    ],
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 14),
          _tryIt(context),
          const SizedBox(height: 14),
          _lessonCard(context, lesson),
          const SizedBox(height: 12),
          Text(
              'Source: ${instrumentSources.first.docNumber}, Pilot\'s Handbook '
              'of Aeronautical Knowledge, chapter 8. The arcs and numbers on '
              'the airspeed dial are an example, not any particular '
              'airplane\'s: yours are in its POH/AFM.',
              style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _dial(String id) {
    final selected = id == _selected;
    return Semantics(
      button: true,
      selected: selected,
      label: '${_labels[id]}, ${_reading(id)}',
      excludeSemantics: true,
      child: InkWell(
        key: Key('sixpack-$id'),
        onTap: () => setState(() => _selected = id),
        borderRadius: Sky.cornersM,
        child: Column(children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: selected
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Sky.nightTeal, width: 3))
                  : null,
              child: CustomPaint(painter: _painter(id), size: Size.infinite),
            ),
          ),
          const SizedBox(height: 4),
          Text(_labels[id]!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: selected ? Sky.nightTeal : const Color(0xFFB9C7D4),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _slider(String label, String value, double v, double min, double max,
          ValueChanged<double> on) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(value,
              style: const TextStyle(
                  fontFamily: AppFonts.mono, fontWeight: FontWeight.w700)),
        ]),
        Slider(
            key: Key('sixpack-slider-$label'),
            label: value,
            semanticFormatterCallback: (_) => value,
            value: v,
            min: min,
            max: max,
            onChanged: (x) => setState(() => on(x))),
      ]);

  Widget _tryIt(BuildContext context) {
    final List<Widget> controls;
    switch (_selected) {
      case 'asi':
        controls = [
          _slider('Airspeed', '${_kt.round()} kt', _kt, 0, 200, (x) => _kt = x)
        ];
      case 'ai':
        controls = [
          _slider('Pitch', '${_pitch.round()}°', _pitch, -20, 20,
              (x) => _pitch = x),
          _slider('Bank', '${_bank.round().abs()}° ${_bank < 0 ? 'left' : _bank > 0 ? 'right' : ''}'
              .trim(), _bank, -45, 45, (x) => _bank = x),
        ];
      case 'alt':
        controls = [
          _slider('Altitude', '${_ft.round()} ft', _ft, 0, 10000,
              (x) => _ft = x)
        ];
      case 'tc':
        // The second mark is a standard-rate turn, 3° per second.
        controls = [
          _slider('Rate of turn', '${(_rate / 5).toStringAsFixed(1)}°/s',
              _rate, -30, 30, (x) => _rate = x)
        ];
      case 'hi':
        controls = [
          _slider('Heading', _hdg.round().toString().padLeft(3, '0'), _hdg, 0,
              359, (x) => _hdg = x)
        ];
      default:
        controls = [
          _slider('Vertical speed', '${_fpm.round()} fpm', _fpm, -2000, 2000,
              (x) => _fpm = x)
        ];
    }
    return SkyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('Try it',
              subtitle: 'Move the slider and watch the dial'),
          ...controls,
        ],
      ),
    );
  }

  Widget _lessonCard(BuildContext context, InstrumentLesson l) {
    final scheme = Theme.of(context).colorScheme;
    Widget section(String title, List<SourcedLine> lines) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: scheme.primary)),
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(line.text,
                          style: TextStyle(
                              fontSize: 14.5,
                              height: 1.4,
                              color: scheme.onSurface)),
                      Text(line.cite,
                          style: TextStyle(
                              fontSize: 11.5, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
            ],
          ),
        );
    return SkyCard(
      key: Key('sixpack-lesson-${l.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.name,
              style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                  color: scheme.onSurface)),
          section('What it shows', l.shows),
          section('How it works', l.works),
          section('Reading it', l.read),
          section('Errors and failures', l.errors),
        ],
      ),
    );
  }
}
