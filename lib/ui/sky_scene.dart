import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Time of day for [SkyScene].
enum SkyMood { day, night, overcast }

/// The hero illustration: a high-wing trainer over hills and a lake, drawn
/// flat in layered colours (no photos, no gradients, nothing fetched).
///
/// The mood follows the planned flight — night when the Night switch is on,
/// overcast when the weather sits outside the pilot's minimums.
class SkyScene extends StatelessWidget {
  const SkyScene({
    super.key,
    this.mood = SkyMood.day,
    this.height = 180,
    this.showPlane = true,
  });

  final SkyMood mood;
  final double height;
  final bool showPlane;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: SkyScenePainter(mood: mood, showPlane: showPlane),
        ),
      ),
    );
  }
}

class _Palette {
  const _Palette({
    required this.sky,
    required this.sun,
    required this.halo,
    required this.cloud,
    required this.farHill,
    required this.water,
    required this.waterLine,
    required this.nearHill,
    required this.tree,
  });

  final Color sky;
  final Color sun;
  final Color halo;
  final Color cloud;
  final Color farHill;
  final Color water;
  final Color waterLine;
  final Color nearHill;
  final Color tree;

  static const day = _Palette(
    sky: Color(0xFFCDE7F7),
    sun: Color(0xFFFFE6A0),
    halo: Color(0xFFFDF1CF),
    cloud: Color(0xFFFFFFFF),
    farHill: Color(0xFFA8D2C4),
    water: Color(0xFF94C9EA),
    waterLine: Color(0xFFBFE0F4),
    nearHill: Color(0xFF7DBB9C),
    tree: Color(0xFF5FA584),
  );

  static const overcast = _Palette(
    sky: Color(0xFFD5DEE6),
    sun: Color(0xFFE9EDF1),
    halo: Color(0xFFDFE5EB),
    cloud: Color(0xFFB9C6D2),
    farHill: Color(0xFFA4B9B3),
    water: Color(0xFFA2B6C6),
    waterLine: Color(0xFFC0CDD8),
    nearHill: Color(0xFF86A396),
    tree: Color(0xFF6F8E80),
  );

  static const night = _Palette(
    sky: Color(0xFF1A3350),
    sun: Color(0xFFF4EFD9),
    halo: Color(0xFF26446A),
    cloud: Color(0xFF2B4A6E),
    farHill: Color(0xFF203D58),
    water: Color(0xFF2A527A),
    waterLine: Color(0xFF3B6894),
    nearHill: Color(0xFF16304A),
    tree: Color(0xFF112739),
  );
}

class SkyScenePainter extends CustomPainter {
  SkyScenePainter({required this.mood, this.showPlane = true});

  final SkyMood mood;
  final bool showPlane;

