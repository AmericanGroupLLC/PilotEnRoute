/// The six primary flight instruments drawn flat (no gradients), for the
/// Learn tab's six-pack trainer. Generic dials: the airspeed arcs are not any
/// particular airplane's — the POH/AFM gives those.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// A flat attitude indicator: rotating horizon (sky/ground), pitch ladder,
/// bank scale and a fixed miniature airplane. No gradients.
class AttitudeIndicatorPainter extends CustomPainter {
  const AttitudeIndicatorPainter({required this.pitchDeg, required this.bankDeg});
  final double pitchDeg;
  final double bankDeg;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final p = Paint()..isAntiAlias = true;
    // Bezel.
    canvas.drawCircle(c, r, p..color = const Color(0xFF26323D));
    canvas.drawCircle(c, r * 0.94, p..color = const Color(0xFF3B4A57));
    final face = r * 0.86;
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: face)));
    canvas.translate(c.dx, c.dy);
    // The horizon turns opposite to the airplane's roll.
    canvas.rotate(-bankDeg * math.pi / 180);
    final pxPerDeg = face / 30;
    final dy = pitchDeg * pxPerDeg;
    canvas.drawRect(Rect.fromLTRB(-r * 2, -r * 2, r * 2, dy),
        p..color = const Color(0xFF4FA8E0));
    canvas.drawRect(Rect.fromLTRB(-r * 2, dy, r * 2, r * 2),
        p..color = const Color(0xFF8A5A3B));
    final line = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;
    canvas.drawLine(Offset(-r * 2, dy), Offset(r * 2, dy), line);
    for (final d in [-20, -10, -5, 5, 10, 20]) {
      final y = dy - d * pxPerDeg;
      final w = d.abs() % 10 == 0 ? face * 0.32 : face * 0.16;
      canvas.drawLine(Offset(-w / 2, y), Offset(w / 2, y),
          line..strokeWidth = 1.4);
    }
    canvas.restore();

    // Bank scale (fixed) and pointer (rotates with bank).
    final tick = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    for (final a in [-60, -45, -30, -20, -10, 10, 20, 30, 45, 60]) {
      final rad = (a - 90) * math.pi / 180;
      final long = a.abs() == 30 || a.abs() == 60;
      final o = c + Offset(math.cos(rad), math.sin(rad)) * face;
      final i = c + Offset(math.cos(rad), math.sin(rad)) * (face - (long ? 16 : 10));
      canvas.drawLine(i, o, tick);
    }
    final tri = Path()
      ..moveTo(c.dx, c.dy - face + 2)
      ..lineTo(c.dx - 7, c.dy - face - 10)
      ..lineTo(c.dx + 7, c.dy - face - 10)
      ..close();
    canvas.drawPath(tri, p..color = const Color(0xFFF2B84B));
    canvas.save();
    canvas.translate(c.dx, c.dy);
    // The horizon turns opposite to the airplane's roll.
    canvas.rotate(-bankDeg * math.pi / 180);
    canvas.drawPath(
        Path()
          ..moveTo(0, -face + 18)
          ..lineTo(-6, -face + 28)
          ..lineTo(6, -face + 28)
          ..close(),
        p..color = Colors.white);
    canvas.restore();

    // Miniature airplane (fixed).
    final plane = Paint()
      ..color = const Color(0xFFF2B84B)
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c + Offset(-face * 0.55, 0), c + Offset(-face * 0.18, 0), plane);
    canvas.drawLine(c + Offset(face * 0.18, 0), c + Offset(face * 0.55, 0), plane);
    canvas.drawLine(c + Offset(-face * 0.18, 0), c + Offset(0, face * 0.10), plane);
    canvas.drawLine(c + Offset(face * 0.18, 0), c + Offset(0, face * 0.10), plane);
    canvas.drawCircle(c, 4, p..color = const Color(0xFFF2B84B));
  }

  @override
  bool shouldRepaint(AttitudeIndicatorPainter o) =>
      o.pitchDeg != pitchDeg || o.bankDeg != bankDeg;
}

abstract class _DialPainter extends CustomPainter {
  const _DialPainter();

  ({Offset c, double r}) face(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final p = Paint()..isAntiAlias = true;
    canvas.drawCircle(c, r, p..color = const Color(0xFF0F161D));
    canvas.drawCircle(c, r * .92, p..color = const Color(0xFF1B252E));
    return (c: c, r: r * .9);
  }

