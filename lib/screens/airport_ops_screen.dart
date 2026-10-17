import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../content/instruments.g.dart';
import '../content/sourced.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Traffic pattern, airport signs and runway/taxiway markings, from the AIM
/// (chapter 4 section 3 and chapter 2 section 3). Each line shows its
/// paragraph.
class AirportOpsScreen extends StatelessWidget {
  const AirportOpsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 72,
          titleSpacing: 0,
          title: const PageTitle('Airport operations',
              subtitle: 'Pattern, signs and markings · AIM'),
          bottom: const SegmentedTabBar(tabs: [
            Tab(text: 'Pattern'),
            Tab(text: 'Signs'),
            Tab(text: 'Markings'),
          ]),
        ),
        body: TabBarView(children: [
          _list(context, [
            // Light in both themes: the diagram's ink is dark.
            const SkyCard(
              color: Sky.tile,
              padding: EdgeInsets.all(10),
              child: SizedBox(
                  height: 260,
                  child: CustomPaint(
                      painter: PatternPainter(), size: Size.infinite)),
            ),
            const SizedBox(height: 12),
            _lines(context, 'Left-hand traffic pattern', trafficPattern),
          ]),
          _list(context, [
            for (final s in airportSigns) ...[
              _SignCard(sign: s),
              const SizedBox(height: 10),
            ],
          ]),
          _list(context, [
            _lines(context, 'Runway and taxiway markings', airportMarkings),
          ]),
        ]),
      ),
    );
  }

  Widget _list(BuildContext context, List<Widget> children) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          ...children,
          const SizedBox(height: 8),
          Text(
              'Source: Aeronautical Information Manual (faa.gov), chapter 2 '
              'section 3 and chapter 4 section 3. Your airport\'s Chart '
              'Supplement entry and ATC instructions come first.',
              style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      );

  static Widget _lines(
      BuildContext context, String title, List<SourcedLine> lines) {
    final scheme = Theme.of(context).colorScheme;
    return SkyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: scheme.onSurface)),
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.text,
                      style: TextStyle(
                          fontSize: 14.5, height: 1.4, color: scheme.onSurface)),
                  Text(l.cite,
                      style: TextStyle(
                          fontSize: 11.5, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A drawn example of each sign type in the colours the AIM gives.
class _SignCard extends StatelessWidget {
  const _SignCard({required this.sign});
  final AirportSign sign;

  static const _red = Color(0xFFD1242F), _yellow = Color(0xFFF2D04B);

  (Color bg, Color fg, Color? border, String text) get _look {
    switch (sign.type) {
      case 'Mandatory instruction':
        return (_red, Colors.white, null, '13-31');
      case 'Location':
        return (Colors.black, _yellow, _yellow, 'A');
      case 'Direction':
        return (_yellow, Colors.black, null, '← B');
      case 'Destination':
        return (_yellow, Colors.black, null, 'RAMP →');
      case 'Information':
        return (_yellow, Colors.black, null, 'i');
      default:
        return (Colors.black, Colors.white, null, '3');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg, border, text) = _look;
    return SkyCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 84,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: border ?? Colors.black26, width: border == null ? 1 : 2.5),
            ),
            child: Text(text,
                style: TextStyle(
                    color: fg, fontWeight: FontWeight.w900, fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${sign.type} sign',
                    style: TextStyle(
                        fontFamily: AppFonts.heading,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: scheme.onSurface)),
                Text(sign.colors,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant)),
                const SizedBox(height: 6),
                Text(sign.meaning.text,
                    style: TextStyle(
                        fontSize: 14.5, height: 1.4, color: scheme.onSurface)),
                Text(sign.meaning.cite,
                    style: TextStyle(
                        fontSize: 11.5, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A left-hand pattern for runway 31, landing toward the left of the
/// picture. The legs and the altitude label follow AIM 4-3-2 / 4-3-3.
class PatternPainter extends CustomPainter {
  const PatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Landing toward the left (runway 31 drawn level); a left-hand pattern
    // therefore sits on the pilot's left: below the runway in this view.
    final rw = Rect.fromCenter(center: Offset(w * .5, h * .26), width: w * .5, height: 22);
    canvas.drawRRect(RRect.fromRectAndRadius(rw, const Radius.circular(3)), Paint()..color = const Color(0xFF55606B));
    final dash = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;
    for (var x = rw.left + 26; x < rw.right - 26; x += 18) {
      canvas.drawLine(Offset(x, rw.center.dy), Offset(x + 9, rw.center.dy), dash);
    }
    void txt(String t, Offset o, {double s = 12, Color c = const Color(0xFF0E2235)}) {
      final tp = TextPainter(
          text: TextSpan(text: t, style: TextStyle(fontFamily: AppFonts.body, color: c, fontSize: s, fontWeight: FontWeight.w800)),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, o - Offset(tp.width / 2, tp.height / 2));
    }

    txt('13', Offset(rw.left + 14, rw.center.dy), s: 10, c: Colors.white);
    txt('31', Offset(rw.right - 14, rw.center.dy), s: 10, c: Colors.white);
    final pat = Rect.fromLTRB(w * .12, rw.center.dy, w * .88, h * .8);
    final path = Paint()
      ..color = const Color(0xFF0A7887)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final pts = [
      Offset(rw.left, rw.center.dy),
      Offset(pat.left, rw.center.dy),
      Offset(pat.left, pat.bottom),
      Offset(pat.right, pat.bottom),
      Offset(pat.right, rw.center.dy),
      Offset(rw.right, rw.center.dy),
    ];
    for (var i = 0; i < pts.length - 1; i++) {
      canvas.drawLine(pts[i], pts[i + 1], path);
      final m = Offset.lerp(pts[i], pts[i + 1], .55)!;
      final d = (pts[i + 1] - pts[i]);
      final a = math.atan2(d.dy, d.dx);
      final head = Path()
        ..moveTo(m.dx + math.cos(a) * 8, m.dy + math.sin(a) * 8)
        ..lineTo(m.dx + math.cos(a + 2.5) * 8, m.dy + math.sin(a + 2.5) * 8)
        ..lineTo(m.dx + math.cos(a - 2.5) * 8, m.dy + math.sin(a - 2.5) * 8)
        ..close();
      canvas.drawPath(head, Paint()..color = const Color(0xFF0A7887));
    }
    txt('Upwind', Offset((rw.left + pat.left) / 2, rw.center.dy - 16));
    txt('Crosswind', Offset(pat.left + 34, (pat.bottom + rw.center.dy) / 2));
    txt('Downwind', Offset(w * .7, pat.bottom + 14));
    txt('Base', Offset(pat.right - 22, (pat.bottom + rw.center.dy) / 2));
    txt('Final', Offset((rw.right + pat.right) / 2, rw.center.dy - 16));
    txt('Propeller aircraft: 1,000 ft AGL recommended', Offset(w * .5, (pat.bottom + rw.center.dy) / 2 + 8), s: 11, c: const Color(0xFF33475B));
    txt('Landing runway 31  ←', Offset(w * .5, rw.center.dy - 26), s: 11, c: const Color(0xFF33475B));
  }

  @override
  bool shouldRepaint(PatternPainter old) => false;
}