  _Palette get _p => switch (mood) {
    SkyMood.day => _Palette.day,
    SkyMood.night => _Palette.night,
    SkyMood.overcast => _Palette.overcast,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = _p;
    final fill = Paint()..isAntiAlias = true;

    canvas.drawRect(Offset.zero & size, fill..color = p.sky);

    // Sun or moon, with a soft halo ring.
    final sunC = Offset(w * 0.84, h * 0.24);
    final r = h * 0.10;
    canvas.drawCircle(sunC, r * 1.8, fill..color = p.halo);
    if (mood == SkyMood.night) {
      final moon = Path.combine(
        PathOperation.difference,
        Path()..addOval(Rect.fromCircle(center: sunC, radius: r)),
        Path()..addOval(
          Rect.fromCircle(
            center: sunC + Offset(r * 0.45, -r * 0.25),
            radius: r * 0.85,
          ),
        ),
      );
      canvas.drawPath(moon, fill..color = p.sun);
      final rnd = math.Random(7);
      for (var i = 0; i < 26; i++) {
        final o = Offset(rnd.nextDouble() * w, rnd.nextDouble() * h * 0.55);
        canvas.drawCircle(
          o,
          0.6 + rnd.nextDouble() * 1.1,
          fill..color = const Color(0xCCFFFFFF),
        );
      }
    } else {
      canvas.drawCircle(sunC, r, fill..color = p.sun);
    }

    // Clouds.
    _cloud(canvas, Offset(w * 0.16, h * 0.20), h * 0.07, p.cloud);
    _cloud(canvas, Offset(w * 0.62, h * 0.13), h * 0.055, p.cloud);
    _cloud(canvas, Offset(w * 0.93, h * 0.44), h * 0.06, p.cloud);
    if (mood == SkyMood.overcast) {
      _cloud(canvas, Offset(w * 0.40, h * 0.30), h * 0.08, p.cloud);
      _cloud(canvas, Offset(w * 0.78, h * 0.08), h * 0.07, p.cloud);
    }

    // Far hills.
    final far = Path()
      ..moveTo(0, h * 0.70)
      ..quadraticBezierTo(w * 0.12, h * 0.56, w * 0.28, h * 0.64)
      ..quadraticBezierTo(w * 0.42, h * 0.54, w * 0.58, h * 0.63)
      ..quadraticBezierTo(w * 0.76, h * 0.52, w, h * 0.62)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(far, fill..color = p.farHill);

    // Lake.
    final lake = Path()
      ..moveTo(0, h * 0.74)
      ..quadraticBezierTo(w * 0.45, h * 0.69, w, h * 0.73)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(lake, fill..color = p.water);
    final ripple = Paint()
      ..color = p.waterLine
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (final (x, y, len) in [
      (0.10, 0.79, 0.08),
      (0.30, 0.77, 0.12),
      (0.55, 0.80, 0.07),
      (0.72, 0.77, 0.10),
    ]) {
      canvas.drawLine(
        Offset(w * x, h * y),
        Offset(w * (x + len), h * y),
        ripple,
      );
    }

    // Near shore with a few trees.
    final near = Path()
      ..moveTo(0, h * 0.86)
      ..quadraticBezierTo(w * 0.22, h * 0.80, w * 0.46, h * 0.88)
      ..quadraticBezierTo(w * 0.72, h * 0.96, w, h * 0.84)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(near, fill..color = p.nearHill);
    for (final x in [0.06, 0.10, 0.88, 0.93]) {
      final base = Offset(w * x, h * (x < 0.5 ? 0.85 : 0.86));
      final t = Path()
        ..moveTo(base.dx - h * 0.025, base.dy)
        ..lineTo(base.dx, base.dy - h * 0.09)
        ..lineTo(base.dx + h * 0.025, base.dy)
        ..close();
      canvas.drawPath(t, fill..color = p.tree);
    }

    if (showPlane) {
      _plane(canvas, Offset(w * 0.40, h * 0.40), h / 180);
    }
  }