  void ticks(Canvas canvas, Offset c, double r, int n, double from, double sweep, {int majorEvery = 1}) {
    final tick = Paint()
      ..color = Colors.white
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i <= n; i++) {
      final a = (from + sweep * i / n) * math.pi / 180;
      final major = i % majorEvery == 0;
      tick.strokeWidth = major ? 1.8 : 1;
      final o = c + Offset(math.cos(a), math.sin(a)) * r * .95;
      final ii = c + Offset(math.cos(a), math.sin(a)) * r * (major ? .78 : .86);
      canvas.drawLine(ii, o, tick);
    }
  }

  void label(Canvas canvas, Offset at, String t, double size, {Color color = Colors.white}) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: TextStyle(fontFamily: AppFonts.body, color: color, fontSize: size, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  void needle(Canvas canvas, Offset c, double r, double deg, double len, {double w = 3, Color color = Colors.white}) {
    final a = deg * math.pi / 180;
    canvas.drawLine(c, c + Offset(math.cos(a), math.sin(a)) * r * len,
        Paint()
          ..color = color
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round);
    canvas.drawCircle(c, r * .07, Paint()..color = const Color(0xFF55606B));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class AsiPainter extends _DialPainter {
  const AsiPainter({required this.kt});
  final double kt;
  static const _from = 135.0, _sweep = 300.0, _max = 200.0;
  double _a(double v) => _from + _sweep * v / _max;

  @override
  void paint(Canvas canvas, Size size) {
    final f = face(canvas, size);
    final rect = Rect.fromCircle(center: f.c, radius: f.r * .9);
    void arc(double a, double b, Color color, double w) => canvas.drawArc(
        rect, _a(a) * math.pi / 180, (_a(b) - _a(a)) * math.pi / 180, false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = w);
    arc(40, 85, Colors.white, f.r * .06);
    arc(48, 129, const Color(0xFF43B36B), f.r * .1);
    arc(129, 163, const Color(0xFFF2B84B), f.r * .1);
    arc(162, 165, const Color(0xFFE5484D), f.r * .14);
    ticks(canvas, f.c, f.r, 20, _from, _sweep, majorEvery: 2);
    for (final v in [40, 80, 120, 160]) {
      final a = _a(v.toDouble()) * math.pi / 180;
      label(canvas, f.c + Offset(math.cos(a), math.sin(a)) * f.r * .56, '$v', f.r * .17);
    }
    label(canvas, f.c + Offset(0, f.r * .32), 'KNOTS', f.r * .12, color: const Color(0xFF9FB0BF));
    needle(canvas, f.c, f.r, _a(kt), .82);
  }
}

class AltimeterPainter extends _DialPainter {
  const AltimeterPainter({required this.ft});
  final double ft;

  @override
  void paint(Canvas canvas, Size size) {
    final f = face(canvas, size);
    ticks(canvas, f.c, f.r, 50, -90, 360, majorEvery: 5);
    for (var i = 0; i < 10; i++) {
      final a = (-90 + 36 * i) * math.pi / 180;
      label(canvas, f.c + Offset(math.cos(a), math.sin(a)) * f.r * .6, '$i', f.r * .19);
    }
    final win = Rect.fromCenter(center: f.c + Offset(f.r * .34, 0), width: f.r * .5, height: f.r * .2);
    canvas.drawRect(win, Paint()..color = Colors.black);
    label(canvas, win.center, '29.92', f.r * .12);
    needle(canvas, f.c, f.r, -90 + 360 * ((ft / 10000) % 1), .45, w: 5);
    needle(canvas, f.c, f.r, -90 + 360 * ((ft / 1000) % 1), .82);
  }
}

class VsiPainter extends _DialPainter {
  const VsiPainter({required this.fpm});
  final double fpm;
  // 0 at 9 o'clock; up to +2000 sweeps 170° clockwise, down mirrors.
  double _a(double v) => 180 + 170 * (v.clamp(-2000, 2000) / 2000);

  @override
  void paint(Canvas canvas, Size size) {
    final f = face(canvas, size);
    ticks(canvas, f.c, f.r, 40, 10, 340, majorEvery: 5);
    for (final v in [0, 5, 10, 15, 20]) {
      for (final s in [1, -1]) {
        // 0 and 2,000 are shared by the climb and descent scales.
        if ((v == 0 || v == 20) && s == -1) continue;
        final a = _a(v * 100.0 * s) * math.pi / 180;
        label(canvas, f.c + Offset(math.cos(a), math.sin(a)) * f.r * .58, '$v', f.r * .17);
      }
    }
    label(canvas, f.c + Offset(f.r * .1, -f.r * .3), 'UP', f.r * .12, color: const Color(0xFF9FB0BF));
    label(canvas, f.c + Offset(f.r * .1, f.r * .3), 'DN', f.r * .12, color: const Color(0xFF9FB0BF));
    needle(canvas, f.c, f.r, _a(fpm), .82);
  }
}

class HeadingPainter extends _DialPainter {
  const HeadingPainter({required this.hdg});
  final double hdg;

  @override
  void paint(Canvas canvas, Size size) {
    final f = face(canvas, size);
    canvas.save();
    canvas.translate(f.c.dx, f.c.dy);
    canvas.rotate(-hdg * math.pi / 180);
    canvas.translate(-f.c.dx, -f.c.dy);
    ticks(canvas, f.c, f.r, 72, -90, 360, majorEvery: 2);
    const names = {0: 'N', 3: '3', 6: '6', 9: 'E', 12: '12', 15: '15', 18: 'S', 21: '21', 24: '24', 27: 'W', 30: '30', 33: '33'};
    names.forEach((k, v) {
      final a = (-90 + k * 10) * math.pi / 180;
      canvas.save();
      final at = f.c + Offset(math.cos(a), math.sin(a)) * f.r * .6;
      canvas.translate(at.dx, at.dy);
      canvas.rotate(a + math.pi / 2);
      label(canvas, Offset.zero, v, f.r * .17, color: v.length == 1 ? const Color(0xFFF2B84B) : Colors.white);
      canvas.restore();
    });
    canvas.restore();
    final plane = Paint()
      ..color = const Color(0xFFF2B84B)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(f.c + Offset(0, -f.r * .3), f.c + Offset(0, f.r * .3), plane);
    canvas.drawLine(f.c + Offset(-f.r * .25, -f.r * .02), f.c + Offset(f.r * .25, -f.r * .02), plane);
    canvas.drawLine(f.c + Offset(-f.r * .1, f.r * .26), f.c + Offset(f.r * .1, f.r * .26), plane);
    final tri = Path()
      ..moveTo(f.c.dx, f.c.dy - f.r * .98)
      ..lineTo(f.c.dx - 5, f.c.dy - f.r * .98 - 8)
      ..lineTo(f.c.dx + 5, f.c.dy - f.r * .98 - 8)
      ..close();
    canvas.drawPath(tri, Paint()..color = const Color(0xFFF2B84B));
  }
}

class TurnCoordinatorPainter extends _DialPainter {
  const TurnCoordinatorPainter({required this.rateDeg});
  final double rateDeg;

  @override
  void paint(Canvas canvas, Size size) {
    final f = face(canvas, size);
    final tick = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    // Level marks at 9 and 3 o'clock; standard-rate marks below them.
    for (final a in [180.0, 165.0, 0.0, 15.0]) {
      final rad = a * math.pi / 180;
      canvas.drawLine(f.c + Offset(math.cos(rad), math.sin(rad)) * f.r * .72,
          f.c + Offset(math.cos(rad), math.sin(rad)) * f.r * .92, tick);
    }
    label(canvas, f.c + Offset(-f.r * .62, f.r * .32), 'L', f.r * .17);
    label(canvas, f.c + Offset(f.r * .62, f.r * .32), 'R', f.r * .17);
    label(canvas, f.c + Offset(0, -f.r * .5), '2 MIN', f.r * .12, color: const Color(0xFF9FB0BF));
    canvas.save();
    canvas.translate(f.c.dx, f.c.dy);
    canvas.rotate(rateDeg * math.pi / 180);
    final plane = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(-f.r * .7, 0), Offset(f.r * .7, 0), plane);
    canvas.drawCircle(Offset.zero, f.r * .1, Paint()..color = Colors.white);
    canvas.drawLine(Offset(0, -f.r * .2), Offset(0, -f.r * .05), plane..strokeWidth = 3);
    canvas.restore();
    final tube = RRect.fromRectAndRadius(
        Rect.fromCenter(center: f.c + Offset(0, f.r * .5), width: f.r * .9, height: f.r * .2),
        Radius.circular(f.r * .1));
    canvas.drawRRect(tube, Paint()..color = const Color(0xFFE8EDF1));
    canvas.drawCircle(f.c + Offset(0, f.r * .5), f.r * .08, Paint()..color = Colors.black);
    for (final s in [-1, 1]) {
      canvas.drawLine(f.c + Offset(s * f.r * .11, f.r * .41), f.c + Offset(s * f.r * .11, f.r * .59),
          Paint()
            ..color = Colors.black
            ..strokeWidth = 1.4);
    }
  }
}