  void _cloud(Canvas canvas, Offset c, double r, Color color) {
    final paint = Paint()..color = color;
    final path = Path()
      ..addOval(Rect.fromCircle(center: c, radius: r))
      ..addOval(
        Rect.fromCircle(center: c + Offset(r * 1.1, r * 0.25), radius: r * 0.8),
      )
      ..addOval(
        Rect.fromCircle(center: c + Offset(-r * 1.1, r * 0.3), radius: r * 0.7),
      )
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            c.dx - r * 1.8,
            c.dy + r * 0.1,
            c.dx + r * 1.9,
            c.dy + r * 1.0,
          ),
          Radius.circular(r * 0.45),
        ),
      );
    canvas.drawPath(path, paint);
  }

  /// A high-wing trainer in profile, nose right, in a 200 × 80 box.
  void _plane(Canvas canvas, Offset centre, double scale) {
    final night = mood == SkyMood.night;
    const navy = Color(0xFF1D4E78);
    const teal = Color(0xFF0A7887);
    final body = night ? const Color(0xFFE3EAF1) : Colors.white;
    final edge = Paint()
      ..color = const Color(0xFF9FB4C6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final fill = Paint()..isAntiAlias = true;

    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(-0.07);
    canvas.scale(scale);
    canvas.translate(-100, -40);

    // Shadow-side wing (far wing), a touch darker.
    final farWing = RRect.fromLTRBR(84, 15, 176, 22, const Radius.circular(3));
    canvas.drawRRect(farWing, fill..color = const Color(0xFFD5E0EA));

    // Tail fin and stabiliser.
    final fin = Path()
      ..moveTo(12, 38)
      ..lineTo(4, 10)
      ..quadraticBezierTo(4, 6, 10, 7)
      ..lineTo(24, 10)
      ..lineTo(48, 33)
      ..close();
    canvas.drawPath(fin, fill..color = body);
    canvas.drawPath(fin, edge);
    canvas.drawPath(
      Path()
        ..moveTo(6, 14)
        ..lineTo(22, 16)
        ..lineTo(28, 22)
        ..lineTo(8, 20)
        ..close(),
      fill..color = navy,
    );
    canvas.drawOval(const Rect.fromLTWH(4, 36, 40, 7), fill..color = body);
    canvas.drawOval(const Rect.fromLTWH(4, 36, 40, 7), edge);

    // Fuselage.
    final fus = Path()
      ..moveTo(10, 37)
      ..quadraticBezierTo(44, 28, 96, 27)
      ..lineTo(160, 27)
      ..quadraticBezierTo(186, 29, 192, 43)
      ..quadraticBezierTo(186, 55, 160, 55)
      ..lineTo(96, 55)
      ..quadraticBezierTo(48, 53, 10, 43)
      ..close();
    canvas.drawPath(fus, fill..color = body);
    canvas.drawPath(fus, edge);

    // Livery: navy cheat line with a thin teal pinstripe.
    canvas.save();
    canvas.clipPath(fus);
    canvas.drawRect(const Rect.fromLTRB(0, 44, 200, 48.5), fill..color = navy);
    canvas.drawRect(const Rect.fromLTRB(0, 50, 200, 51.5), fill..color = teal);
    canvas.restore();

    // Cabin windows.
    final win = Path()
      ..moveTo(116, 30)
      ..lineTo(150, 30)
      ..quadraticBezierTo(158, 31, 164, 40)
      ..lineTo(116, 40)
      ..close();
    canvas.drawPath(
      win,
      fill..color = night ? const Color(0xFFFFE6A0) : const Color(0xFF2E5A7F),
    );
    canvas.drawLine(
      const Offset(140, 30),
      const Offset(140, 40),
      Paint()
        ..color = body
        ..strokeWidth = 2,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(96, 31, 110, 39, const Radius.circular(2)),
      fill..color = night ? const Color(0xFFFFE6A0) : const Color(0xFF2E5A7F),
    );

    // Near wing on top, and its strut.
    final wing = RRect.fromLTRBR(78, 20, 170, 27.5, const Radius.circular(3.5));
    canvas.drawRRect(wing, fill..color = body);
    canvas.drawRRect(wing, edge);
    canvas.drawLine(
      const Offset(126, 27),
      const Offset(108, 53),
      Paint()
        ..color = const Color(0xFF7F95A8)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // Gear.
    final gear = Paint()
      ..color = const Color(0xFF55697C)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(112, 54), const Offset(106, 64), gear);
    canvas.drawLine(const Offset(172, 54), const Offset(172, 63), gear);
    for (final (c, rad) in [
      (const Offset(105, 66), 5.0),
      (const Offset(172, 65), 4.0),
    ]) {
      canvas.drawCircle(c, rad, fill..color = const Color(0xFF26323D));
      canvas.drawCircle(c, rad * 0.4, fill..color = const Color(0xFFB7C4CF));
    }

    // Spinner and a blurred propeller disc.
    canvas.drawOval(
      const Rect.fromLTWH(192, 22, 4, 42),
      fill..color = const Color(0x5591A3B3),
    );
    canvas.drawCircle(const Offset(193, 43), 3.4, fill..color = navy);

    // Night: nav and beacon lights.
    if (night) {
      canvas.drawCircle(
        const Offset(168, 22),
        2.2,
        fill..color = const Color(0xFF6BE38F),
      );
      canvas.drawCircle(
        const Offset(8, 9),
        2.2,
        fill..color = const Color(0xFFFF6B6B),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(SkyScenePainter old) =>
      old.mood != mood || old.showPlane != showPlane;
}
